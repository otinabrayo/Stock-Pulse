from datetime import datetime, timedelta
from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator

default_args = {
    "owner": "stockpulse",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
}

DBT_DIR = "/opt/airflow/dbt-stock-pulse"

with DAG(
    dag_id="stockpulse_analytics",
    description="Build and test StockPulse analytical models",
    default_args=default_args,
    start_date=datetime(2026, 1, 1),
    schedule="0 2 * * *",
    catchup=False,
    max_active_runs=1,
    tags=["stockpulse", "dbt", "analytics"],
) as dag:

    check_database = BashOperator(
        task_id="check_database",
        bash_command=(
            "python -c \""
            "import os, psycopg2; "
            "conn = psycopg2.connect("
            "host='postgres', dbname='stockpulse', port=5432, "
            "user=os.environ['POSTGRES_USER'], "
            "password=os.environ['POSTGRES_PASSWORD']); "
            "conn.close(); "
            "print('PostgreSQL connection successful')\""
        ),
    )

    run_dbt = BashOperator(
        task_id="run_dbt_models",
        bash_command=f"dbt run --project-dir {DBT_DIR} --profiles-dir {DBT_DIR}",
    )

    test_dbt = BashOperator(
        task_id="test_dbt_models",
        bash_command=f"dbt test --project-dir {DBT_DIR} --profiles-dir {DBT_DIR}",
    )

    check_database >> run_dbt >> test_dbt
    