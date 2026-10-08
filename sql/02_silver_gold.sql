SELECT pedido_id, cliente_id, data_pedido, valor, status, source_type, source_key
FROM lakehouse.silver.orders_unified
ORDER BY pedido_id;

SELECT source_key, source_line, raw_line, error_reason
FROM lakehouse.silver.orders_quarantine
ORDER BY source_line;

SELECT data_pedido, qtd_pedidos, valor_aprovado, ticket_medio
FROM lakehouse.gold.daily_sales
ORDER BY data_pedido;
