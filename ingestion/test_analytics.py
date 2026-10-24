
from datetime import datetime, timezone as dt_timezone
from decimal import Decimal

from django.test import TestCase

from .analytics import sales_metrics
from .models import IngestionRun, Product, SaleRecord


class SalesAnalyticsTests(TestCase):
    def setUp(self):
        run = IngestionRun.objects.create(
            original_filename="analytics-test.csv",
            raw_file="analytics-test.csv",
        )

        product = Product.objects.create(
            sku="SKU-001",
            name="Test Product",
            category="General",
        )

        SaleRecord.objects.create(
            transaction_id="TXN-001",
            sold_at=datetime(
                2026, 10, 20, 10, 0,
                tzinfo=dt_timezone.utc,
            ),
            sku="SKU-001",
            product=product,
            quantity=3,
            unit_price=Decimal("25.00"),
            unit_cost=Decimal("15.00"),
            source_run=run,
        )

    def test_sales_metrics_reconcile(self):
        metrics = sales_metrics()

        self.assertEqual(metrics["transactions"], 1)
        self.assertEqual(metrics["sales_lines"], 1)
        self.assertEqual(metrics["units_sold"], 3)
        self.assertEqual(
            metrics["revenue"],
            Decimal("75.00"),
        )
        self.assertEqual(
            metrics["cost"],
            Decimal("45.00"),
        )
        self.assertEqual(
            metrics["gross_profit"],
            Decimal("30.00"),
        )
