-- Operational Readiness: Item Master Completeness Check
-- Grain: 1 row per item
-- Purpose: Identifies items with incomplete master data that blocks downstream processes
-- Source: stg_item (all items) + stg_sales_order_item (for sales activity check)

DROP TABLE IF EXISTS mart.fact_item_master_readiness CASCADE;
CREATE TABLE mart.fact_item_master_readiness AS
WITH item_sales_activity AS (
    -- Check if item has been sold (appears in sales orders)
    SELECT DISTINCT item_code, TRUE AS has_sales_activity
    FROM staging.stg_sales_order_item
)
SELECT
    di.item_key,
    i.item_code,
    i.item_name,
    i.item_group,
    i.brand,
    CASE WHEN i.item_group IS NOT NULL AND i.item_group != '' THEN TRUE ELSE FALSE END AS has_item_group,
    CASE WHEN i.brand IS NOT NULL AND i.brand != '' THEN TRUE ELSE FALSE END AS has_brand,
    CASE WHEN i.weight_per_unit IS NOT NULL AND i.weight_per_unit > 0 THEN TRUE ELSE FALSE END AS has_weight,
    CASE WHEN i.stock_uom IS NOT NULL AND i.stock_uom != '' THEN TRUE ELSE FALSE END AS has_stock_uom,
    CASE WHEN i.purchase_uom IS NOT NULL AND i.purchase_uom != '' THEN TRUE ELSE FALSE END AS has_purchase_uom,
    i.is_sales,
    i.is_stock,
    i.is_purchase,
    CASE WHEN i.is_sales = TRUE THEN TRUE ELSE FALSE END AS is_sales_item,
    CASE WHEN i.is_stock = TRUE THEN TRUE ELSE FALSE END AS is_stock_item,
    CASE WHEN i.is_purchase = TRUE THEN TRUE ELSE FALSE END AS is_purchase_item,
    CASE WHEN isa.item_code IS NOT NULL THEN TRUE ELSE FALSE END AS has_recent_sales_activity,
    -- Readiness score: count of completed attributes divided by expected count
    -- For sales items: item_group, brand, stock_uom, is_stock, is_sales
    -- For stock items: stock_uom, weight
    -- For purchase items: purchase_uom
    CASE WHEN i.is_sales = TRUE THEN
        ROUND(
            (
                CASE WHEN i.item_group IS NOT NULL AND i.item_group != '' THEN 1 ELSE 0 END +
                CASE WHEN i.brand IS NOT NULL AND i.brand != '' THEN 1 ELSE 0 END +
                CASE WHEN i.stock_uom IS NOT NULL AND i.stock_uom != '' THEN 1 ELSE 0 END +
                CASE WHEN i.is_stock = TRUE THEN 1 ELSE 0 END
            )::NUMERIC / 4.0 * 100,
            1
        )
         ELSE 0 END AS sales_readiness_score,
    CASE WHEN i.is_stock = TRUE THEN
        ROUND(
            (
                CASE WHEN i.stock_uom IS NOT NULL AND i.stock_uom != '' THEN 1 ELSE 0 END +
                CASE WHEN i.weight_per_unit IS NOT NULL AND i.weight_per_unit > 0 THEN 1 ELSE 0 END
            )::NUMERIC / 2.0 * 100,
            1
        )
         ELSE 0 END AS stock_readiness_score,
    CASE WHEN i.is_purchase = TRUE THEN
        ROUND(
            (
                CASE WHEN i.purchase_uom IS NOT NULL AND i.purchase_uom != '' THEN 1 ELSE 0 END
            )::NUMERIC / 1.0 * 100,
            1
        )
         ELSE 0 END AS purchase_readiness_score,
    -- Overall readiness determination
    CASE WHEN (i.is_sales = TRUE AND i.item_group IS NULL) OR
              (i.is_stock = TRUE AND i.stock_uom IS NULL) OR
              (i.is_purchase = TRUE AND i.purchase_uom IS NULL) THEN 'INCOMPLETE'
         WHEN i.is_sales = TRUE AND i.brand IS NULL THEN 'INCOMPLETE'
         ELSE 'COMPLETE' END AS readiness_status,
    i.is_purchase,
    i.valuation_method,
    i.creation,
    i.modified,
    NOW() AS dw_load_date
FROM staging.stg_item i
LEFT JOIN mart.dim_item di ON i.item_code = di.item_code
LEFT JOIN item_sales_activity isa ON i.item_code = isa.item_code
ORDER BY readiness_status DESC, i.item_code;

ALTER TABLE mart.fact_item_master_readiness ADD PRIMARY KEY (item_key);
CREATE INDEX idx_item_readiness_status ON mart.fact_item_master_readiness(readiness_status);
CREATE INDEX idx_item_readiness_sales_score ON mart.fact_item_master_readiness(sales_readiness_score);
CREATE INDEX idx_item_readiness_stock_score ON mart.fact_item_master_readiness(stock_readiness_score);
CREATE INDEX idx_item_readiness_is_sales ON mart.fact_item_master_readiness(is_sales);
CREATE INDEX idx_item_readiness_is_stock ON mart.fact_item_master_readiness(is_stock);
CREATE INDEX idx_item_readiness_has_activity ON mart.fact_item_master_readiness(has_recent_sales_activity);
CREATE INDEX idx_item_readiness_item_code ON mart.fact_item_master_readiness(item_code);
