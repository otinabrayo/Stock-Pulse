import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

load_dotenv(Path(__file__).with_name(".env"))

connection = psycopg2.connect(
    host=os.environ["POSTGRES_HOST"],
    port=os.environ.get("POSTGRES_PORT", "5432"),
    dbname=os.environ["POSTGRES_DB"],
    user=os.environ["POSTGRES_USER"],
    password=os.environ["POSTGRES_PASSWORD"],
)

SQL = """
CREATE TABLE IF NOT EXISTS kafka_sales_events (
    event_id UUID PRIMARY KEY,
    transaction_id VARCHAR(100) NOT NULL,
    sold_at TIMESTAMPTZ NOT NULL,
    sku VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    unit_cost NUMERIC(12, 2) NOT NULL CHECK (unit_cost >= 0),
    raw_payload JSONB NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kafka_rejected_events (
    rejection_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id TEXT,
    raw_payload JSONB,
    reason TEXT NOT NULL,
    rejected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kafka_sales_sold_at
    ON kafka_sales_events (sold_at);

CREATE INDEX IF NOT EXISTS idx_kafka_sales_sku_sold_at
    ON kafka_sales_events (sku, sold_at);
"""

try:
    with connection:
        with connection.cursor() as cursor:
            cursor.execute(SQL)
    print("Kafka ingestion tables are ready.")
finally:
    connection.close()
