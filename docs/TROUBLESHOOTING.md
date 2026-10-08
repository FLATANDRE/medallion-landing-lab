# Diagnóstico

## O DAG não aparece

```bash
docker compose logs --tail=200 airflow-scheduler
docker compose exec airflow-scheduler airflow dags list-import-errors
```

## O catálogo não responde

```bash
docker compose logs --tail=200 rest
curl http://localhost:8181/v1/config
```

## Falha no OCR

```bash
docker compose exec airflow-scheduler tesseract --version
docker compose exec airflow-scheduler tesseract --list-langs
```

O PNG contém um fallback textual em metadados para que o laboratório continue determinístico.

## Reset completo

```bash
bash scripts/reset.sh --yes-delete-lab-data
bash scripts/up.sh
```
