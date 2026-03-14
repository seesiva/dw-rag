-- Staging layer: Manufacturing and Procurement (Phase 2)
-- Transforms raw data from manufacturing and procurement modules
-- Idempotent: DROP + CREATE

CREATE SCHEMA IF NOT EXISTS staging;

-- ============================================================================
-- Bill of Materials (BOM) Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_bom CASCADE;
CREATE TABLE staging.stg_bom AS
SELECT
    name AS bom_id,
    item AS item_code,
    is_active,
    is_default,
    quantity::NUMERIC(18,6) AS bom_quantity,
    company,
    creation,
    modified
FROM raw.erpnext_bom
WHERE docstatus = 1  -- Submitted BOMs only
  AND (is_active = 'Yes' OR is_active = 1 OR is_active = TRUE);

CREATE INDEX idx_stg_bom_item_code ON staging.stg_bom(item_code);
CREATE INDEX idx_stg_bom_is_default ON staging.stg_bom(is_default);

-- ============================================================================
-- Work Orders Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_work_order CASCADE;
CREATE TABLE staging.stg_work_order AS
SELECT
    name AS work_order_id,
    production_item AS item_code,
    bom_no,
    qty::NUMERIC(18,6),
    produced_qty::NUMERIC(18,6),
    status,
    planned_start_date::DATE,
    planned_end_date::DATE,
    actual_start_date::DATE,
    actual_end_date::DATE,
    company,
    creation,
    modified
FROM raw.erpnext_work_order
WHERE docstatus = 1;  -- Submitted work orders only

CREATE INDEX idx_stg_wo_item_code ON staging.stg_work_order(item_code);
CREATE INDEX idx_stg_wo_status ON staging.stg_work_order(status);
CREATE INDEX idx_stg_wo_id ON staging.stg_work_order(work_order_id);

-- ============================================================================
-- Work Order Items Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_work_order_item CASCADE;
CREATE TABLE staging.stg_work_order_item AS
SELECT
    name AS work_order_item_id,
    parent AS work_order_id,
    item_code,
    item_name,
    required_qty::NUMERIC(18,6),
    consumed_qty::NUMERIC(18,6)
FROM raw.erpnext_work_order_item
WHERE parent IN (SELECT work_order_id FROM staging.stg_work_order);

CREATE INDEX idx_stg_woi_wo_id ON staging.stg_work_order_item(work_order_id);
CREATE INDEX idx_stg_woi_item_code ON staging.stg_work_order_item(item_code);

-- ============================================================================
-- Job Cards Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_job_card CASCADE;
CREATE TABLE staging.stg_job_card AS
SELECT
    name AS job_card_id,
    work_order,
    operation,
    workstation,
    status,
    creation,
    modified
FROM raw.erpnext_job_card
WHERE docstatus IN (0, 1);  -- Open and submitted job cards

CREATE INDEX idx_stg_jc_wo ON staging.stg_job_card(work_order);
CREATE INDEX idx_stg_jc_status ON staging.stg_job_card(status);
CREATE INDEX idx_stg_jc_id ON staging.stg_job_card(job_card_id);

-- ============================================================================
-- Purchase Orders Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_purchase_order CASCADE;
CREATE TABLE staging.stg_purchase_order AS
SELECT
    name AS po_id,
    supplier,
    transaction_date::DATE,
    schedule_date::DATE AS expected_delivery_date,
    base_grand_total::NUMERIC(18,6) AS grand_total,
    status,
    company,
    creation,
    modified
FROM raw.erpnext_purchase_order
WHERE docstatus = 1;  -- Submitted POs only

CREATE INDEX idx_stg_po_supplier ON staging.stg_purchase_order(supplier);
CREATE INDEX idx_stg_po_status ON staging.stg_purchase_order(status);
CREATE INDEX idx_stg_po_id ON staging.stg_purchase_order(po_id);

-- ============================================================================
-- Purchase Order Items Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_purchase_order_item CASCADE;
CREATE TABLE staging.stg_purchase_order_item AS
SELECT
    name AS po_item_id,
    parent AS po_id,
    item_code,
    item_name,
    qty::NUMERIC(18,6),
    received_qty::NUMERIC(18,6),
    billed_qty::NUMERIC(18,6),
    rate::NUMERIC(18,6),
    base_rate::NUMERIC(18,6),
    base_amount::NUMERIC(18,6) AS amount,
    warehouse,
    schedule_date::DATE AS expected_delivery_date
FROM raw.erpnext_purchase_order_item
WHERE parent IN (SELECT po_id FROM staging.stg_purchase_order);

CREATE INDEX idx_stg_poi_po_id ON staging.stg_purchase_order_item(po_id);
CREATE INDEX idx_stg_poi_item_code ON staging.stg_purchase_order_item(item_code);
CREATE INDEX idx_stg_poi_warehouse ON staging.stg_purchase_order_item(warehouse);

-- ============================================================================
-- Material Requests Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_material_request CASCADE;
CREATE TABLE staging.stg_material_request AS
SELECT
    name AS material_request_id,
    material_request_type,
    transaction_date::DATE,
    schedule_date::DATE AS expected_date,
    status,
    company,
    creation,
    modified
FROM raw.erpnext_material_request
WHERE docstatus = 1;  -- Submitted MRs only

CREATE INDEX idx_stg_mr_type ON staging.stg_material_request(material_request_type);
CREATE INDEX idx_stg_mr_status ON staging.stg_material_request(status);
CREATE INDEX idx_stg_mr_id ON staging.stg_material_request(material_request_id);

-- ============================================================================
-- Material Request Items Staging
-- ============================================================================

DROP TABLE IF EXISTS staging.stg_material_request_item CASCADE;
CREATE TABLE staging.stg_material_request_item AS
SELECT
    name AS mr_item_id,
    parent AS material_request_id,
    item_code,
    item_name,
    qty::NUMERIC(18,6),
    ordered_qty::NUMERIC(18,6),
    warehouse
FROM raw.erpnext_material_request_item
WHERE parent IN (SELECT material_request_id FROM staging.stg_material_request);

CREATE INDEX idx_stg_mri_mr_id ON staging.stg_material_request_item(material_request_id);
CREATE INDEX idx_stg_mri_item_code ON staging.stg_material_request_item(item_code);
CREATE INDEX idx_stg_mri_warehouse ON staging.stg_material_request_item(warehouse);
