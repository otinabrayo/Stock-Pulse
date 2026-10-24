from django.contrib import admin

# Register your models here.
from .models import IngestionRun


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
