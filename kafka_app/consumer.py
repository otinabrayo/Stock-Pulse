import json
import os
import psycopg2
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
from uuid import UUID
from dotenv import load_dotenv
from kafka import KafkaConsumer

load_dotenv(Path(__file__).with_name(".env"))

DB_CONFIG = {
    "host": os.environ["POSTGRES_HOST"],
    "port": os.environ.get("POSTGRES_PORT", "5432"),
    "dbname": os.environ["POSTGRES_DB"],
    "user": os.environ["POSTGRES_USER"],
    "password": os.environ["POSTGRES_PASSWORD"],
}

consumer = KafkaConsumer(
    "stockpulse.sales",
    bootstrap_servers=["127.0.0.1:9092"],
    group_id="stockpulse-postgres-ingestion",
    auto_offset_reset="earliest",
    enable_auto_commit=False,
    value_deserializer=lambda value: json.loads(value.decode("utf-8")),
)

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

    sold_at = datetime.fromisoformat(
        str(event["sold_at"]).replace("Z", "+00:00")
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
            raise ValueError(f"{name} may have at most 2 decimal places")
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
        json.dumps(event),
    )



def persist_event(connection, event):
    event_id = (
        str(event.get("event_id"))[:100]
        if isinstance(event, dict) and event.get("event_id") is not None
        else None
    )

    try:
        values = validate_event(event)

    except (ValueError, TypeError, KeyError, OverflowError) as exc:
        with connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO kafka_rejected_events
                        (event_id, raw_payload, reason)
                    VALUES (%s, %s::jsonb, %s)
                    """,
                    (event_id, json.dumps(event), str(exc)),
                )

        print(f"Rejected invalid event {event_id}: {exc}")
        return

    with connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO kafka_sales_events (
                    event_id,
                    transaction_id,
                    sold_at,
                    sku,
                    quantity,
                    unit_price,
                    unit_cost,
                    raw_payload
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb)
                ON CONFLICT DO NOTHING
                RETURNING event_id
                """,
                values,
            )

            inserted = cursor.fetchone()

            if inserted:
                print(f"Stored new sales event {values[0]}")
            else:
                reason = (
                    "Duplicate sale: transaction_id and SKU already exist, "
                    "or this event_id has already been processed"
                )

                cursor.execute(
                    """
                    INSERT INTO kafka_rejected_events
                        (event_id, raw_payload, reason)
                    VALUES (%s, %s::jsonb, %s)
                    """,
                    (
                        event_id,
                        json.dumps(event),
                        reason,
                    ),
                )

                print(f"Rejected duplicate event {event_id}: {reason}")
                

connection = psycopg2.connect(**DB_CONFIG)

try:
    print("Connected to PostgreSQL.")
    print("Listening for Kafka sales events...")

    for message in consumer:
        # Invalid JSON can fail inside the deserializer before this
        # block is reached. We'll handle malformed JSON separately
        # when we build the dead-letter topic.
        persist_event(connection, message.value)

        # Commit the Kafka offset only after the database write succeeds.
        consumer.commit()

except KeyboardInterrupt:
    print("Consumer stopped.")
finally:
    consumer.close()
    connection.close()
