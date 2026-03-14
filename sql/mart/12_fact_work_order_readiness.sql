-- Operational Readiness: Work Order Status and Job Card Readiness
-- Grain: 1 row per work order
-- Purpose: Identifies work orders that haven't had job cards created or are overdue
-- Source: stg_work_order + stg_job_card + stg_work_order_item + dimensions

DROP TABLE IF EXISTS mart.fact_work_order_readiness CASCADE;
CREATE TABLE mart.fact_work_order_readiness AS
WITH work_order_summary AS (
    -- Aggregate work order details
    SELECT
        wo.work_order_id,
        wo.item_code,
        i.item_name,
        COALESCE(di.item_key, -1) AS item_key,
        wo.bom_no,
        wo.status,
        wo.planned_qty,
        wo.produced_qty,
        wo.planned_start_date,
        wo.planned_end_date,
        wo.actual_start_date,
        wo.company,
        -- Count of associated job cards
        COALESCE(jc_count.job_card_count, 0) AS job_card_count,
        -- Count of work order items
        COALESCE(woi_count.material_item_count, 0) AS material_item_count,
        -- Check if job cards exist
        CASE WHEN jc_count.job_card_count > 0 THEN TRUE ELSE FALSE END AS has_job_cards
    FROM staging.stg_work_order wo
    LEFT JOIN staging.stg_item i ON wo.item_code = i.item_code
    LEFT JOIN mart.dim_item di ON wo.item_code = di.item_code
    LEFT JOIN (
        SELECT work_order, COUNT(DISTINCT job_card_id) AS job_card_count
        FROM staging.stg_job_card
        GROUP BY work_order
    ) jc_count ON wo.work_order_id = jc_count.work_order
    LEFT JOIN (
        SELECT work_order_id, COUNT(DISTINCT item_id) AS material_item_count
        FROM staging.stg_work_order_item
        GROUP BY work_order_id
    ) woi_count ON wo.work_order_id = woi_count.work_order_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY wos.work_order_id) AS fact_key,
    wos.work_order_id,
    wos.item_key,
    wos.item_code,
    wos.item_name,
    wos.bom_no,
    wos.status,
    wos.planned_qty,
    wos.produced_qty,
    wos.planned_start_date,
    wos.planned_end_date,
    wos.actual_start_date,
    ROUND(100.0 * wos.produced_qty / NULLIF(wos.planned_qty, 0), 1) AS completion_pct,
    -- Delivery status
    CASE WHEN wos.status = 'Completed' THEN 'Completed'
         WHEN wos.actual_start_date IS NULL THEN 'Not Started'
         WHEN wos.actual_start_date IS NOT NULL AND wos.status IN ('In Process', 'Submitted') THEN 'In Progress'
         ELSE 'Other' END AS production_status,
    -- Overdue check
    CASE WHEN COALESCE(wos.planned_end_date, CURRENT_DATE) < CURRENT_DATE AND wos.status != 'Completed'
         THEN TRUE ELSE FALSE END AS is_overdue,
    CASE WHEN COALESCE(wos.planned_end_date, CURRENT_DATE) < CURRENT_DATE AND wos.status != 'Completed'
         THEN (CURRENT_DATE - wos.planned_end_date::DATE)::INT
         ELSE 0 END AS days_overdue,
    -- Job card readiness
    wos.has_job_cards,
    wos.job_card_count,
    wos.material_item_count,
    -- Business rules for readiness
    CASE WHEN wos.status IN ('Not Started', 'In Process') AND wos.has_job_cards = FALSE THEN 'MISSING_JOB_CARDS'
         WHEN COALESCE(wos.planned_end_date, CURRENT_DATE) < CURRENT_DATE AND wos.status != 'Completed' THEN 'OVERDUE'
         WHEN wos.status = 'Completed' THEN 'COMPLETED'
         WHEN wos.status = 'Stopped' THEN 'STOPPED'
         ELSE 'IN_PROGRESS' END AS readiness_flag,
    wos.company,
    NOW() AS dw_load_date
FROM work_order_summary wos
ORDER BY wos.status, COALESCE(wos.planned_end_date, CURRENT_DATE) DESC;

ALTER TABLE mart.fact_work_order_readiness ADD PRIMARY KEY (fact_key);
CREATE INDEX idx_wo_readiness_item_key ON mart.fact_work_order_readiness(item_key);
CREATE INDEX idx_wo_readiness_status ON mart.fact_work_order_readiness(readiness_flag);
CREATE INDEX idx_wo_readiness_has_jc ON mart.fact_work_order_readiness(has_job_cards);
CREATE INDEX idx_wo_readiness_is_overdue ON mart.fact_work_order_readiness(is_overdue);
CREATE INDEX idx_wo_readiness_wo_id ON mart.fact_work_order_readiness(work_order_id);
CREATE INDEX idx_wo_readiness_prod_status ON mart.fact_work_order_readiness(production_status);
