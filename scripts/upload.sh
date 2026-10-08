#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 || ! "$1" =~ ^(structured|unstructured)$ ]]; then
  echo "Uso: $0 structured|unstructured /caminho/arquivo" >&2
  exit 2
fi
family="$1"; file="$2"
[[ -f "$file" ]] || { echo "Arquivo não encontrado: $file" >&2; exit 2; }
cd "$(dirname "$0")/.."
name="$(basename "$file")"
docker compose cp "$file" "minio-client:/tmp/$name"
docker compose exec -T minio-client mc cp "/tmp/$name" "lab/lakehouse/landing/$family/$name"
echo "Enviado para s3://lakehouse/landing/$family/$name"
