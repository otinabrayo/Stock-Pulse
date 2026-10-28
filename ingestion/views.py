import uuid
import pandas as pd
from pathlib import Path
from botocore.exceptions import BotoCoreError, ClientError
from django.conf import settings
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import IngestionRun, SaleRecord
from .serializers import IngestionRunSerializer, SaleRecordSerializer
from .services import validate_sales_csv
from .loaders import load_validation_result
from datetime import datetime, time, timedelta
from decimal import Decimal
from django.db.models import DecimalField, ExpressionWrapper, F, Sum
from .airflow_client import trigger_stockpulse_dag
from .minio_storage import upload_raw_file

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
MONEY_FIELD = DecimalField(max_digits=20, decimal_places=2)


class SalesCSVUploadView(APIView):
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        uploaded_file = request.FILES.get("file")

        if uploaded_file is None:
            return Response(
                {"error": "Upload a CSV using the 'file' field."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if uploaded_file.size > MAX_FILE_SIZE:
            return Response(
                {"error": "Maximum upload size is 10 MB."},
                status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            )

        if Path(uploaded_file.name).suffix.lower() != ".csv":
            return Response(
                {"error": "Only CSV files are supported."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        raw_root = Path(settings.DATA_RAW_ROOT)
        raw_root.mkdir(parents=True, exist_ok=True)

        run_id = uuid.uuid4()
        safe_filename = f"{run_id}.csv"
        raw_path = raw_root / safe_filename

        try:
            # 1. Save a local processing copy for the validator.
            with raw_path.open("wb") as destination:
                for chunk in uploaded_file.chunks():
                    destination.write(chunk)

            # 2. Upload the original CSV to MinIO.
            uploaded_file.seek(0)
            raw_storage = upload_raw_file(
                uploaded_file=uploaded_file,
                run_id=run_id,
            )

            # 3. Create the ingestion record with MinIO metadata.
            run = IngestionRun.objects.create(
                id=run_id,
                original_filename=Path(uploaded_file.name).name[:255],
                raw_file=str(raw_path),
                raw_bucket=raw_storage["bucket"],
                raw_object_key=raw_storage["object_key"],
                status=IngestionRun.Status.PENDING,
            )

            # 4. Validate and load.
            result = validate_sales_csv(raw_path)
            summary = load_validation_result(run, result)

            # 5. Persist row-level validation errors.
            run.validation_errors = [
                {
                    "row": rejected["source_row_number"],
                    "reason": rejected["reason"],
                }
                for rejected in result.rejected_rows
            ]
            run.save(update_fields=["validation_errors"])
            run.refresh_from_db()

            # 6. Trigger analytics only after successful ingestion.
            pipeline_trigger = {
                "status": "skipped",
                "message": "Ingestion did not succeed.",
            }

            if run.status == IngestionRun.Status.SUCCEEDED:
                pipeline_trigger = trigger_stockpulse_dag(run)

            return Response(
                {
                    "ingestion": IngestionRunSerializer(run).data,
                    "summary": summary,
                    "validation_errors": run.validation_errors,
                    "pipeline_trigger": pipeline_trigger,
                },
                status=status.HTTP_201_CREATED,
            )

        except (
            ValueError,
            pd.errors.ParserError,
            UnicodeDecodeError,
            BotoCoreError,
            ClientError,
        ) as exc:
            run = IngestionRun.objects.filter(id=run_id).first()

            if run is None:
                run = IngestionRun.objects.create(
                    id=run_id,
                    original_filename=Path(uploaded_file.name).name[:255],
                    raw_file=str(raw_path),
                )

            run.status = IngestionRun.Status.FAILED
            run.error_message = str(exc)[:2000]
            run.completed_at = timezone.now()
            run.save()

            return Response(
                {
                    "ingestion": IngestionRunSerializer(run).data,
                    "error": str(exc),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )


class IngestionRunListView(generics.ListAPIView):
    queryset = IngestionRun.objects.all()
    serializer_class = IngestionRunSerializer


class IngestionRunDetailView(generics.RetrieveAPIView):
    queryset = IngestionRun.objects.all()
    serializer_class = IngestionRunSerializer
    lookup_field = "id"


class SaleRecordListView(generics.ListAPIView):
    serializer_class = SaleRecordSerializer

    def get_queryset(self):
        return (
            SaleRecord.objects
            .select_related("product")
            .order_by("-sold_at", "-id")
        )


def get_period_metrics(start_date, end_date):
    """
    Calculate metrics for start_date inclusive and end_date exclusive.
    The dates are interpreted in Django's current timezone.
    """
    start_datetime = timezone.make_aware(
        datetime.combine(start_date, time.min)
    )
    end_datetime = timezone.make_aware(
        datetime.combine(end_date, time.min)
    )

    sales = SaleRecord.objects.filter(
        sold_at__gte=start_datetime,
        sold_at__lt=end_datetime,
    )

    revenue_expression = ExpressionWrapper(
        F("quantity") * F("unit_price"),
        output_field=MONEY_FIELD,
    )

    cost_expression = ExpressionWrapper(
        F("quantity") * F("unit_cost"),
        output_field=MONEY_FIELD,
    )

    totals = sales.aggregate(
        revenue=Sum(revenue_expression),
        cost=Sum(cost_expression),
        units_sold=Sum("quantity"),
    )

    revenue = totals["revenue"] or Decimal("0.00")
    cost = totals["cost"] or Decimal("0.00")

    return {
        "revenue": revenue,
        "gross_profit": revenue - cost,
        "transactions": sales.values("transaction_id").distinct().count(),
        "units_sold": totals["units_sold"] or 0,
    }


class MonthlyComparisonAPIView(APIView):
    def get(self, request):
        today = timezone.localdate()

        current_start = today.replace(day=1)
        current_end = today + timedelta(days=1)  # Exclusive

        previous_month_last_day = current_start - timedelta(days=1)
        previous_start = previous_month_last_day.replace(day=1)
        previous_end = current_start  # Exclusive

        current = get_period_metrics(current_start, current_end)
        previous = get_period_metrics(previous_start, previous_end)

        return Response({
            "current": {
                **current,
                "revenue": str(current["revenue"]),
                "gross_profit": str(current["gross_profit"]),
            },
            "previous": {
                **previous,
                "revenue": str(previous["revenue"]),
                "gross_profit": str(previous["gross_profit"]),
            },
            "periods": {
                "current_start": current_start.isoformat(),
                "current_end": today.isoformat(),
                "previous_start": previous_start.isoformat(),
                "previous_end": previous_month_last_day.isoformat(),
            },
        })
        