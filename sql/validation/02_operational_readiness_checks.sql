-- Validation: Operational Readiness Tables
-- Verify row counts, data quality, and integrity of operational readiness marts

CREATE SCHEMA IF NOT EXISTS validation;

-- ============================================================================
-- 1. ROW COUNT VALIDATION
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_operational_readiness_row_counts()
RETURNS TABLE (check_name TEXT, table_name TEXT, expected_min INT, actual_count INT, status TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'fact_material_shortage row count'::TEXT AS check_name,
        'mart.fact_material_shortage'::TEXT AS table_name,
        1::INT AS expected_min,
        (SELECT COUNT(*) FROM mart.fact_material_shortage)::INT AS actual_count,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_material_shortage) > 0 THEN 'PASS' ELSE 'FAIL' END AS status;

    RETURN QUERY
    SELECT
        'fact_sales_order_readiness row count'::TEXT,
        'mart.fact_sales_order_readiness'::TEXT,
        1::INT,
        (SELECT COUNT(*) FROM mart.fact_sales_order_readiness)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_sales_order_readiness) > 0 THEN 'PASS' ELSE 'FAIL' END;

    RETURN QUERY
    SELECT
        'fact_item_master_readiness row count'::TEXT,
        'mart.fact_item_master_readiness'::TEXT,
        1::INT,
        (SELECT COUNT(*) FROM mart.fact_item_master_readiness)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_item_master_readiness) > 0 THEN 'PASS' ELSE 'FAIL' END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. MATERIAL SHORTAGE VALIDATION
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_material_shortage_quality()
RETURNS TABLE (check_name TEXT, issue_count INT, status TEXT) AS $$
BEGIN
    -- Check for null item_codes
    RETURN QUERY
    SELECT
        'material_shortage: null item_code check'::TEXT AS check_name,
        (SELECT COUNT(*) FROM mart.fact_material_shortage WHERE item_code IS NULL)::INT AS issue_count,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_material_shortage WHERE item_code IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END AS status;

    -- Check for orphan item_keys (items in fact but not in dimension)
    RETURN QUERY
    SELECT
        'material_shortage: orphan item_key check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_material_shortage WHERE item_key = -1 AND item_code IS NOT NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_material_shortage WHERE item_key = -1 AND item_code IS NOT NULL) = 0 THEN 'PASS' ELSE 'WARNING' END;

    -- Check is_shortfall flag consistency
    RETURN QUERY
    SELECT
        'material_shortage: is_shortfall consistency'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_material_shortage
         WHERE (is_shortfall = TRUE AND current_qty > 0) OR (is_shortfall = FALSE AND current_qty <= 0))::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_material_shortage
                   WHERE (is_shortfall = TRUE AND current_qty > 0) OR (is_shortfall = FALSE AND current_qty <= 0)) = 0
             THEN 'PASS' ELSE 'FAIL' END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. SALES ORDER READINESS VALIDATION
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_sales_order_readiness_quality()
RETURNS TABLE (check_name TEXT, issue_count INT, status TEXT) AS $$
BEGIN
    -- Check for null order_id
    RETURN QUERY
    SELECT
        'sales_order_readiness: null order_id check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_sales_order_readiness WHERE order_id IS NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_sales_order_readiness WHERE order_id IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END;

    -- Check for orphan customer_keys
    RETURN QUERY
    SELECT
        'sales_order_readiness: orphan customer_key check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_sales_order_readiness WHERE customer_key = -1 AND customer IS NOT NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_sales_order_readiness WHERE customer_key = -1 AND customer IS NOT NULL) = 0
             THEN 'PASS' ELSE 'WARNING' END;

    -- Check is_overdue consistency
    RETURN QUERY
    SELECT
        'sales_order_readiness: is_overdue consistency'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_sales_order_readiness
         WHERE (is_overdue = TRUE AND days_past_due <= 0) OR (is_overdue = FALSE AND days_past_due > 0))::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_sales_order_readiness
                   WHERE (is_overdue = TRUE AND days_past_due <= 0) OR (is_overdue = FALSE AND days_past_due > 0)) = 0
             THEN 'PASS' ELSE 'FAIL' END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. ITEM MASTER READINESS VALIDATION
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_item_master_readiness_quality()
RETURNS TABLE (check_name TEXT, issue_count INT, status TEXT) AS $$
BEGIN
    -- Check for null item_code
    RETURN QUERY
    SELECT
        'item_master_readiness: null item_code check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_item_master_readiness WHERE item_code IS NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_item_master_readiness WHERE item_code IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END;

    -- Check readiness status values
    RETURN QUERY
    SELECT
        'item_master_readiness: valid status values'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_item_master_readiness
         WHERE readiness_status NOT IN ('COMPLETE', 'INCOMPLETE'))::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_item_master_readiness
                   WHERE readiness_status NOT IN ('COMPLETE', 'INCOMPLETE')) = 0
             THEN 'PASS' ELSE 'FAIL' END;

    -- Check readiness scores are between 0 and 100
    RETURN QUERY
    SELECT
        'item_master_readiness: score ranges'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_item_master_readiness
         WHERE (sales_readiness_score < 0 OR sales_readiness_score > 100) OR
               (stock_readiness_score < 0 OR stock_readiness_score > 100) OR
               (purchase_readiness_score < 0 OR purchase_readiness_score > 100))::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_item_master_readiness
                   WHERE (sales_readiness_score < 0 OR sales_readiness_score > 100) OR
                         (stock_readiness_score < 0 OR stock_readiness_score > 100) OR
                         (purchase_readiness_score < 0 OR purchase_readiness_score > 100)) = 0
             THEN 'PASS' ELSE 'FAIL' END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. RUN ALL VALIDATION CHECKS
-- ============================================================================

-- Row count checks
SELECT * FROM validation.check_operational_readiness_row_counts();

-- Data quality checks
SELECT * FROM validation.check_material_shortage_quality();
SELECT * FROM validation.check_sales_order_readiness_quality();
SELECT * FROM validation.check_item_master_readiness_quality();

-- ============================================================================
-- 6. OPERATIONAL SUMMARY QUERIES
-- ============================================================================

-- Items with critical shortages (negative or zero stock)
SELECT
    'Items in Critical Stock' AS report,
    COUNT(*) AS count,
    COUNT(CASE WHEN stock_status = 'Negative' THEN 1 END) AS negative_stock,
    COUNT(CASE WHEN stock_status = 'Zero Stock' THEN 1 END) AS zero_stock
FROM mart.fact_material_shortage
WHERE is_shortfall = TRUE;

-- Sales orders past due
SELECT
    'Orders Past Due' AS report,
    COUNT(*) AS total_overdue,
    SUM(days_past_due) AS total_days_overdue,
    ROUND(AVG(days_past_due), 1) AS avg_days_overdue,
    MAX(days_past_due) AS max_days_overdue
FROM mart.fact_sales_order_readiness
WHERE is_overdue = TRUE;

-- Item master completeness
SELECT
    'Item Master Completeness' AS report,
    COUNT(CASE WHEN readiness_status = 'COMPLETE' THEN 1 END) AS complete_items,
    COUNT(CASE WHEN readiness_status = 'INCOMPLETE' THEN 1 END) AS incomplete_items,
    ROUND(100.0 * COUNT(CASE WHEN readiness_status = 'COMPLETE' THEN 1 END) / COUNT(*), 1) AS pct_complete
FROM mart.fact_item_master_readiness;
