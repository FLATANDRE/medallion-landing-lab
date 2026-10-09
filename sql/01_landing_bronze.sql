SELECT '** Landing Bronze **';

SELECT chr(10);

SELECT '** Exibindo dados da Landing Bronze **';
SELECT object_key, data_family, media_type, object_size, etag
FROM lakehouse.bronze.landing_manifest
ORDER BY object_key;

SELECT chr(10);

select '** Exibindo dados da Landing Bronze - Orders Raw **';
SELECT source_key, source_line, raw_line
FROM lakehouse.bronze.orders_raw
ORDER BY source_key, source_line;

SELECT chr(10);

SELECT '** Exibindo dados da Landing Bronze - Documents Extracted **';
SELECT source_key, media_type, extraction_method, extraction_status, extracted_text
FROM lakehouse.bronze.documents_extracted
ORDER BY source_key;
