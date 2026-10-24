from rest_framework import serializers
from .models import IngestionRun


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
            "created_at",
            "completed_at",
        ]
        read_only_fields = fields
