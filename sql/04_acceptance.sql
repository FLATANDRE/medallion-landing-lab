WITH checks AS (
    SELECT 'landing_manifest' name, count(*) actual, 3 expected FROM lakehouse.bronze.landing_manifest
    UNION ALL SELECT 'bronze_orders', count(*), 7 FROM lakehouse.bronze.orders_raw
    UNION ALL SELECT 'bronze_documents', count(*), 2 FROM lakehouse.bronze.documents_extracted
    UNION ALL SELECT 'silver_orders', count(*), 4 FROM lakehouse.silver.orders
    UNION ALL SELECT 'quarantine', count(*), 2 FROM lakehouse.silver.orders_quarantine
    UNION ALL SELECT 'document_orders', count(*), 2 FROM lakehouse.silver.document_orders
    UNION ALL SELECT 'unified_orders', count(*), 6 FROM lakehouse.silver.orders_unified
    UNION ALL SELECT 'gold_dates', count(*), 3 FROM lakehouse.gold.daily_sales
)
SELECT name, actual, expected, actual = expected AS passed FROM checks ORDER BY name;

SELECT sum(valor_aprovado) AS approved_total,
       sum(valor_aprovado) = DECIMAL '960.40' AS passed
FROM lakehouse.gold.daily_sales;
