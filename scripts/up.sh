#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || cp .env.example .env
docker compose config --quiet
docker compose up -d --build
printf '
Airflow: http://localhost:8080
MinIO:  http://localhost:9001
Trino:  http://localhost:8081
'
