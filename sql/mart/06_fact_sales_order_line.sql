-- Fact: Sales Order Line Items
-- Grain: 1 row per sales order line item
-- Joins: stg_sales_order + stg_sales_order_item + dimensions

DROP TABLE IF EXISTS mart.fact_sales_order_line CASCADE;
CREATE TABLE mart.fact_sales_order_line AS
SELECT
    ROW_NUMBER() OVER (ORDER BY oi.item_id) AS fact_key,
    oi.item_id,
    o.order_id,
    dc.customer_key,
    di.item_key,
    dw.warehouse_key,
    dd.date_id AS order_date_id,
    (TO_CHAR(COALESCE(o.delivery_date, o.posting_date), 'YYYYMMDD'))::INT AS delivery_date_id,
    o.status,
    o.company,
    o.territory,
    oi.qty,
    oi.net_amount,
    oi.amount,
    oi.discount_percentage,
    ROUND((oi.qty * oi.rate), 2) AS gross_amount,
    oi.rate AS unit_price,
    NOW() AS dw_load_date
FROM staging.stg_sales_order_item oi
INNER JOIN staging.stg_sales_order o ON oi.order_id = o.order_id
LEFT JOIN mart.dim_customer dc ON o.customer = dc.customer_id
LEFT JOIN mart.dim_item di ON oi.item_code = di.item_code
LEFT JOIN mart.dim_warehouse dw ON oi.warehouse = dw.warehouse_id
LEFT JOIN mart.dim_date dd ON o.posting_date = dd.full_date;

ALTER TABLE mart.fact_sales_order_line ADD PRIMARY KEY (fact_key);
CREATE INDEX idx_fact_sales_order_customer ON mart.fact_sales_order_line(customer_key);
CREATE INDEX idx_fact_sales_order_item ON mart.fact_sales_order_line(item_key);
CREATE INDEX idx_fact_sales_order_warehouse ON mart.fact_sales_order_line(warehouse_key);
CREATE INDEX idx_fact_sales_order_date ON mart.fact_sales_order_line(order_date_id);
CREATE INDEX idx_fact_sales_order_order ON mart.fact_sales_order_line(order_id);
