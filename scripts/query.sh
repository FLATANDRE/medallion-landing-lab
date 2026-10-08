#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
file="${1:-02_silver_gold.sql}"
docker compose exec -T trino trino --server http://localhost:8080 --catalog lakehouse --file "/lab/sql/$file"
