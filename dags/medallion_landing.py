from datetime import datetime

from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

DEFAULT_ARGS = {"owner": "data-engineering", "retries": 1}

with DAG(
    dag_id="medallion_landing_zone",
    description="Landing Zone, Bronze, Silver e Gold com dados estruturados e não estruturados",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args=DEFAULT_ARGS,
    tags=["medallion", "landing", "iceberg", "ocr"],
) as dag:
    def spark_task(stage):
        return SparkSubmitOperator(
            task_id=stage,
            conn_id="spark_default",
            application="/opt/airflow/jobs/medallion_pipeline.py",
            application_args=[stage],
            verbose=False,
        )

    inventory = spark_task("inventory")
    bronze_structured = spark_task("bronze_structured")
    bronze_unstructured = spark_task("bronze_unstructured")
    silver = spark_task("silver")
    gold = spark_task("gold")
    validate = spark_task("validate")

    inventory >> [bronze_structured, bronze_unstructured]
    [bronze_structured, bronze_unstructured] >> silver >> gold >> validate
