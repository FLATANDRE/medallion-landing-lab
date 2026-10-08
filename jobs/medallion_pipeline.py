import csv
import io
import os
import re
import sys
from datetime import datetime
from decimal import Decimal

import boto3
import pytesseract
from PIL import Image
from pypdf import PdfReader
from pyspark.sql import SparkSession, functions as F, types as T
from pyspark.sql.window import Window

CATALOG = "lakehouse"
BUCKET = os.getenv("MINIO_BUCKET", "lakehouse")
PREFIX = "landing/"

spark = SparkSession.builder.appName("medallion-landing-lab").getOrCreate()
spark.sparkContext.setLogLevel("WARN")

for namespace in ["bronze", "silver", "gold"]:
    spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {CATALOG}.{namespace}")

s3 = boto3.client(
    "s3",
    endpoint_url=os.getenv("MINIO_ENDPOINT", "http://minio:9000"),
    aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
    aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
    region_name=os.getenv("AWS_REGION", "us-east-1"),
)

def list_landing():
    rows = []
    token = None
    while True:
        args = {"Bucket": BUCKET, "Prefix": PREFIX}
        if token:
            args["ContinuationToken"] = token
        page = s3.list_objects_v2(**args)
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue
            ext = key.rsplit(".", 1)[-1].lower() if "." in key else ""
            family = "structured" if "/structured/" in f"/{key}" else "unstructured"
            media = {"csv": "text/csv", "pdf": "application/pdf", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg"}.get(ext, "application/octet-stream")
            rows.append((
                key, obj["ETag"].strip('"'), int(obj["Size"]),
                obj["LastModified"].replace(tzinfo=None), ext, family, media,
                f"s3://{BUCKET}/{key}", datetime.utcnow(),
            ))
        if not page.get("IsTruncated"):
            break
        token = page.get("NextContinuationToken")
    return rows

def merge_insert(df, table, keys):
    if not spark.catalog.tableExists(table):
        (df.writeTo(table).using("iceberg")
           .tableProperty("format-version", "2")
           .tableProperty("write.format.default", "parquet").create())
        return
    view = "incoming_" + table.split(".")[-1]
    df.createOrReplaceTempView(view)
    condition = " AND ".join([f"t.{k}=s.{k}" for k in keys])
    spark.sql(f"MERGE INTO {table} t USING {view} s ON {condition} WHEN NOT MATCHED THEN INSERT *")

def replace_table(df, table):
    (df.writeTo(table).using("iceberg")
       .tableProperty("format-version", "2")
       .tableProperty("write.format.default", "parquet").createOrReplace())

def inventory():
    schema = T.StructType([
        T.StructField("object_key", T.StringType(), False),
        T.StructField("etag", T.StringType(), False),
        T.StructField("object_size", T.LongType(), False),
        T.StructField("last_modified", T.TimestampType(), False),
        T.StructField("extension", T.StringType(), False),
        T.StructField("data_family", T.StringType(), False),
        T.StructField("media_type", T.StringType(), False),
        T.StructField("object_uri", T.StringType(), False),
        T.StructField("discovered_at", T.TimestampType(), False),
    ])
    rows = list_landing()
    if not rows:
        raise RuntimeError("A Landing Zone está vazia")
    merge_insert(spark.createDataFrame(rows, schema), f"{CATALOG}.bronze.landing_manifest", ["object_key", "etag"])

def bronze_structured():
    rows = []
    for key, etag, *_ in list_landing():
        if "/structured/" not in f"/{key}" or not key.lower().endswith(".csv"):
            continue
        body = s3.get_object(Bucket=BUCKET, Key=key)["Body"].read()
        lines = body.decode("utf-8-sig").splitlines()
        for line_number, raw_line in enumerate(lines[1:], 2):
            rows.append((key, etag, line_number, raw_line, datetime.utcnow()))
    schema = "source_key string, source_etag string, source_line int, raw_line string, ingested_at timestamp"
    if not rows:
        raise RuntimeError("Nenhum CSV encontrado em landing/structured")
    merge_insert(spark.createDataFrame(rows, schema), f"{CATALOG}.bronze.orders_raw", ["source_key", "source_etag", "source_line"])

def extract_pdf(data):
    reader = PdfReader(io.BytesIO(data))
    return "\n".join((page.extract_text() or "") for page in reader.pages), "pypdf"

def extract_image(data):
    image = Image.open(io.BytesIO(data))
    fallback = image.info.get("Description", "")
    try:
        text = pytesseract.image_to_string(image, lang="por", config="--psm 6")
        if re.search(r"PEDIDO\s*[:=-]?\s*\d+", text, re.I):
            return text, "tesseract-ocr"
        if fallback:
            return fallback, "png-metadata-fallback"
        return text, "tesseract-ocr"
    except Exception:
        if fallback:
            return fallback, "png-metadata-fallback"
        raise

def bronze_unstructured():
    rows = []
    for key, etag, size, _, ext, family, media, _, _ in list_landing():
        if family != "unstructured":
            continue
        method, text, status, error = "unsupported", "", "unsupported", None
        try:
            data = s3.get_object(Bucket=BUCKET, Key=key)["Body"].read()
            if ext == "pdf":
                text, method = extract_pdf(data)
                status = "success"
            elif ext in {"png", "jpg", "jpeg"}:
                text, method = extract_image(data)
                status = "success"
        except Exception as exc:
            status, error = "error", str(exc)[:1000]
        rows.append((key, etag, size, media, method, text.strip(), status, error, datetime.utcnow()))
    schema = "source_key string, source_etag string, object_size long, media_type string, extraction_method string, extracted_text string, extraction_status string, error_message string, extracted_at timestamp"
    if not rows:
        raise RuntimeError("Nenhum PDF ou imagem encontrado em landing/unstructured")
    merge_insert(spark.createDataFrame(rows, schema), f"{CATALOG}.bronze.documents_extracted", ["source_key", "source_etag"])

def silver():
    raw = spark.table(f"{CATALOG}.bronze.orders_raw")
    csv_schema = "pedido_id_raw STRING, cliente_id_raw STRING, data_pedido_raw STRING, valor_raw STRING, status_raw STRING, updated_at_raw STRING"
    parsed = (raw.withColumn("parsed", F.from_csv("raw_line", csv_schema, {"mode": "PERMISSIVE"}))
        .select("source_key", "source_etag", "source_line", "raw_line", "parsed.*")
        .selectExpr(
            "source_key", "source_etag", "source_line", "raw_line",
            "try_cast(pedido_id_raw AS BIGINT) pedido_id",
            "try_cast(cliente_id_raw AS BIGINT) cliente_id",
            "try_cast(data_pedido_raw AS DATE) data_pedido",
            "try_cast(valor_raw AS DECIMAL(12,2)) valor",
            "lower(trim(status_raw)) status",
            "try_cast(updated_at_raw AS TIMESTAMP) updated_at"))
    valid = F.coalesce(
        (F.col("pedido_id") > 0) & (F.col("cliente_id") > 0) &
        F.col("data_pedido").isNotNull() & F.col("updated_at").isNotNull() &
        (F.col("valor") >= 0) & F.col("status").isin("aprovado", "cancelado"), F.lit(False))
    checked = parsed.withColumn("is_valid", valid)
    reasons = F.concat_ws("; ",
        F.when(F.col("pedido_id").isNull() | (F.col("pedido_id") <= 0), "pedido_id inválido"),
        F.when(F.col("cliente_id").isNull() | (F.col("cliente_id") <= 0), "cliente_id inválido"),
        F.when(F.col("data_pedido").isNull(), "data inválida"),
        F.when(F.col("valor").isNull() | (F.col("valor") < 0), "valor inválido"),
        F.when(~F.col("status").isin("aprovado", "cancelado") | F.col("status").isNull(), "status inválido"),
        F.when(F.col("updated_at").isNull(), "updated_at inválido"))
    replace_table(checked.filter(~F.col("is_valid")).withColumn("error_reason", reasons), f"{CATALOG}.silver.orders_quarantine")
    window = Window.partitionBy("pedido_id").orderBy(F.col("updated_at").desc(), F.col("source_etag").desc(), F.col("source_line").desc())
    orders = (checked.filter("is_valid").withColumn("rn", F.row_number().over(window)).filter("rn=1")
        .select("pedido_id", "cliente_id", "data_pedido", "valor", "status", "updated_at", "source_key", "source_etag"))
    replace_table(orders, f"{CATALOG}.silver.orders")

    docs = spark.table(f"{CATALOG}.bronze.documents_extracted").filter("extraction_status='success'")
    def rex(pattern):
        return F.regexp_extract("extracted_text", pattern, 1)
    doc_parsed = (docs
        .withColumn("pedido_raw", rex(r"(?i)PEDIDO(?:_ID)?\s*[:=-]?\s*(\d+)"))
        .withColumn("cliente_raw", rex(r"(?i)CLIENTE(?:_ID)?\s*[:=-]?\s*(\d+)"))
        .withColumn("data_raw", rex(r"(?i)DATA\s*[:=-]?\s*(\d{4}-\d{2}-\d{2})"))
        .withColumn("valor_raw", rex(r"(?i)VALOR\s*[:=-]?\s*([0-9]+[\.,][0-9]{2})"))
        .withColumn("status_raw", rex(r"(?i)STATUS\s*[:=-]?\s*([A-ZÇÃÕ]+)"))
        .withColumn("updated_raw", rex(r"(?i)ATUALIZADO\s*[:=-]?\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})"))
        .selectExpr(
            "source_key", "source_etag", "media_type", "extraction_method", "extracted_text",
            "try_cast(pedido_raw AS BIGINT) pedido_id",
            "try_cast(cliente_raw AS BIGINT) cliente_id",
            "try_cast(data_raw AS DATE) data_pedido",
            "try_cast(replace(valor_raw, ',', '.') AS DECIMAL(12,2)) valor",
            "lower(status_raw) status",
            "try_cast(updated_raw AS TIMESTAMP) updated_at"))
    doc_valid = F.coalesce(
        (F.col("pedido_id") > 0) & (F.col("cliente_id") > 0) & F.col("data_pedido").isNotNull() &
        (F.col("valor") >= 0) & F.col("status").isin("aprovado", "cancelado") & F.col("updated_at").isNotNull(), F.lit(False))
    docs_checked = doc_parsed.withColumn("is_valid", doc_valid)
    replace_table(docs_checked, f"{CATALOG}.silver.documents_parsed")
    replace_table(docs_checked.filter("is_valid").drop("is_valid"), f"{CATALOG}.silver.document_orders")

def gold():
    structured = (spark.table(f"{CATALOG}.silver.orders")
        .select("pedido_id", "cliente_id", "data_pedido", "valor", "status", "updated_at", "source_key")
        .withColumn("source_type", F.lit("csv")))
    documents = (spark.table(f"{CATALOG}.silver.document_orders")
        .select("pedido_id", "cliente_id", "data_pedido", "valor", "status", "updated_at", "source_key")
        .withColumn("source_type", F.lit("document")))
    unified = structured.unionByName(documents)
    window = Window.partitionBy("pedido_id").orderBy(F.col("updated_at").desc(), F.col("source_type").desc())
    unified = unified.withColumn("rn", F.row_number().over(window)).filter("rn=1").drop("rn")
    replace_table(unified, f"{CATALOG}.silver.orders_unified")
    daily = (unified.filter("status='aprovado'").groupBy("data_pedido")
        .agg(F.count("*").alias("qtd_pedidos"), F.sum("valor").alias("valor_aprovado"))
        .withColumn("ticket_medio", (F.col("valor_aprovado") / F.col("qtd_pedidos")).cast("decimal(14,2)")))
    replace_table(daily, f"{CATALOG}.gold.daily_sales")

def validate():
    expected = {
        f"{CATALOG}.bronze.landing_manifest": 3,
        f"{CATALOG}.bronze.orders_raw": 7,
        f"{CATALOG}.bronze.documents_extracted": 2,
        f"{CATALOG}.silver.orders": 4,
        f"{CATALOG}.silver.orders_quarantine": 2,
        f"{CATALOG}.silver.document_orders": 2,
        f"{CATALOG}.silver.orders_unified": 6,
        f"{CATALOG}.gold.daily_sales": 3,
    }
    for table, count in expected.items():
        actual = spark.table(table).count()
        assert actual == count, f"{table}: esperado={count}, atual={actual}"
    total = spark.table(f"{CATALOG}.gold.daily_sales").agg(F.sum("valor_aprovado")).first()[0]
    assert Decimal(str(total)) == Decimal("960.40"), f"Total inesperado: {total}"
    failed = spark.table(f"{CATALOG}.bronze.documents_extracted").filter("extraction_status <> 'success'").count()
    assert failed == 0, f"Extrações com falha: {failed}"
    print("VALIDATION_OK: Landing=3; Bronze rows=7; docs=2; unified=6; approved_total=960.40")

stages = {
    "inventory": inventory,
    "bronze_structured": bronze_structured,
    "bronze_unstructured": bronze_unstructured,
    "silver": silver,
    "gold": gold,
    "validate": validate,
}

def run_all():
    for name in ["inventory", "bronze_structured", "bronze_unstructured", "silver", "gold", "validate"]:
        stages[name]()

if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else "all"
    run_all() if stage == "all" else stages[stage]()
    spark.stop()
