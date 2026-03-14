-- Operational Readiness: Sales Order Fulfillment Tracking
-- Grain: 1 row per sales order
-- Purpose: Identifies orders due for delivery that are unfulfilled, overdue, or have fulfillment gaps
-- Source: stg_sales_order + stg_sales_order_item + dimensions

DROP TABLE IF EXISTS mart.fact_sales_order_readiness CASCADE;
CREATE TABLE mart.fact_sales_order_readiness AS
WITH order_summary AS (
    -- Aggregate quantities by order
    SELECT
        o.order_id,
        o.customer,
        o.customer_name,
        COALESCE(dc.customer_key, -1) AS customer_key,
        o.transaction_date,
        o.posting_date,
        o.delivery_date,
        o.status,
        o.net_total,
        o.grand_total,
        SUM(oi.qty) AS qty_ordered,
        COUNT(DISTINCT oi.item_id) AS line_count,
        CURRENT_DATE::DATE - o.delivery_date::DATE AS days_overdue,
        o.company,
        o.territory,
        COALESCE(dd_delivery.date_id, -1) AS delivery_date_id
    FROM staging.stg_sales_order o
    INNER JOIN staging.stg_sales_order_item oi ON o.order_id = oi.order_id
    LEFT JOIN mart.dim_customer dc ON o.customer = dc.customer_id
    LEFT JOIN mart.dim_date dd_delivery ON o.delivery_date::DATE = dd_delivery.full_date
    GROUP BY o.order_id, o.customer, o.customer_name, dc.customer_key, o.transaction_date,
             o.posting_date, o.delivery_date, o.status, o.net_total, o.grand_total,
             o.company, o.territory, dd_delivery.date_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY os.order_id) AS fact_key,
    os.order_id,
    os.customer_key,
    os.customer,
    os.customer_name,
    os.transaction_date::DATE AS order_date,
    os.posting_date::DATE AS order_posted_date,
    os.delivery_date::DATE AS expected_delivery_date,
    os.delivery_date_id,
    os.status AS order_status,
    CASE WHEN os.status = 'Closed' THEN 'Closed'
         WHEN COALESCE(os.delivery_date::DATE, CURRENT_DATE) < CURRENT_DATE THEN 'Overdue'
         WHEN COALESCE(os.delivery_date::DATE, CURRENT_DATE) = CURRENT_DATE THEN 'Due Today'
         WHEN COALESCE(os.delivery_date::DATE, CURRENT_DATE) BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days' THEN 'Due This Week'
         ELSE 'Pending' END AS fulfillment_status,
    CASE WHEN os.days_overdue > 0 THEN TRUE ELSE FALSE END AS is_overdue,
    CASE WHEN os.days_overdue > 0 THEN os.days_overdue ELSE 0 END AS days_past_due,
    CASE WHEN os.delivery_date::DATE > CURRENT_DATE THEN (os.delivery_date::DATE - CURRENT_DATE)::INT ELSE 0 END AS days_until_due,
    os.qty_ordered,
    os.line_count,
    os.net_total,
    os.grand_total,
    os.company,
    os.territory,
    NOW() AS dw_load_date
FROM order_summary os
WHERE os.status != 'Draft'  -- Exclude draft orders
ORDER BY os.days_overdue DESC, os.delivery_date;

ALTER TABLE mart.fact_sales_order_readiness ADD PRIMARY KEY (fact_key);
CREATE INDEX idx_so_readiness_customer_key ON mart.fact_sales_order_readiness(customer_key);
CREATE INDEX idx_so_readiness_status ON mart.fact_sales_order_readiness(fulfillment_status);
CREATE INDEX idx_so_readiness_is_overdue ON mart.fact_sales_order_readiness(is_overdue);
CREATE INDEX idx_so_readiness_order_id ON mart.fact_sales_order_readiness(order_id);
CREATE INDEX idx_so_readiness_delivery_date ON mart.fact_sales_order_readiness(expected_delivery_date);
CREATE INDEX idx_so_readiness_order_date ON mart.fact_sales_order_readiness(order_date);
