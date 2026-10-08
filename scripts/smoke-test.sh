#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/run-local.sh all
bash scripts/query.sh 04_acceptance.sql
