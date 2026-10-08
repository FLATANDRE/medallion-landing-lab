SELECT file_path, file_format, record_count
FROM lakehouse.gold."daily_sales$files";

SELECT committed_at, snapshot_id, operation
FROM lakehouse.gold."daily_sales$snapshots"
ORDER BY committed_at DESC;

SELECT *
FROM lakehouse.gold."daily_sales$history"
ORDER BY made_current_at DESC;
