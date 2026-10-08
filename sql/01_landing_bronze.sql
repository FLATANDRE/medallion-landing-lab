SELECT object_key, data_family, media_type, object_size, etag
FROM lakehouse.bronze.landing_manifest
ORDER BY object_key;

SELECT source_key, source_line, raw_line
FROM lakehouse.bronze.orders_raw
ORDER BY source_key, source_line;

SELECT source_key, media_type, extraction_method, extraction_status, extracted_text
FROM lakehouse.bronze.documents_extracted
ORDER BY source_key;
