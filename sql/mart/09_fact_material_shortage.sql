-- Operational Readiness: Material Shortage Analysis
-- Grain: 1 row per item + warehouse (current stock snapshot)
-- Purpose: Identifies items at zero or negative stock that block production and delivery
-- Source: stg_stock_ledger (latest qty per item+warehouse) + stg_item

DROP TABLE IF EXISTS mart.fact_material_shortage CASCADE;
CREATE TABLE mart.fact_material_shortage AS
WITH latest_stock AS (
    -- Get the most recent stock qty for each item+warehouse combination
    SELECT
        item_code,
        warehouse,
        qty_after_transaction,
        posting_date,
        ROW_NUMBER() OVER (PARTITION BY item_code, warehouse ORDER BY posting_date DESC, entry_id DESC) AS rn
    FROM staging.stg_stock_ledger
    WHERE warehouse IS NOT NULL AND item_code IS NOT NULL
)
SELECT
    COALESCE(di.item_key, -1) AS item_key,
    COALESCE(dw.warehouse_key, -1) AS warehouse_key,
    ls.item_code,
    i.item_name,
    i.item_group,
    ls.warehouse,
    ls.qty_after_transaction AS current_qty,
    CASE WHEN COALESCE(ls.qty_after_transaction, 0) <= 0 THEN TRUE ELSE FALSE END AS is_shortfall,
    CASE WHEN COALESCE(ls.qty_after_transaction, 0) < 0 THEN 'Negative'
         WHEN COALESCE(ls.qty_after_transaction, 0) = 0 THEN 'Zero Stock'
         ELSE 'Available' END AS stock_status,
    ls.posting_date AS last_stock_movement_date,
    i.is_stock,
    i.is_sales,
    i.is_purchase,
    i.brand,
    NOW() AS dw_load_date
FROM latest_stock ls
INNER JOIN staging.stg_item i ON ls.item_code = i.item_code
LEFT JOIN mart.dim_item di ON i.item_code = di.item_code
LEFT JOIN mart.dim_warehouse dw ON ls.warehouse = dw.warehouse_id
WHERE ls.rn = 1
  AND i.is_stock = TRUE  -- Only track items that are tracked in inventory
ORDER BY ls.qty_after_transaction ASC, ls.item_code, ls.warehouse;

ALTER TABLE mart.fact_material_shortage ADD PRIMARY KEY (item_key, warehouse_key);
CREATE INDEX idx_shortage_is_shortfall ON mart.fact_material_shortage(is_shortfall);
CREATE INDEX idx_shortage_stock_status ON mart.fact_material_shortage(stock_status);
CREATE INDEX idx_shortage_item_key ON mart.fact_material_shortage(item_key);
CREATE INDEX idx_shortage_warehouse_key ON mart.fact_material_shortage(warehouse_key);
CREATE INDEX idx_shortage_item_code ON mart.fact_material_shortage(item_code);
