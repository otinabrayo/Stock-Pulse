
import tempfile
from pathlib import Path

from django.test import SimpleTestCase

from .services import validate_sales_csv


class ValidateSalesCSVTests(SimpleTestCase):
    def test_valid_csv(self):
        content = (
            "transaction_id,sold_at,sku,quantity,"
            "unit_price,unit_cost\n"
            "TXN-1,2026-10-20 10:00:00,"
            "SKU-1,2,10.00,6.00\n"
        )

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sales.csv"
            path.write_text(content, encoding="utf-8")

            result = validate_sales_csv(path)

        self.assertEqual(result.rows_read, 1)
        self.assertEqual(result.rows_valid, 1)
        self.assertEqual(result.rows_rejected, 0)

    def test_invalid_quantity_is_rejected(self):
        content = (
            "transaction_id,sold_at,sku,quantity,"
            "unit_price,unit_cost\n"
            "TXN-1,2026-10-20 10:00:00,"
            "SKU-1,-2,10.00,6.00\n"
        )

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sales.csv"
            path.write_text(content, encoding="utf-8")

            result = validate_sales_csv(path)

        self.assertEqual(result.rows_read, 1)
        self.assertEqual(result.rows_valid, 0)
        self.assertEqual(result.rows_rejected, 1)
        self.assertTrue(result.errors)

    def test_missing_required_column_fails(self):
        content = (
            "transaction_id,sold_at,sku,quantity,unit_price\n"
            "TXN-1,2026-10-20 10:00:00,SKU-1,2,10.00\n"
        )

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sales.csv"
            path.write_text(content, encoding="utf-8")

            with self.assertRaises(ValueError):
                validate_sales_csv(path)
