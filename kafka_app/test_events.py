import json
import os
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=[os.getenv("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092")],
)

messages = [
    # Invalid JSON
    b'{"transaction_id": ',

    # Valid JSON but missing required fields
    json.dumps({
        "event_id": "not-a-valid-event",
        "transaction_id": "TXN-BAD-001",
    }).encode("utf-8"),

    # Duplicate of a test sale: use a transaction/SKU already in PostgreSQL
    json.dumps({
        "event_id": "f9307c52-b9df-48c7-85c6-58e6f7640001",
        "transaction_id": "TXN-KAFKA-001",
        "sold_at": "2026-10-25T10:00:00+00:00",
        "sku": "SKU-001",
        "quantity": 2,
        "unit_price": 25.00,
        "unit_cost": 15.00,
    }).encode("utf-8"),
]

try:
    for message in messages:
        result = producer.send("stockpulse.sales", value=message)
        metadata = result.get(timeout=10)
        print(f"Sent test message to {metadata.topic}, offset={metadata.offset}")
finally:
    producer.flush()
    producer.close()
