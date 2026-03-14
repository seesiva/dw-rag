-- Operational Readiness: Purchase Order Fulfillment Tracking
-- Grain: 1 row per purchase order line item
-- Purpose: Identifies open PO lines where goods not yet fully received or are overdue
-- Source: stg_purchase_order + stg_purchase_order_item + dimensions

DROP TABLE IF EXISTS mart.fact_purchase_readiness CASCADE;
CREATE TABLE mart.fact_purchase_readiness AS
SELECT
    ROW_NUMBER() OVER (ORDER BY poi.po_id, poi.po_item_id) AS fact_key,
    poi.po_id,
    COALESCE(di.item_key, -1) AS item_key,
    COALESCE(dw.warehouse_key, -1) AS warehouse_key,
    po.supplier,
    poi.item_code,
    poi.item_name,
    poi.qty AS ordered_qty,
    COALESCE(poi.received_qty, 0) AS received_qty,
    (COALESCE(poi.qty, 0) - COALESCE(poi.received_qty, 0)) AS pending_qty,
    poi.rate,
    poi.base_rate,
    poi.amount,
    po.transaction_date AS po_date,
    poi.expected_delivery_date,
    po.expected_delivery_date AS po_expected_delivery_date,
    po.status AS po_status,
    -- Receipt status determination
    CASE WHEN COALESCE(poi.received_qty, 0) = 0 THEN 'Not Received'
         WHEN COALESCE(poi.received_qty, 0) < poi.qty THEN 'Partially Received'
         WHEN COALESCE(poi.received_qty, 0) >= poi.qty THEN 'Fully Received'
         ELSE 'Unknown' END AS receipt_status,
    -- Overdue check
    CASE WHEN COALESCE(poi.expected_delivery_date, po.expected_delivery_date, CURRENT_DATE) < CURRENT_DATE
              AND COALESCE(poi.received_qty, 0) < poi.qty
         THEN TRUE ELSE FALSE END AS is_overdue,
    CASE WHEN COALESCE(poi.expected_delivery_date, po.expected_delivery_date, CURRENT_DATE) < CURRENT_DATE
              AND COALESCE(poi.received_qty, 0) < poi.qty
         THEN EXTRACT(DAY FROM CURRENT_DATE - COALESCE(poi.expected_delivery_date, po.expected_delivery_date)::DATE)
         ELSE 0 END AS days_pending,
    CASE WHEN COALESCE(poi.expected_delivery_date, po.expected_delivery_date, CURRENT_DATE) >= CURRENT_DATE
              AND COALESCE(poi.received_qty, 0) < poi.qty
         THEN EXTRACT(DAY FROM COALESCE(poi.expected_delivery_date, po.expected_delivery_date)::DATE - CURRENT_DATE)
         ELSE 0 END AS days_until_due,
    -- Readiness flags
    CASE WHEN COALESCE(poi.received_qty, 0) >= poi.qty THEN 'RECEIVED'
         WHEN COALESCE(poi.expected_delivery_date, po.expected_delivery_date, CURRENT_DATE) < CURRENT_DATE
              AND COALESCE(poi.received_qty, 0) < poi.qty THEN 'OVERDUE'
         WHEN COALESCE(poi.received_qty, 0) > 0 AND COALESCE(poi.received_qty, 0) < poi.qty THEN 'PARTIALLY_RECEIVED'
         WHEN COALESCE(poi.received_qty, 0) = 0 THEN 'PENDING_RECEIPT'
         ELSE 'UNKNOWN' END AS fulfillment_status,
    po.company,
    poi.warehouse,
    NOW() AS dw_load_date
FROM staging.stg_purchase_order_item poi
INNER JOIN staging.stg_purchase_order po ON poi.po_id = po.po_id
LEFT JOIN mart.dim_item di ON poi.item_code = di.item_code
LEFT JOIN mart.dim_warehouse dw ON poi.warehouse = dw.warehouse_id
WHERE po.status NOT IN ('Cancelled', 'Closed')  -- Exclude completed/cancelled orders
ORDER BY COALESCE(poi.expected_delivery_date, po.expected_delivery_date) ASC,
         COALESCE(poi.received_qty, 0) / NULLIF(poi.qty, 0) ASC;

ALTER TABLE mart.fact_purchase_readiness ADD PRIMARY KEY (fact_key);
CREATE INDEX idx_po_readiness_item_key ON mart.fact_purchase_readiness(item_key);
CREATE INDEX idx_po_readiness_warehouse_key ON mart.fact_purchase_readiness(warehouse_key);
CREATE INDEX idx_po_readiness_status ON mart.fact_purchase_readiness(fulfillment_status);
CREATE INDEX idx_po_readiness_is_overdue ON mart.fact_purchase_readiness(is_overdue);
CREATE INDEX idx_po_readiness_po_id ON mart.fact_purchase_readiness(po_id);
CREATE INDEX idx_po_readiness_supplier ON mart.fact_purchase_readiness(supplier);
CREATE INDEX idx_po_readiness_expected_date ON mart.fact_purchase_readiness(po_expected_delivery_date);
CREATE INDEX idx_po_readiness_receipt_status ON mart.fact_purchase_readiness(receipt_status);
