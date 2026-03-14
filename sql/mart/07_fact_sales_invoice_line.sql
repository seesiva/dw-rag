-- Fact: Sales Invoice Line Items
-- Grain: 1 row per sales invoice line item
-- Joins: stg_sales_invoice + stg_sales_invoice_item + dimensions

DROP TABLE IF EXISTS mart.fact_sales_invoice_line CASCADE;
CREATE TABLE mart.fact_sales_invoice_line AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ii.item_id) AS fact_key,
    ii.item_id,
    i.invoice_id,
    dc.customer_key,
    di.item_key,
    dw.warehouse_key,
    dd.date_id AS invoice_date_id,
    (TO_CHAR(COALESCE(i.due_date, i.posting_date), 'YYYYMMDD'))::INT AS due_date_id,
    i.is_return,
    i.company,
    i.territory,
    ii.qty,
    ii.net_amount,
    ii.amount,
    ii.discount_percentage,
    ROUND((ii.qty * ii.rate), 2) AS gross_amount,
    ii.rate AS unit_price,
    CASE WHEN i.is_return THEN -1 * ii.net_amount ELSE ii.net_amount END AS signed_net_amount,
    NOW() AS dw_load_date
FROM staging.stg_sales_invoice_item ii
INNER JOIN staging.stg_sales_invoice i ON ii.invoice_id = i.invoice_id
LEFT JOIN mart.dim_customer dc ON i.customer = dc.customer_id
LEFT JOIN mart.dim_item di ON ii.item_code = di.item_code
LEFT JOIN mart.dim_warehouse dw ON ii.warehouse = dw.warehouse_id
LEFT JOIN mart.dim_date dd ON i.posting_date = dd.full_date;

ALTER TABLE mart.fact_sales_invoice_line ADD PRIMARY KEY (fact_key);
CREATE INDEX idx_fact_sales_invoice_customer ON mart.fact_sales_invoice_line(customer_key);
CREATE INDEX idx_fact_sales_invoice_item ON mart.fact_sales_invoice_line(item_key);
CREATE INDEX idx_fact_sales_invoice_warehouse ON mart.fact_sales_invoice_line(warehouse_key);
CREATE INDEX idx_fact_sales_invoice_date ON mart.fact_sales_invoice_line(invoice_date_id);
CREATE INDEX idx_fact_sales_invoice_invoice ON mart.fact_sales_invoice_line(invoice_id);
CREATE INDEX idx_fact_sales_invoice_is_return ON mart.fact_sales_invoice_line(is_return);
