from django.db import transaction
from django.utils import timezone
from .models import (
    IngestionRun,
    RejectedRecord,
    SaleRecord,
    Product,
)


def load_validation_result(run, result):
    """
    Persist a validated import atomically.

    Re-uploading an existing transaction/SKU combination
    will not create another sales record.
    """

    with transaction.atomic():
        RejectedRecord.objects.bulk_create([
            RejectedRecord(
                ingestion_run=run,
                source_row_number=row["source_row_number"],
                raw_data=row["raw_data"],
                reason=row["reason"][:500],
            )
            for row in result.rejected_rows
        ])

        # Insert only records that don't already exist.
        # The database unique constraint is the final guard
        # against duplicates.
        existing_keys = set(
            SaleRecord.objects.filter(
                transaction_id__in=[
                    row["transaction_id"]
                    for row in result.valid_rows
                ],
                sku__in=[
                    row["sku"]
                    for row in result.valid_rows
                ],
            ).values_list("transaction_id", "sku")
        )

        # Create dimension records for previously unseen SKUs.
        incoming_skus = {
            row["sku"]
            for row in result.valid_rows
        }

        existing_skus = set(
            Product.objects.filter(
                sku__in=incoming_skus
            ).values_list("sku", flat=True)
        )

        Product.objects.bulk_create(
            [
                Product(
                    sku=sku,
                    name=sku,
                    category="Uncategorised",
                )
                for sku in incoming_skus - existing_skus
            ],
            ignore_conflicts=True,
            batch_size=1000,
        )

        products_by_sku = {
            product.sku: product
            for product in Product.objects.filter(
                sku__in=incoming_skus
            )
        }

        new_sales = []

        for row in result.valid_rows:
            key = (row["transaction_id"], row["sku"])

            if key in existing_keys:
                continue

            new_sales.append(
                SaleRecord(
                    transaction_id=row["transaction_id"],
                    sold_at=row["sold_at"],
                    sku=row["sku"],
                    quantity=row["quantity"],
                    unit_price=row["unit_price"],
                    unit_cost=row["unit_cost"],
                    source_run=run,
                    product=products_by_sku[row["sku"]],
                )
            )

        SaleRecord.objects.bulk_create(
            new_sales,
            batch_size=1000,
            ignore_conflicts=True,
        )

        run.rows_read = result.rows_read
        run.rows_valid = result.rows_valid
        run.rows_rejected = result.rows_rejected
        run.status = IngestionRun.Status.SUCCEEDED
        run.error_message = ""
        run.completed_at = timezone.now()
        run.save()

    return {
        "rows_read": result.rows_read,
        "rows_validated": result.rows_valid,
        "rows_rejected": result.rows_rejected,
        "new_records_attempted": len(new_sales),
    }
