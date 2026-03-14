-- Dimension: Warehouse
-- 1 row per unique warehouse (leaf nodes)

DROP TABLE IF EXISTS mart.dim_warehouse CASCADE;
CREATE TABLE mart.dim_warehouse AS
SELECT
    ROW_NUMBER() OVER (ORDER BY warehouse_id) AS warehouse_key,
    warehouse_id,
    warehouse_name,
    parent_warehouse,
    company,
    city,
    state,
    NOW() AS dw_load_date
FROM staging.stg_warehouse
ORDER BY warehouse_id;

ALTER TABLE mart.dim_warehouse ADD PRIMARY KEY (warehouse_key);
CREATE UNIQUE INDEX idx_dim_warehouse_id ON mart.dim_warehouse(warehouse_id);
CREATE INDEX idx_dim_warehouse_name ON mart.dim_warehouse(warehouse_name);
CREATE INDEX idx_dim_warehouse_company ON mart.dim_warehouse(company);
