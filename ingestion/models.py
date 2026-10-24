import uuid
from django.db import models
from django.db.models import Q


class IngestionRun(models.Model):
    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        SUCCEEDED = "SUCCEEDED", "Succeeded"
        FAILED = "FAILED", "Failed"

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
    )
    original_filename = models.CharField(max_length=255)
    raw_file = models.FileField(upload_to="", max_length=500)

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
    )

    rows_read = models.PositiveIntegerField(default=0)
    rows_valid = models.PositiveIntegerField(default=0)
    rows_rejected = models.PositiveIntegerField(default=0)

    error_message = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.original_filename} ({self.status})"


class Product(models.Model):
    sku = models.CharField(max_length=100, unique=True)
    name = models.CharField(max_length=200)
    category = models.CharField(
        max_length=100,
        default="Uncategorised",
    )
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["sku"]

    def __str__(self):
        return f"{self.sku} - {self.name}"


class SaleRecord(models.Model):
    """
    A validated sales line in the analytical data layer.

    A source transaction can contain multiple products,
    but each transaction/SKU pair is unique.
    """

    id = models.BigAutoField(primary_key=True)

    transaction_id = models.CharField(max_length=150)
    sold_at = models.DateTimeField()
    sku = models.CharField(max_length=100)

    quantity = models.PositiveIntegerField()
    unit_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
    )
    unit_cost = models.DecimalField(
        max_digits=12,
        decimal_places=2,
    )

    source_run = models.ForeignKey(
        IngestionRun,
        on_delete=models.PROTECT,
        related_name="sales",
    )

    created_at = models.DateTimeField(auto_now_add=True)

    product = models.ForeignKey(
        Product,
        on_delete=models.PROTECT,
        related_name="sales",
        null=True,
        blank=True,
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["transaction_id", "sku"],
                name="uniq_sale_transaction_sku",
            ),
            models.CheckConstraint(
                condition=Q(quantity__gt=0),
                name="sale_quantity_positive",
            ),
            models.CheckConstraint(
                condition=Q(unit_price__gte=0),
                name="sale_unit_price_nonnegative",
            ),
            models.CheckConstraint(
                condition=Q(unit_cost__gte=0),
                name="sale_unit_cost_nonnegative",
            ),
        ]
        indexes = [
            models.Index(
                fields=["sold_at"],
                name="sale_sold_at_idx",
            ),
            models.Index(
                fields=["sku", "sold_at"],
                name="sale_sku_date_idx",
            ),
        ]

    def __str__(self):
        return f"{self.transaction_id} - {self.sku}"


class RejectedRecord(models.Model):
    """
    Stores rejected source rows for investigation and reprocessing.
    """

    id = models.BigAutoField(primary_key=True)

    ingestion_run = models.ForeignKey(
        IngestionRun,
        on_delete=models.PROTECT,
        related_name="rejected_records",
    )

    source_row_number = models.PositiveIntegerField()
    raw_data = models.JSONField()
    reason = models.CharField(max_length=500)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(
                fields=["ingestion_run", "source_row_number"],
                name="reject_run_row_idx",
            ),
        ]

    def __str__(self):
        return (
            f"Rejected row {self.source_row_number} "
            f"in {self.ingestion_run_id}"
        )
