#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

output_file="${1:-reports/consulta-relatorio.html}"
mkdir -p "$(dirname "$output_file")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

trino_query() {
  local sql="$1"
  docker compose exec -T trino \
    trino \
    --server http://localhost:8080 \
    --catalog lakehouse \
    --output-format CSV_HEADER \
    --execute "$sql"
}

render_query_section() {
  local title="$1"
  local subtitle="$2"
  local sql="$3"
  local csv_file="$tmp_dir/$(date +%s%N).csv"

  trino_query "$sql" > "$csv_file"

  python3 - "$title" "$subtitle" "$csv_file" >> "$output_file" <<'PY'
import csv
import html
import pathlib
import re
import sys
import unicodedata

title = sys.argv[1]
subtitle = sys.argv[2]
csv_path = pathlib.Path(sys.argv[3])

def slugify(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    without_accents = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", without_accents).strip("-").lower()
    return slug or "secao"

with csv_path.open(newline="", encoding="utf-8") as fh:
    rows = list(csv.reader(fh))

section_id = slugify(title)
print(f'<section class="section-card" id="{section_id}">')
print('<div class="section-header">')
print(f"<h2>{html.escape(title)}</h2>")
if subtitle:
    print(f'<p class="section-subtitle">{html.escape(subtitle)}</p>')
print("</div>")

if not rows:
    print('<p class="empty-state">Consulta sem retorno.</p>')
    print("</section>")
    raise SystemExit(0)

header = rows[0]
data_rows = rows[1:]

if not data_rows:
    print('<p class="empty-state">Consulta sem linhas.</p>')
    print("</section>")
    raise SystemExit(0)

print('<div class="table-wrap">')
print('<table class="result-table">')
print("<thead><tr>")
for col in header:
    print(f"<th>{html.escape(col)}</th>")
print("</tr></thead>")
print("<tbody>")

num_pattern = re.compile(r"^-?\d+(?:\.\d+)?$")

for row in data_rows:
    print("<tr>")
    for idx, value in enumerate(row):
        raw = value.strip()
        col_name = header[idx].strip().lower() if idx < len(header) else ""
        classes = []
        rendered = html.escape(value)
        lower = raw.lower()

        if lower in {"true", "false"}:
            classes.append("bool-cell")
            classes.append("bool-true" if lower == "true" else "bool-false")
            rendered = "Aprovado" if lower == "true" else "Falhou"
        elif num_pattern.match(raw):
            classes.append("num-cell")

        if col_name in {"passed", "status"} and lower in {"ok", "true", "false", "failed"}:
            classes.append("status-cell")

        class_attr = f' class="{" ".join(classes)}"' if classes else ""
        print(f"<td{class_attr}>{rendered}</td>")
    print("</tr>")

print("</tbody></table></div>")
print("</section>")
PY
}

cat > "$output_file" <<'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Relatório de Consultas - Medallion Landing Lab</title>
  <style>
    :root {
      --bg: #0b1020;
      --surface: #141b34;
      --surface-2: #1b2447;
      --text: #e8ecff;
      --muted: #9da9d8;
      --accent: #7c9cff;
      --accent-2: #54d2c0;
      --ok: #1fa971;
      --error: #d9536f;
      --border: #2e3b6f;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Inter", "Segoe UI", Roboto, Arial, sans-serif;
      background: radial-gradient(circle at top right, #223164 0%, var(--bg) 45%);
      color: var(--text);
      line-height: 1.5;
    }
    .container {
      max-width: 1300px;
      margin: 0 auto;
      padding: 28px 20px 40px;
    }
    .hero {
      background: linear-gradient(135deg, rgba(124, 156, 255, 0.2), rgba(84, 210, 192, 0.16));
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 20px 24px;
      margin-bottom: 20px;
    }
    .hero h1 {
      margin: 0 0 8px;
      font-size: 1.7rem;
      letter-spacing: 0.2px;
    }
    .hero p {
      margin: 0;
      color: var(--muted);
    }
    .toc {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin: 16px 0 24px;
    }
    .toc a {
      text-decoration: none;
      color: var(--text);
      background: rgba(124, 156, 255, 0.16);
      border: 1px solid rgba(124, 156, 255, 0.35);
      border-radius: 999px;
      font-size: 0.84rem;
      padding: 6px 12px;
    }
    .section-card {
      background: linear-gradient(180deg, rgba(27, 36, 71, 0.95), rgba(20, 27, 52, 0.95));
      border: 1px solid var(--border);
      border-radius: 14px;
      margin-bottom: 18px;
      overflow: hidden;
      box-shadow: 0 10px 24px rgba(0, 0, 0, 0.25);
    }
    .section-header {
      padding: 16px 18px 10px;
      border-bottom: 1px solid rgba(157, 169, 216, 0.2);
    }
    .section-header h2 {
      margin: 0;
      font-size: 1.1rem;
    }
    .section-subtitle {
      margin: 6px 0 0;
      color: var(--muted);
      font-size: 0.92rem;
    }
    .table-wrap {
      width: 100%;
      overflow-x: auto;
      padding: 12px 14px 16px;
    }
    .result-table {
      width: 100%;
      border-collapse: collapse;
      min-width: 840px;
    }
    .result-table th,
    .result-table td {
      border: 1px solid rgba(157, 169, 216, 0.24);
      padding: 8px 10px;
      vertical-align: top;
      font-size: 0.9rem;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .result-table th {
      background: var(--surface-2);
      color: #dbe4ff;
      position: sticky;
      top: 0;
      z-index: 1;
    }
    .result-table tbody tr:nth-child(odd) {
      background: rgba(255, 255, 255, 0.02);
    }
    .num-cell {
      text-align: right;
      font-variant-numeric: tabular-nums;
    }
    .bool-cell {
      text-align: center;
      font-weight: 600;
      border-radius: 6px;
    }
    .bool-true {
      color: #d5ffe8;
      background: rgba(31, 169, 113, 0.28);
    }
    .bool-false {
      color: #ffd9e1;
      background: rgba(217, 83, 111, 0.3);
    }
    .empty-state {
      margin: 0;
      padding: 12px 18px 18px;
      color: var(--muted);
    }
    .footer {
      margin-top: 24px;
      color: var(--muted);
      font-size: 0.82rem;
      text-align: right;
    }
  </style>
</head>
<body>
  <main class="container">
    <section class="hero">
      <h1>Relatório Executivo de Consultas</h1>
      <p>Consolidação das consultas da seção "Consultar" (Landing, Bronze, Silver, Gold, metadados Iceberg e validações de aceitação).</p>
    </section>
    <nav class="toc">
      <a href="#kpis-gerais">KPIs gerais</a>
      <a href="#landing-manifesto">Landing Manifesto</a>
      <a href="#bronze-orders-raw">Bronze Orders Raw</a>
      <a href="#bronze-documentos-extraidos">Bronze Documentos Extraídos</a>
      <a href="#silver-orders-unificados">Silver Orders Unificados</a>
      <a href="#silver-quarentena">Silver Quarentena</a>
      <a href="#gold-vendas-diarias">Gold Vendas Diárias</a>
      <a href="#validacoes-de-aceitacao">Validações de Aceitação</a>
      <a href="#iceberg-arquivos-da-tabela-gold">Iceberg Arquivos</a>
      <a href="#iceberg-snapshots">Iceberg Snapshots</a>
      <a href="#iceberg-history">Iceberg History</a>
    </nav>
HTML

render_query_section \
  "KPIs gerais" \
  "Indicadores consolidados da camada Gold" \
  "SELECT count(*) AS dias_com_vendas, sum(qtd_pedidos) AS pedidos_aprovados_total, sum(valor_aprovado) AS valor_aprovado_total, round(sum(valor_aprovado) / nullif(sum(qtd_pedidos), 0), 2) AS ticket_medio_geral FROM lakehouse.gold.daily_sales"

render_query_section \
  "Landing Manifesto" \
  "Arquivos recebidos na Landing Zone e catalogados na Bronze" \
  "SELECT object_key, data_family, media_type, object_size, etag FROM lakehouse.bronze.landing_manifest ORDER BY object_key"

render_query_section \
  "Bronze Orders Raw" \
  "Linhas estruturadas brutas, sem tratamento semântico" \
  "SELECT source_key, source_line, raw_line FROM lakehouse.bronze.orders_raw ORDER BY source_key, source_line"

render_query_section \
  "Bronze Documentos Extraídos" \
  "Textos extraídos de PDFs e imagens (OCR)" \
  "SELECT source_key, media_type, extraction_method, extraction_status, extracted_text FROM lakehouse.bronze.documents_extracted ORDER BY source_key"

render_query_section \
  "Silver Orders Unificados" \
  "Pedidos estruturados + pedidos extraídos de documentos, já padronizados" \
  "SELECT pedido_id, cliente_id, data_pedido, valor, status, source_type, source_key FROM lakehouse.silver.orders_unified ORDER BY pedido_id"

render_query_section \
  "Silver Quarentena" \
  "Registros rejeitados com motivo de erro de qualidade" \
  "SELECT source_key, source_line, raw_line, error_reason FROM lakehouse.silver.orders_quarantine ORDER BY source_line"

render_query_section \
  "Gold Vendas Diárias" \
  "Métrica final para consumo analítico" \
  "SELECT data_pedido, qtd_pedidos, valor_aprovado, ticket_medio FROM lakehouse.gold.daily_sales ORDER BY data_pedido"

render_query_section \
  "Validações de Aceitação" \
  "Conferência de contagem esperada por camada e soma de valor aprovado" \
  "WITH checks AS (SELECT 'landing_manifest' name, count(*) actual, 3 expected FROM lakehouse.bronze.landing_manifest UNION ALL SELECT 'bronze_orders', count(*), 7 FROM lakehouse.bronze.orders_raw UNION ALL SELECT 'bronze_documents', count(*), 2 FROM lakehouse.bronze.documents_extracted UNION ALL SELECT 'silver_orders', count(*), 4 FROM lakehouse.silver.orders UNION ALL SELECT 'quarantine', count(*), 2 FROM lakehouse.silver.orders_quarantine UNION ALL SELECT 'document_orders', count(*), 2 FROM lakehouse.silver.document_orders UNION ALL SELECT 'unified_orders', count(*), 6 FROM lakehouse.silver.orders_unified UNION ALL SELECT 'gold_dates', count(*), 3 FROM lakehouse.gold.daily_sales) SELECT name, actual, expected, actual = expected AS passed FROM checks ORDER BY name"

render_query_section \
  "Validação de Total Aprovado" \
  "Valor esperado consolidado da Gold (960.40)" \
  "SELECT sum(valor_aprovado) AS approved_total, sum(valor_aprovado) = DECIMAL '960.40' AS passed FROM lakehouse.gold.daily_sales"

render_query_section \
  "Iceberg Arquivos da tabela Gold" \
  "Detalhes físicos de arquivos Parquet da tabela daily_sales" \
  "SELECT file_path, file_format, record_count FROM lakehouse.gold.\"daily_sales\$files\""

render_query_section \
  "Iceberg Snapshots" \
  "Snapshots mais recentes e tipo de operação" \
  "SELECT committed_at, snapshot_id, operation FROM lakehouse.gold.\"daily_sales\$snapshots\" ORDER BY committed_at DESC"

render_query_section \
  "Iceberg History" \
  "Histórico de mudanças de snapshot da tabela daily_sales" \
  "SELECT * FROM lakehouse.gold.\"daily_sales\$history\" ORDER BY made_current_at DESC"

generated_at="$(date '+%Y-%m-%d %H:%M:%S %z')"

cat >> "$output_file" <<HTML
    <p class="footer">Relatório gerado automaticamente em ${generated_at}</p>
  </main>
</body>
</html>
HTML

echo "Relatório HTML gerado em: $output_file"
