-- Dimension: Item (Product Master)
-- 1 row per unique item

DROP TABLE IF EXISTS mart.dim_item CASCADE;
CREATE TABLE mart.dim_item AS
SELECT
    ROW_NUMBER() OVER (ORDER BY item_id) AS item_key,
    item_id,
    item_code,
    item_name,
    item_group,
    brand,
    is_stock,
    is_sales,
    is_purchase,
    valuation_method,
    weight_per_unit,
    weight_uom,
    stock_uom,
    purchase_uom,
    variant_of,
    NOW() AS dw_load_date
FROM staging.stg_item
ORDER BY item_id;

ALTER TABLE mart.dim_item ADD PRIMARY KEY (item_key);
CREATE UNIQUE INDEX idx_dim_item_id ON mart.dim_item(item_id);
CREATE INDEX idx_dim_item_code ON mart.dim_item(item_code);
CREATE INDEX idx_dim_item_group ON mart.dim_item(item_group);
CREATE INDEX idx_dim_item_brand ON mart.dim_item(brand);
