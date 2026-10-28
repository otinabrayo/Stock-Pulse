import os
import requests
from django.utils import timezone


def trigger_stockpulse_dag(run):
    """
    Trigger the StockPulse analytics DAG after a successful ingestion.
    This function does not change the ingestion's database status.
    """
    base_url = os.getenv(
        "AIRFLOW_BASE_URL",
        "http://127.0.0.1:8080",
    ).rstrip("/")

    dag_id = os.getenv(
        "AIRFLOW_DAG_ID",
        "stockpulse_analytics",
    )

    try:
        token_response = requests.get(
            f"{base_url}/auth/token",
            timeout=10,
        )
        token_response.raise_for_status()

        token = token_response.json().get("access_token")
        if not token:
            return {
                "status": "failed",
                "message": "Airflow did not return an access token.",
            }

        dag_run_id = f"stockpulse_upload_{run.id}"

        payload = {
            "dag_run_id": dag_run_id,
            "logical_date": timezone.now().isoformat(),
            "conf": {
                "ingestion_run_id": str(run.id),
                "original_filename": run.original_filename,
                "bucket": run.raw_bucket,
                "object_key": run.raw_object_key,
            },
        }

        response = requests.post(
            f"{base_url}/api/v2/dags/{dag_id}/dagRuns",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
            timeout=15,
        )

        if response.status_code in (200, 201):
            return {
                "status": "triggered",
                "dag_run_id": dag_run_id,
            }

        return {
            "status": "failed",
            "message": (
                f"Airflow returned HTTP {response.status_code}."
            ),
        }

    except requests.RequestException as exc:
        # Do not expose request headers or authentication tokens.
        return {
            "status": "failed",
            "message": f"Could not contact Airflow: {type(exc).__name__}.",
        }
