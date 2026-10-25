import json
from datetime import datetime, timezone
from uuid import uuid4

from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=["127.0.0.1:9092"],
    value_serializer=lambda value: json.dumps(value).encode("utf-8"),
    acks="all",
    retries=5,
)

sales_events = [
    {
        "event_id": str(uuid4()),
        "transaction_id": "TXN-KAFKA-001",
        "sold_at": datetime.now(timezone.utc).isoformat(),
        "sku": "SKU-001",
        "quantity": 2,
        "unit_price": 25.00,
        "unit_cost": 15.00,
    },
    {
        "event_id": str(uuid4()),
        "transaction_id": "TXN-KAFKA-002",
        "sold_at": datetime.now(timezone.utc).isoformat(),
        "sku": "SKU-002",
        "quantity": 3,
        "unit_price": 40.00,
        "unit_cost": 28.00,
    },
]

try:
    for event in sales_events:
        metadata = producer.send(
            "stockpulse.sales",
            key=event["transaction_id"].encode("utf-8"),
            value=event,
        ).get(timeout=10)

        print(
            f"Published {event['transaction_id']} "
            f"to {metadata.topic}, partition={metadata.partition}, "
            f"offset={metadata.offset}"
        )
finally:
    producer.flush()
    producer.close()
