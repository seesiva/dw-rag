-- Data Quality Validation Queries
-- Run after ETL to verify counts and integrity

-- Row count validation: raw → staging → mart
SELECT 'Raw Layer' AS layer, 'Sales Invoices' AS entity, COUNT(*) AS row_count
FROM raw.erpnext_sales_invoice
UNION ALL
SELECT 'Raw Layer', 'Sales Orders', COUNT(*)
FROM raw.erpnext_sales_order
UNION ALL
SELECT 'Raw Layer', 'Customers', COUNT(*)
FROM raw.erpnext_customer
UNION ALL
SELECT 'Raw Layer', 'Items', COUNT(*)
FROM raw.erpnext_item
UNION ALL
SELECT 'Raw Layer', 'Warehouses', COUNT(*)
FROM raw.erpnext_warehouse
UNION ALL
SELECT 'Raw Layer', 'Stock Ledger', COUNT(*)
FROM raw.erpnext_stock_ledger_entry
UNION ALL
SELECT 'Staging', 'Sales Invoices', COUNT(*)
FROM staging.stg_sales_invoice
UNION ALL
SELECT 'Staging', 'Sales Orders', COUNT(*)
FROM staging.stg_sales_order
UNION ALL
SELECT 'Staging', 'Customers', COUNT(*)
FROM staging.stg_customer
UNION ALL
SELECT 'Staging', 'Items', COUNT(*)
FROM staging.stg_item
UNION ALL
SELECT 'Staging', 'Warehouses', COUNT(*)
FROM staging.stg_warehouse
UNION ALL
SELECT 'Staging', 'Stock Ledger', COUNT(*)
FROM staging.stg_stock_ledger
UNION ALL
SELECT 'Mart', 'Customers', COUNT(*)
FROM mart.dim_customer
UNION ALL
SELECT 'Mart', 'Items', COUNT(*)
FROM mart.dim_item
UNION ALL
SELECT 'Mart', 'Warehouses', COUNT(*)
FROM mart.dim_warehouse
UNION ALL
SELECT 'Mart', 'Sales Order Lines', COUNT(*)
FROM mart.fact_sales_order_line
UNION ALL
SELECT 'Mart', 'Sales Invoice Lines', COUNT(*)
FROM mart.fact_sales_invoice_line
UNION ALL
SELECT 'Mart', 'Stock Movements', COUNT(*)
FROM mart.fact_stock_movement
ORDER BY layer, entity;

-- Validate submitted records only (docstatus=1) in staging
SELECT
    'Sales Invoices - Submitted Check' AS check_name,
    COUNT(*) AS count,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM staging.stg_sales_invoice
WHERE TRUE
UNION ALL
SELECT
    'Sales Orders - Submitted Check',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM staging.stg_sales_order;

-- Validate foreign key integrity (no orphan keys)
SELECT
    'Fact_Sales_Invoice - Customer FK Integrity' AS check_name,
    COUNT(DISTINCT customer_key) AS fk_count,
    (SELECT COUNT(*) FROM mart.dim_customer) AS dim_count,
    CASE
        WHEN COUNT(DISTINCT customer_key) <= (SELECT COUNT(*) FROM mart.dim_customer)
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM mart.fact_sales_invoice_line
WHERE customer_key IS NOT NULL
UNION ALL
SELECT
    'Fact_Sales_Invoice - Item FK Integrity',
    COUNT(DISTINCT item_key),
    (SELECT COUNT(*) FROM mart.dim_item),
    CASE
        WHEN COUNT(DISTINCT item_key) <= (SELECT COUNT(*) FROM mart.dim_item)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM mart.fact_sales_invoice_line
WHERE item_key IS NOT NULL
UNION ALL
SELECT
    'Fact_Sales_Invoice - Warehouse FK Integrity',
    COUNT(DISTINCT warehouse_key),
    (SELECT COUNT(*) FROM mart.dim_warehouse),
    CASE
        WHEN COUNT(DISTINCT warehouse_key) <= (SELECT COUNT(*) FROM mart.dim_warehouse)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM mart.fact_sales_invoice_line
WHERE warehouse_key IS NOT NULL;

-- Sample fact data for visual inspection
SELECT 'Sample Sales Invoice Facts' AS description;
SELECT
    f.invoice_id,
    c.customer_name,
    i.item_name,
    w.warehouse_name,
    d.full_date,
    f.qty,
    f.net_amount,
    f.is_return
FROM mart.fact_sales_invoice_line f
LEFT JOIN mart.dim_customer c ON f.customer_key = c.customer_key
LEFT JOIN mart.dim_item i ON f.item_key = i.item_key
LEFT JOIN mart.dim_warehouse w ON f.warehouse_key = w.warehouse_key
LEFT JOIN mart.dim_date d ON f.invoice_date_id = d.date_id
LIMIT 10;

SELECT 'Sample Stock Movement Facts' AS description;
SELECT
    sm.entry_id,
    i.item_name,
    w.warehouse_name,
    d.full_date,
    sm.movement_type,
    sm.actual_qty,
    sm.valuation_rate,
    sm.stock_value_difference
FROM mart.fact_stock_movement sm
LEFT JOIN mart.dim_item i ON sm.item_key = i.item_key
LEFT JOIN mart.dim_warehouse w ON sm.warehouse_key = w.warehouse_key
LEFT JOIN mart.dim_date d ON sm.date_id = d.date_id
LIMIT 10;
