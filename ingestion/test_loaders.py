from datetime import datetime, timezone as dt_timezone
from decimal import Decimal
from django.test import TestCase
from .loaders import load_validation_result
from .models import IngestionRun, SaleRecord
from .services import ValidationResult


class SalesLoaderTests(TestCase):
    def setUp(self):
        self.run = IngestionRun.objects.create(
            original_filename="sample_sales.csv",
            raw_file="test.csv",
        )

        self.result = ValidationResult(
            rows_read=1,
            valid_rows=[
                {
                    "transaction_id": "TXN-1001",
                    "sold_at": datetime(
                        2026, 10, 20, 10, 30,
                        tzinfo=dt_timezone.utc,
                    ),
                    "sku": "SKU-001",
                    "quantity": 3,
                    "unit_price": Decimal("25.00"),
                    "unit_cost": Decimal("15.00"),
                    "source_row_number": 2,
                }
            ],
            rejected_rows=[],
        )

    def test_valid_sale_is_loaded(self):
        summary = load_validation_result(
            self.run,
            self.result,
        )

        self.assertEqual(SaleRecord.objects.count(), 1)
        self.assertEqual(summary["new_records_attempted"], 1)

    def test_reimport_does_not_duplicate_sale(self):
        load_validation_result(self.run, self.result)

        second_run = IngestionRun.objects.create(
            original_filename="sample_sales.csv",
            raw_file="test.csv",
        )

        summary = load_validation_result(
            second_run,
            self.result,
        )

        self.assertEqual(SaleRecord.objects.count(), 1)
        self.assertEqual(summary["new_records_attempted"], 0)

    def test_rejected_rows_are_preserved(self):
        self.result.rejected_rows = [
            {
                "source_row_number": 3,
                "raw_data": {"sku": "SKU-BAD"},
                "reason": "Invalid quantity",
            }
        ]

        load_validation_result(self.run, self.result)

        self.assertEqual(
            self.run.rejected_records.count(),
            1,
        )
