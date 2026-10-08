# Dados da Landing Zone

- `structured/orders/orders_2026-10-01.csv`: sete linhas estruturadas.
- `unstructured/documents/order_1008.pdf`: comprovante PDF com texto pesquisável.
- `unstructured/images/order_1009.png`: comprovante em imagem para OCR.

O serviço `minio-init` envia esses três objetos para `s3://lakehouse/landing/`.
