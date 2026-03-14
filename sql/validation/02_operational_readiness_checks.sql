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

    RETURN QUERY
    SELECT
        'fact_work_order_readiness row count (Phase 2)'::TEXT,
        'mart.fact_work_order_readiness'::TEXT,
        0::INT,
        (SELECT COUNT(*) FROM mart.fact_work_order_readiness)::INT,
        'PASS'::TEXT;

    RETURN QUERY
    SELECT
        'fact_purchase_readiness row count (Phase 2)'::TEXT,
        'mart.fact_purchase_readiness'::TEXT,
        0::INT,
        (SELECT COUNT(*) FROM mart.fact_purchase_readiness)::INT,
        'PASS'::TEXT;
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

-- ============================================================================
-- Phase 2: Work Order Readiness Validation
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_work_order_readiness_quality()
RETURNS TABLE (check_name TEXT, issue_count INT, status TEXT) AS $$
BEGIN
    -- Check for null work_order_id
    RETURN QUERY
    SELECT
        'work_order_readiness: null work_order_id check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_work_order_readiness WHERE work_order_id IS NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_work_order_readiness WHERE work_order_id IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END;

    -- Check for orphan item_keys
    RETURN QUERY
    SELECT
        'work_order_readiness: orphan item_key check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_work_order_readiness WHERE item_key = -1 AND item_code IS NOT NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_work_order_readiness WHERE item_key = -1 AND item_code IS NOT NULL) = 0
             THEN 'PASS' ELSE 'WARNING' END;

    -- Check is_overdue consistency
    RETURN QUERY
    SELECT
        'work_order_readiness: is_overdue consistency'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_work_order_readiness
         WHERE (is_overdue = TRUE AND days_overdue <= 0) OR (is_overdue = FALSE AND days_overdue > 0))::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_work_order_readiness
                   WHERE (is_overdue = TRUE AND days_overdue <= 0) OR (is_overdue = FALSE AND days_overdue > 0)) = 0
             THEN 'PASS' ELSE 'FAIL' END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Phase 2: Purchase Readiness Validation
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_purchase_readiness_quality()
RETURNS TABLE (check_name TEXT, issue_count INT, status TEXT) AS $$
BEGIN
    -- Check for null po_id
    RETURN QUERY
    SELECT
        'purchase_readiness: null po_id check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_purchase_readiness WHERE po_id IS NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_purchase_readiness WHERE po_id IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END;

    -- Check for orphan item_keys
    RETURN QUERY
    SELECT
        'purchase_readiness: orphan item_key check'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_purchase_readiness WHERE item_key = -1 AND item_code IS NOT NULL)::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_purchase_readiness WHERE item_key = -1 AND item_code IS NOT NULL) = 0
             THEN 'PASS' ELSE 'WARNING' END;

    -- Check fulfillment status values
    RETURN QUERY
    SELECT
        'purchase_readiness: valid fulfillment status'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_purchase_readiness
         WHERE fulfillment_status NOT IN ('RECEIVED', 'PARTIALLY_RECEIVED', 'PENDING_RECEIPT', 'OVERDUE', 'UNKNOWN'))::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_purchase_readiness
                   WHERE fulfillment_status NOT IN ('RECEIVED', 'PARTIALLY_RECEIVED', 'PENDING_RECEIPT', 'OVERDUE', 'UNKNOWN')) = 0
             THEN 'PASS' ELSE 'FAIL' END;

    -- Check is_overdue consistency
    RETURN QUERY
    SELECT
        'purchase_readiness: is_overdue consistency'::TEXT,
        (SELECT COUNT(*) FROM mart.fact_purchase_readiness
         WHERE (is_overdue = TRUE AND days_pending <= 0) OR (is_overdue = FALSE AND days_pending > 0))::INT,
        CASE WHEN (SELECT COUNT(*) FROM mart.fact_purchase_readiness
                   WHERE (is_overdue = TRUE AND days_pending <= 0) OR (is_overdue = FALSE AND days_pending > 0)) = 0
             THEN 'PASS' ELSE 'FAIL' END;
END;
$$ LANGUAGE plpgsql;

-- Row count checks (Phase 1 + Phase 2)
SELECT * FROM validation.check_operational_readiness_row_counts();

-- Data quality checks (Phase 1)
SELECT * FROM validation.check_material_shortage_quality();
SELECT * FROM validation.check_sales_order_readiness_quality();
SELECT * FROM validation.check_item_master_readiness_quality();

-- Data quality checks (Phase 2)
SELECT * FROM validation.check_work_order_readiness_quality();
SELECT * FROM validation.check_purchase_readiness_quality();

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

-- ============================================================================
-- Phase 2 OPERATIONAL SUMMARY QUERIES
-- ============================================================================

-- Items without active BOM (finished goods requiring BOM)
SELECT
    'Items Without Active BOM' AS report,
    COUNT(*) AS items_without_bom,
    COUNT(CASE WHEN is_stock_item = TRUE THEN 1 END) AS stock_items_without_bom,
    COUNT(CASE WHEN has_recent_sales_activity = TRUE THEN 1 END) AS with_recent_sales
FROM mart.fact_item_master_readiness
WHERE has_active_bom = FALSE AND (is_stock_item = TRUE OR has_recent_sales_activity = TRUE);

-- Work orders missing job cards
SELECT
    'Work Orders Missing Job Cards' AS report,
    COUNT(*) AS wo_missing_jc,
    COUNT(CASE WHEN is_overdue = TRUE THEN 1 END) AS wo_missing_jc_overdue,
    COUNT(CASE WHEN production_status IN ('Not Started', 'In Progress') THEN 1 END) AS wo_in_progress_no_jc
FROM mart.fact_work_order_readiness
WHERE has_job_cards = FALSE;

-- Overdue purchase orders
SELECT
    'Overdue Purchase Orders' AS report,
    COUNT(*) AS po_lines_overdue,
    COUNT(DISTINCT po_id) AS distinct_pos_overdue,
    SUM(pending_qty) AS total_pending_qty,
    ROUND(AVG(days_pending), 1) AS avg_days_pending,
    MAX(days_pending) AS max_days_pending
FROM mart.fact_purchase_readiness
WHERE is_overdue = TRUE;

-- Purchase order fulfillment by receipt status
SELECT
    'PO Fulfillment Status' AS report,
    COUNT(CASE WHEN receipt_status = 'Fully Received' THEN 1 END) AS fully_received,
    COUNT(CASE WHEN receipt_status = 'Partially Received' THEN 1 END) AS partially_received,
    COUNT(CASE WHEN receipt_status = 'Not Received' THEN 1 END) AS not_received,
    ROUND(100.0 * SUM(CASE WHEN receipt_status = 'Fully Received' THEN 1 END) / COUNT(*), 1) AS pct_fulfilled
FROM mart.fact_purchase_readiness
WHERE fulfillment_status IN ('RECEIVED', 'PARTIALLY_RECEIVED', 'PENDING_RECEIPT');
