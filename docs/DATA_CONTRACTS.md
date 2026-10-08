# Contratos de dados

| Zona/camada | Objeto | Contrato |
|---|---|---|
| Landing | CSV, PDF e PNG | Arquivo original, chave e ETag preservados |
| Bronze | `landing_manifest` | Um registro por objeto e versão encontrada |
| Bronze | `orders_raw` | Uma linha por linha de dados do CSV |
| Bronze | `documents_extracted` | Metadados, método e texto extraído por documento |
| Silver | `orders` | Pedido CSV tipado, válido e deduplicado |
| Silver | `orders_quarantine` | Linha inválida com motivo |
| Silver | `document_orders` | Pedido interpretado de PDF/imagem |
| Silver | `orders_unified` | Uma versão por pedido, qualquer origem |
| Gold | `daily_sales` | Pedidos aprovados agregados por data |

## Resultados esperados

| Métrica | Valor |
|---|---:|
| Objetos na Landing | 3 |
| Linhas na Bronze estruturada | 7 |
| Documentos extraídos | 2 |
| Pedidos CSV válidos e únicos | 4 |
| Linhas CSV em quarentena | 2 |
| Pedidos derivados de documentos | 2 |
| Pedidos unificados | 6 |
| Datas na Gold | 3 |
| Valor aprovado total | 960,40 |
