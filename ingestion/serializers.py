from rest_framework import serializers
from .models import IngestionRun, SaleRecord


class IngestionRunSerializer(serializers.ModelSerializer):
    class Meta:
        model = IngestionRun
        fields = [
            "id",
            "original_filename",
            "status",
            "rows_read",
            "rows_valid",
            "rows_rejected",
            "error_message",
            "validation_errors",
            "created_at",
            "completed_at",
        ]
        read_only_fields = fields


class SaleRecordSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(
        source="product.name",
        read_only=True,
        default="",
    )
    revenue = serializers.SerializerMethodField()
    gross_profit = serializers.SerializerMethodField()

    class Meta:
        model = SaleRecord
        fields = [
            "id",
            "transaction_id",
            "sold_at",
            "sku",
            "quantity",
            "unit_price",
            "unit_cost",
            "product_name",
            "revenue",
            "gross_profit",
        ]
        read_only_fields = fields

    def get_revenue(self, obj):
        return obj.quantity * obj.unit_price

    def get_gross_profit(self, obj):
        return obj.quantity * (obj.unit_price - obj.unit_cost)
