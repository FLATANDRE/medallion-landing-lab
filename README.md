# Laboratório Medallion com Landing Zone

Laboratório local com **Landing → Bronze → Silver → Gold**, capaz de receber CSV, PDF e imagem. O Airflow orquestra jobs PySpark; o Apache Iceberg gerencia tabelas com dados Parquet; o REST Catalog compartilha metadados; o MinIO armazena a Landing Zone e o warehouse; o Trino consulta os resultados.

## Pré-requisitos

- Docker Desktop ou Docker Engine com Compose v2.
- Bash; no Windows, use WSL2.
- Recomendação didática: 4 CPUs, 10 GB de RAM e 15 GB livres.

## Subir o laboratório

```bash
cp .env.example .env
bash scripts/up.sh
docker compose ps -a
```

A primeira construção baixa imagens, pacotes Python e JARs Maven. Aguarde `airflow-init` e `minio-init` terminarem com código zero.

| Serviço | URL | Credenciais |
|---|---|---|
| Airflow | http://localhost:8080 | `admin` / `adminlab123` |
| MinIO | http://localhost:9001 | `labadmin` / `labpassword123` |
| Trino | http://localhost:8081 | sem autenticação no laboratório |
| Iceberg REST | http://localhost:8181/v1/config | sem autenticação |

## Executar

Pelo Airflow, dispare `medallion_landing_zone`. O fluxo é:

```text
inventory -> [bronze_structured, bronze_unstructured] -> silver -> gold -> validate
```

Ou execute diretamente para diagnóstico, sem executar o DAG ao mesmo tempo:

```bash
bash scripts/run-local.sh all
```

## Consultar

```bash
bash scripts/query.sh 01_landing_bronze.sql
bash scripts/query.sh 02_silver_gold.sql
bash scripts/query.sh 03_iceberg_metadata.sql
bash scripts/query.sh 04_acceptance.sql
```

## Dados incluídos

- CSV: sete linhas; inclui duplicata, valor negativo e data inválida.
- PDF: pedido 1008 no valor de 320,50.
- PNG: pedido 1009 no valor de 89,90, extraído por OCR.

A Landing Zone fica em `s3://lakehouse/landing/`. Os binários originais continuam nela; a Bronze armazena inventário, linhas brutas e texto extraído.

## Resultado esperado

| Data | Pedidos aprovados | Valor aprovado | Ticket médio |
|---|---:|---:|---:|
| 2026-10-01 | 2 | 350,00 | 175,00 |
| 2026-10-02 | 2 | 520,50 | 260,25 |
| 2026-10-03 | 1 | 89,90 | 89,90 |

## Testes

```bash
bash scripts/smoke-test.sh
bash scripts/idempotency.sh
bash scripts/doctor.sh
```

## Enviar outro arquivo

```bash
bash scripts/upload.sh structured ./novo.csv
bash scripts/upload.sh unstructured ./novo.pdf
```

Depois do upload, execute novamente o DAG. Os testes de aceitação fornecidos usam exclusivamente os três arquivos originais; arquivos adicionais exigem ajustar as expectativas.

## Encerrar

```bash
docker compose down
```

Para apagar volumes e todo o estado:

```bash
bash scripts/reset.sh --yes-delete-lab-data
```

## Limites

Este é um ambiente didático: Spark local, credenciais fixas, catálogo REST de fixture, sem TLS e sem antivírus. Silver e Gold são reconstruídas integralmente. OCR em produção exige métricas de qualidade, revisão humana e proteção contra arquivos maliciosos.
