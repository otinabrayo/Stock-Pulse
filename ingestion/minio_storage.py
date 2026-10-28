import os
import uuid
import boto3
from botocore.config import Config
from datetime import datetime, timezone


MINIO_ENDPOINT = os.getenv(
    "MINIO_ENDPOINT_URL",  
    "http://localhost:9000",
)

MINIO_BUCKET = os.getenv(
    "MINIO_BUCKET_NAME",
    "stockpulse-raw",
)


def get_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=os.getenv("MINIO_ROOT_USER"),
        aws_secret_access_key=os.getenv("MINIO_ROOT_PASSWORD"),
        region_name=os.getenv("AWS_DEFAULT_REGION", "us-east-1"),
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},  # required for MinIO
        ),
    )


def upload_raw_file(uploaded_file, run_id=None, dataset_type="sales"):
    """
    Upload the original uploaded file to MinIO.

    run_id: the IngestionRun id, so the object can be traced to its run.
    dataset_type: sales, inventory, suppliers
    """
    ingestion_id = str(run_id) if run_id else str(uuid.uuid4())

    now = datetime.now(timezone.utc)
    timestamp_path = now.strftime("year=%Y/month=%m/day=%d")
    original_filename = os.path.basename(uploaded_file.name)

    object_key = (
        f"{dataset_type}/"
        f"{timestamp_path}/"
        f"{ingestion_id}/"
        f"{original_filename}"
    )

    uploaded_file.seek(0)

    get_s3_client().upload_fileobj(
        uploaded_file,
        MINIO_BUCKET,
        object_key,
        ExtraArgs={
            "ContentType": (
                getattr(uploaded_file, "content_type", None)
                or "application/octet-stream"
            ),
            "Metadata": {
                "ingestion-id": ingestion_id,
                "dataset-type": dataset_type,
                "original-filename": original_filename,
            },
        },
    )

    return {
        "ingestion_id": ingestion_id,
        "bucket": MINIO_BUCKET,
        "object_key": object_key,
        "original_filename": original_filename,
        "uploaded_at": now.isoformat(),
    }