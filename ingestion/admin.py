from django.contrib import admin
from .models import IngestionRun, Product, SaleRecord, RejectedRecord


@admin.register(IngestionRun)
class IngestionRunAdmin(admin.ModelAdmin):
    list_display = (
        "original_filename",
        "status",
        "rows_read",
        "rows_valid",
        "rows_rejected",
        "created_at",
    )
    list_filter = ("status",)
    search_fields = ("original_filename",)
    readonly_fields = (
        "id",
        "created_at",
        "completed_at",
    )


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("sku", "name", "category", "active")
    list_filter = ("category", "active")
    search_fields = ("sku", "name")
