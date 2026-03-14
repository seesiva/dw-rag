-- Dimension: Customer
-- 1 row per unique customer from staging

DROP TABLE IF EXISTS mart.dim_customer CASCADE;
CREATE TABLE mart.dim_customer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
    customer_id,
    customer_name,
    customer_type,
    customer_group,
    territory,
    email_id,
    mobile_no,
    credit_limit,
    market_segment,
    industry,
    NOW() AS dw_load_date
FROM staging.stg_customer
ORDER BY customer_id;

ALTER TABLE mart.dim_customer ADD PRIMARY KEY (customer_key);
CREATE UNIQUE INDEX idx_dim_customer_id ON mart.dim_customer(customer_id);
CREATE INDEX idx_dim_customer_group ON mart.dim_customer(customer_group);
CREATE INDEX idx_dim_customer_territory ON mart.dim_customer(territory);
