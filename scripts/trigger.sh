#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T airflow-webserver airflow dags unpause medallion_landing_zone >/dev/null
docker compose exec -T airflow-webserver airflow dags trigger medallion_landing_zone
