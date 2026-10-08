# Arquitetura

```text
Produtores
  ├─ CSV ----------------------------┐
  ├─ PDF ----------------------------┤
  └─ imagem -------------------------┤
                                    v
MinIO / landing/ (pré-Bronze, objetos originais)
  ├─ structured/orders/*.csv
  └─ unstructured/{documents,images}/*
                                    |
                                    v
Airflow -> PySpark
  ├─ Bronze: manifesto, linhas CSV brutas e texto extraído
  ├─ Silver: pedidos validados, quarentena e documentos interpretados
  └─ Gold: vendas aprovadas por dia
                                    |
                          Iceberg REST Catalog
                                    |
                       Parquet + metadados no MinIO
                                    |
                                  Trino
```

## Fronteira da Landing Zone

A Landing Zone guarda os objetos originais antes de qualquer transformação. O laboratório separa `structured/` e `unstructured/`, preserva PDF e PNG, e cria um manifesto Iceberg na Bronze. O pipeline não modifica os objetos de entrada.

## Não estruturados

O PDF possui texto pesquisável e é lido por `pypdf`. A imagem é processada por Tesseract OCR. Para tornar o exercício reproduzível, o PNG inclui o mesmo texto em metadados e o job utiliza esse conteúdo apenas se o OCR não reconhecer o campo `PEDIDO`.
