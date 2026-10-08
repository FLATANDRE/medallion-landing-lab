#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
stage="${1:-all}"
docker compose exec -T airflow-scheduler spark-submit /opt/airflow/jobs/medallion_pipeline.py "$stage"
