import json
import os
from datetime import timedelta
from pathlib import Path

import requests
from django.conf import settings
from django.db import DatabaseError, connection
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_GET
from kafka import KafkaAdminClient
from kafka.errors import KafkaError
from confluent_kafka import KafkaException
from confluent_kafka.admin import AdminClient
from .models import IngestionRun


KAFKA_BOOTSTRAP_SERVERS = os.getenv(
    "KAFKA_BOOTSTRAP_SERVERS",
    "127.0.0.1:9092",
).split(",")

AIRFLOW_HEALTH_URL = os.getenv(
    "AIRFLOW_HEALTH_URL",
    "http://127.0.0.1:8080/api/v2/monitor/health",
)

DBT_RESULTS_PATH = Path(
    os.getenv(
        "DBT_RESULTS_PATH",
        str(
            Path(settings.BASE_DIR)
            / "dbt-stock-pulse"
            / "target"
            / "run_results.json"
        ),
    )
)

# Results older than this are considered stale.
DBT_MAX_AGE = timedelta(hours=6)

REQUIRED_KAFKA_TOPICS = {
    "kafka_sales": "stockpulse.sales",
    "kafka_dead_letter_queue": "stockpulse.sales.dlq",
}

KAFKA_CONSUMER_GROUP = os.getenv(
    "KAFKA_CONSUMER_GROUP",
    "stockpulse-postgres-ingestion-v2",
)

def check_postgresql():
    try:
        connection.ensure_connection()

        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()

        return {"status": "Healthy"}

    except DatabaseError:
        return {
            "status": "Failed",
            "message": "PostgreSQL health check failed.",
        }


def check_django_ingestion(database_status):
    if database_status != "Healthy":
        return {
            "status": "Unknown",
            "message": "Cannot query ingestion history while the database is unavailable.",
            "latest_successful_run": None,
        }

    try:
        latest_success = (
            IngestionRun.objects
            .filter(status=IngestionRun.Status.SUCCEEDED)
            .order_by("-completed_at", "-created_at")
            .values("id", "original_filename", "completed_at")
            .first()
        )

        if not latest_success:
            return {
                "status": "Warning",
                "message": "No successful CSV ingestion run was found.",
                "latest_successful_run": None,
            }

        if latest_success["completed_at"]:
            latest_success["completed_at"] = (
                latest_success["completed_at"].isoformat()
            )

        return {
            "status": "Healthy",
            "latest_successful_run": latest_success,
        }

    except DatabaseError:
        return {
            "status": "Unknown",
            "message": "Could not retrieve ingestion history.",
            "latest_successful_run": None,
        }


def check_kafka():
    admin = None

    try:
        admin = KafkaAdminClient(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            request_timeout_ms=3000,
            client_id="stockpulse-health-check",
        )

        existing_topics = admin.list_topics()
        components = {}

        for component_name, topic_name in REQUIRED_KAFKA_TOPICS.items():
            if topic_name in existing_topics:
                components[component_name] = {
                    "status": "Healthy",
                    "topic": topic_name,
                    "message": (
                        "Kafka broker is reachable and the topic exists. "
                    ),
                }
            else:
                components[component_name] = {
                    "status": "Failed",
                    "topic": topic_name,
                    "message": "Required Kafka topic does not exist.",
                }

        return components

    except (KafkaError, OSError, Exception) as exc:
        # Keep the health endpoint available even when Kafka is down.
        message = f"Kafka health check failed: {type(exc).__name__}: {exc}"

        return {
            name: {
                "status": "Failed",
                "topic": topic,
                "message": message,
            }
            for name, topic in REQUIRED_KAFKA_TOPICS.items()
        }

    finally:
        if admin is not None:
            try:
                admin.close()
            except Exception:
                pass

def check_kafka_consumer():
    base = {"consumer_group": KAFKA_CONSUMER_GROUP}

    try:
        admin = AdminClient({
            "bootstrap.servers": ",".join(KAFKA_BOOTSTRAP_SERVERS),
            "socket.timeout.ms": 3000,
        })

        futures = admin.describe_consumer_groups(
            [KAFKA_CONSUMER_GROUP], request_timeout=3
        )
        group = futures[KAFKA_CONSUMER_GROUP].result()

        state = group.state.name.lower()      # stable, empty, dead, ...
        active_members = len(group.members)

        if state == "dead" or (state == "empty" and active_members == 0):
            return {**base, "status": "Warning", "group_state": state,
                    "active_members": 0,
                    "message": "No active consumer is connected."}

        if state != "stable":
            return {**base, "status": "Warning", "group_state": state,
                    "active_members": active_members,
                    "message": "Consumers are connected, but the group is not stable (it may be rebalancing)."}

        return {**base, "status": "Healthy", "group_state": state,
                "active_members": active_members,
                "message": "Kafka consumer group is active and stable."}

    except KafkaException as exc:
        return {**base, "status": "Failed",
                "message": f"Kafka consumer health check failed: {exc.args[0].name()}."}
    except Exception as exc:
        return {**base, "status": "Failed",
                "message": f"Kafka consumer health check failed: {type(exc).__name__}."}


def check_dbt():
    if not DBT_RESULTS_PATH.is_file():
        return {
            "status": "Unknown",
            "message": "dbt run_results.json was not found.",
            "results_file": str(DBT_RESULTS_PATH),
        }

    try:
        modified_at = timezone.datetime.fromtimestamp(
            DBT_RESULTS_PATH.stat().st_mtime,
            tz=timezone.get_current_timezone(),
        )
        age = timezone.now() - modified_at

        with DBT_RESULTS_PATH.open("r", encoding="utf-8") as file:
            results = json.load(file)

        run_results = results.get("results", [])
        statuses = [
            str(item.get("status", "")).lower()
            for item in run_results
        ]

        details = {
            "results_file": str(DBT_RESULTS_PATH),
            "last_modified": modified_at.isoformat(),
            "age_hours": round(age.total_seconds() / 3600, 2),
            "models_checked": len(run_results),
            "model_statuses": statuses,
        }

        if not run_results:
            return {
                **details,
                "status": "Warning",
                "message": "dbt results contain no model execution records.",
            }

        if any(
            status in {"error", "fail", "failed", "runtime error"}
            for status in statuses
        ):
            return {
                **details,
                "status": "Failed",
                "message": "The recorded dbt run contains failures.",
            }

        if age < timedelta(0) or age > DBT_MAX_AGE:
            return {
                **details,
                "status": "Warning",
                "message": "The dbt results file is stale.",
            }

        if any(status not in {"success", "pass", "skipped"} for status in statuses):
            return {
                **details,
                "status": "Warning",
                "message": "Some dbt result statuses need investigation.",
            }

        return {
            **details,
            "status": "Healthy",
            "message": "Recent dbt results contain no recorded failures.",
        }

    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return {
            "status": "Unknown",
            "message": "Could not read or parse dbt run results.",
            "results_file": str(DBT_RESULTS_PATH),
        }


def check_airflow():
    try:
        response = requests.get(AIRFLOW_HEALTH_URL, timeout=4)
        response.raise_for_status()
        payload = response.json()

        components = {
            "metadatabase": payload.get("metadatabase", {}).get("status"),
            "scheduler": payload.get("scheduler", {}).get("status"),
            "dag_processor": payload.get("dag_processor", {}).get("status"),
        }

        unhealthy = [
            name for name, status in components.items()
            if status != "healthy"
        ]

        if unhealthy:
            return {
                "status": "Failed",
                "message": (
                    "Airflow components are unhealthy or unreported: "
                    + ", ".join(unhealthy)
                ),
                "components": components,
            }

        return {
            "status": "Healthy",
            "message": (
                "Airflow metadata database, scheduler, and DAG processor "
                "are healthy."
            ),
            "components": components,
            "triggerer": payload.get("triggerer", {}).get("status"),
        }

    except (requests.RequestException, ValueError, TypeError) as exc:
        return {
            "status": "Failed",
            "message": f"Airflow health check failed: {type(exc).__name__}.",
        }


@require_GET
def pipeline_health(request):
    checked_at = timezone.now().isoformat()

    postgresql = check_postgresql()
    ingestion = check_django_ingestion(postgresql["status"])
    kafka_components = check_kafka()
    kafka_consumer = check_kafka_consumer()
    dbt = check_dbt()
    airflow = check_airflow()

    components = {
        "postgresql": postgresql,
        "django_csv_ingestion": ingestion,
        **kafka_components,
        "kafka_consumer": kafka_consumer,
        "dbt": dbt,
        "airflow": airflow,
    }

    statuses = [
        component.get("status", "Unknown")
        for component in components.values()
    ]

    if "Failed" in statuses:
        overall_status = "Failed"
    elif any(status != "Healthy" for status in statuses):
        overall_status = "Warning"
    else:
        overall_status = "Healthy"

    return JsonResponse({
        "checked_at": checked_at,
        "overall_status": overall_status,
        "components": components,
    })
