#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose config --quiet
docker compose ps -a
docker compose exec -T minio-client mc ls --recursive lab/lakehouse/landing/
curl -fsS http://localhost:8181/v1/config >/dev/null && echo "REST catalog: OK"
curl -fsS http://localhost:8080/health >/dev/null && echo "Airflow: OK"
curl -fsS http://localhost:8081/v1/info >/dev/null && echo "Trino: OK"
