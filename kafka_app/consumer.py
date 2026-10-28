import json
import os
import psycopg2
from datetime import datetime
from zoneinfo import ZoneInfo
from decimal import Decimal, InvalidOperation
from pathlib import Path
from uuid import UUID
from dotenv import load_dotenv
from kafka import KafkaConsumer, KafkaProducer

load_dotenv(Path(__file__).with_name(".env"))

DB_CONFIG = {
    "host": os.environ["POSTGRES_HOST"],
    "port": os.environ.get("POSTGRES_PORT", "5432"),
    "dbname": os.environ["POSTGRES_DB"],
    "user": os.environ["POSTGRES_USER"],
    "password": os.environ["POSTGRES_PASSWORD"],
}

SOURCE_TOPIC = "stockpulse.sales"
DLQ_TOPIC = "stockpulse.sales.dlq"


def validate_event(event):
    if not isinstance(event, dict):
        raise ValueError("Event must be a JSON object")

    required = {
        "event_id", "transaction_id", "sold_at",
        "sku", "quantity", "unit_price", "unit_cost",
    }

    missing = required - event.keys()
    if missing:
        raise ValueError(f"Missing fields: {sorted(missing)}")

    event_id = UUID(str(event["event_id"]))
    transaction_id = str(event["transaction_id"]).strip()
    sku = str(event["sku"]).strip()

    if not transaction_id or len(transaction_id) > 100:
        raise ValueError("Invalid transaction_id")

    if not sku or len(sku) > 100:
        raise ValueError("Invalid SKU")

    if isinstance(event["quantity"], bool):
        raise ValueError("Quantity must be an integer")

    quantity = int(event["quantity"])
    if quantity <= 0 or str(quantity) != str(event["quantity"]):
        raise ValueError("Quantity must be a positive integer")

    sold_at = datetime.strptime(event["sold_at"], "%d/%m/%Y %H:%M").replace(
        tzinfo=ZoneInfo("Africa/Nairobi").isoformat()
    )
    
    if sold_at.tzinfo is None:
        raise ValueError("sold_at must include a timezone")

    try:
        unit_price = Decimal(str(event["unit_price"]))
        unit_cost = Decimal(str(event["unit_cost"]))
    except InvalidOperation as exc:
        raise ValueError("Price and cost must be numeric") from exc

    for name, amount in (
        ("unit_price", unit_price),
        ("unit_cost", unit_cost),
    ):
        if not amount.is_finite() or amount < 0:
            raise ValueError(f"{name} must be finite and nonnegative")
        if amount.as_tuple().exponent < -2:
            raise ValueError(
                f"{name} may have at most 2 decimal places"
            )
        if amount >= Decimal("10000000000"):
            raise ValueError(f"{name} exceeds the supported range")

    return (
        str(event_id),
        transaction_id,
        sold_at,
        sku,
        quantity,
        unit_price,
        unit_cost,
        json.dumps(event, allow_nan=False),
    )


def reject_event(connection, producer, raw_text, event, reason):
    event_id = None

    if isinstance(event, dict) and event.get("event_id") is not None:
        event_id = str(event["event_id"])[:100]

    # Store the raw message as a JSON string so even malformed JSON
    # can be recorded safely in the JSONB column.
    raw_payload = json.dumps(raw_text)

    # Rejection audit record.
    with connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO kafka_rejected_events
                    (event_id, raw_payload, reason)
                VALUES (%s, %s::jsonb, %s)
                """,
                (event_id, raw_payload, reason),
            )

    # Publish to the dead-letter topic and wait for broker confirmation.
    # If this fails, the Kafka source offset will not be committed.
    producer.send(
        DLQ_TOPIC,
        key=event_id.encode("utf-8") if event_id else None,
        value={
            "source_topic": SOURCE_TOPIC,
            "event_id": event_id,
            "reason": reason,
            "raw_message": raw_text,
            "rejected_at": datetime.now().astimezone().isoformat(),
        },
    ).get(timeout=15)

    print(f"Sent rejected event {event_id} to {DLQ_TOPIC}: {reason}")


def persist_event(connection, producer, raw_bytes):
    raw_text = raw_bytes.decode("utf-8", errors="replace")

    try:
        event = json.loads(raw_text)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        reject_event(
            connection,
            producer,
            raw_text,
            None,
            f"Invalid JSON: {exc}",
        )
        return

    try:
        values = validate_event(event)
    except (ValueError, TypeError, KeyError, OverflowError) as exc:
        reject_event(
            connection,
            producer,
            raw_text,
            event,
            f"Validation failed: {exc}",
        )
        return

    # ON CONFLICT catches either a repeated event ID or a repeated
    # transaction_id + SKU, provided the unique constraints exist.
    with connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO kafka_sales_events (
                    event_id, transaction_id, sold_at, sku,
                    quantity, unit_price, unit_cost, raw_payload
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb)
                ON CONFLICT DO NOTHING
                RETURNING event_id
                """,
                values,
            )
            inserted = cursor.fetchone()

    if inserted:
        print(f"Stored event {values[0]}")
        return

    reject_event(
        connection,
        producer,
        raw_text,
        event,
        "Duplicate event: event_id or transaction_id + SKU already exists",
    )


consumer = KafkaConsumer(
    SOURCE_TOPIC,
    bootstrap_servers=[os.getenv("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092")],
    group_id="stockpulse-postgres-ingestion-v2",
    auto_offset_reset="earliest",
    enable_auto_commit=False,
)

producer = KafkaProducer(
    bootstrap_servers=[os.getenv("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092")],
    acks="all",
    retries=5,
    value_serializer=lambda value: json.dumps(value).encode("utf-8"),
)

connection = psycopg2.connect(**DB_CONFIG)

try:
    print("Connected to PostgreSQL.")
    print("Listening on {SOURCE_TOPIC}...")

    for message in consumer:
        # Invalid JSON can fail inside the deserializer before this
        # block is reached. We'll handle malformed JSON separately
        # when we build the dead-letter topic.
        persist_event(connection, producer, message.value)

        # Commit the Kafka offset only after the database write succeeds.
        consumer.commit()

except KeyboardInterrupt:
    print("Consumer stopped.")
finally:
    consumer.close()
    producer.close()
    connection.close()
