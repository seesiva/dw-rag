-- Fact: Stock Ledger Movements
-- Grain: 1 row per stock ledger entry (inventory transaction)
-- Joins: stg_stock_ledger + dimensions

DROP TABLE IF EXISTS mart.fact_stock_movement CASCADE;
CREATE TABLE mart.fact_stock_movement AS
SELECT
    ROW_NUMBER() OVER (ORDER BY sl.entry_id) AS fact_key,
    sl.entry_id,
    di.item_key,
    dw.warehouse_key,
    dd.date_id,
    -- Actual transaction date (crucial for filtering and trend analysis)
    sl.posting_date::DATE AS transaction_date,
    sl.voucher_type,
    sl.voucher_no,
    sl.company,
    sl.project,
    sl.batch_no,
    sl.fiscal_year,
    sl.actual_qty,
    sl.qty_after_transaction,
    sl.incoming_rate,
    sl.outgoing_rate,
    sl.valuation_rate,
    sl.stock_value,
    sl.stock_value_difference,
    CASE
        WHEN sl.actual_qty > 0 THEN 'IN'
        WHEN sl.actual_qty < 0 THEN 'OUT'
        ELSE 'ZERO'
    END AS movement_type,
    NOW() AS dw_load_date
FROM staging.stg_stock_ledger sl
LEFT JOIN mart.dim_item di ON sl.item_code = di.item_code
LEFT JOIN mart.dim_warehouse dw ON sl.warehouse = dw.warehouse_id
LEFT JOIN mart.dim_date dd ON sl.posting_date::DATE = dd.full_date;

ALTER TABLE mart.fact_stock_movement ADD PRIMARY KEY (fact_key);
CREATE INDEX idx_fact_stock_movement_item ON mart.fact_stock_movement(item_key);
CREATE INDEX idx_fact_stock_movement_warehouse ON mart.fact_stock_movement(warehouse_key);
CREATE INDEX idx_fact_stock_movement_date ON mart.fact_stock_movement(date_id);
CREATE INDEX idx_fact_stock_movement_voucher ON mart.fact_stock_movement(voucher_type, voucher_no);
CREATE INDEX idx_fact_stock_movement_type ON mart.fact_stock_movement(movement_type);
