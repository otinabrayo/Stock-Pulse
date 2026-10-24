import uuid
import pandas as pd
from pathlib import Path
from django.conf import settings
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import IngestionRun
from .serializers import IngestionRunSerializer
from .services import validate_sales_csv
from .loaders import load_validation_result


MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

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

        # Preserve the original upload in the raw directory.
        try:
            with raw_path.open("wb") as destination:
                for chunk in uploaded_file.chunks():
                    destination.write(chunk)

            run = IngestionRun.objects.create(
                id=run_id,
                original_filename=Path(
                    uploaded_file.name
                ).name[:255],
                raw_file=str(raw_path),
                status=IngestionRun.Status.PENDING,
            )


            result = validate_sales_csv(raw_path)

            summary = load_validation_result(run, result)
            run.refresh_from_db()

            return Response(
                {
                    "ingestion": IngestionRunSerializer(
                        run
                    ).data,
                    "summary": summary,
                    "validation_errors": result.errors,
                },
                status=status.HTTP_201_CREATED,
            )

        except (
            ValueError,
            pd.errors.ParserError,
            UnicodeDecodeError,
        ) as exc:
            run = IngestionRun.objects.filter(
                id=run_id
            ).first()

            if run is None:
                run = IngestionRun.objects.create(
                    id=run_id,
                    original_filename=Path(
                        uploaded_file.name
                    ).name[:255],
                    raw_file=str(raw_path),
                )

            run.status = IngestionRun.Status.FAILED
            run.error_message = str(exc)[:2000]
            run.completed_at = timezone.now()
            run.save()

            return Response(
                {
                    "ingestion": IngestionRunSerializer(
                        run
                    ).data,
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
