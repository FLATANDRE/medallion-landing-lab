#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" != "--yes-delete-lab-data" ]]; then
  echo "Uso: $0 --yes-delete-lab-data" >&2
  exit 2
fi
docker compose down -v --remove-orphans
