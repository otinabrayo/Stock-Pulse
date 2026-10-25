import json

from kafka import KafkaConsumer

consumer = KafkaConsumer(
    "stockpulse.sales",
    bootstrap_servers=["127.0.0.1:9092"],
    auto_offset_reset="earliest",
    enable_auto_commit=False,
    group_id="stockpulse-sales-debug",
    value_deserializer=lambda value: json.loads(value.decode("utf-8")),
)

print("Listening for StockPulse sales events... Press Ctrl+C to stop.")

try:
    for message in consumer:
        event = message.value

        print(
            f"Received event at partition={message.partition}, "
            f"offset={message.offset}"
        )
        print(json.dumps(event, indent=2))

        # This demo only prints events.
        # Commit only after a real database write succeeds.
        consumer.commit()
finally:
    consumer.close()
