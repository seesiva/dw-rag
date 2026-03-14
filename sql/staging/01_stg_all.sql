-- Staging layer: clean and normalize raw data
-- Idempotent: DROP + CREATE

CREATE SCHEMA IF NOT EXISTS staging;

-- Staging: Sales Invoices (submitted only)
DROP TABLE IF EXISTS staging.stg_sales_invoice CASCADE;
CREATE TABLE staging.stg_sales_invoice AS
SELECT
    name AS invoice_id,
    customer,
    customer_name,
    customer_group,
    posting_date,
    due_date,
    po_date,
    po_no,
    base_net_total::NUMERIC(18,6) AS net_total,
    base_grand_total::NUMERIC(18,6) AS grand_total,
    base_total_taxes_and_charges::NUMERIC(18,6) AS total_taxes,
    total_qty::NUMERIC(18,6) AS qty,
    currency,
    CASE WHEN is_return = 1 THEN TRUE ELSE FALSE END AS is_return,
    return_against,
    company,
    territory,
    cost_center,
    project,
    creation,
    modified
FROM raw.erpnext_sales_invoice
WHERE docstatus = 1;

-- Staging: Sales Invoice Items
DROP TABLE IF EXISTS staging.stg_sales_invoice_item CASCADE;
CREATE TABLE staging.stg_sales_invoice_item AS
SELECT
    name AS item_id,
    parent AS invoice_id,
    item_code,
    item_name,
    item_group,
    qty::NUMERIC(18,6),
    rate::NUMERIC(18,6),
    base_rate::NUMERIC(18,6),
    base_net_amount::NUMERIC(18,6) AS net_amount,
    base_amount::NUMERIC(18,6) AS amount,
    warehouse,
    uom,
    discount_percentage::NUMERIC(18,6),
    brand,
    cost_center,
    so_detail,
    delivery_note
FROM raw.erpnext_sales_invoice_item
WHERE parent IN (SELECT invoice_id FROM staging.stg_sales_invoice);

-- Staging: Sales Orders (submitted only, exclude internal customers)
DROP TABLE IF EXISTS staging.stg_sales_order CASCADE;
CREATE TABLE staging.stg_sales_order AS
SELECT
    o.name AS order_id,
    o.customer,
    o.customer_name,
    o.transaction_date,
    o.posting_date,
    o.delivery_date,
    o.base_net_total::NUMERIC(18,6) AS net_total,
    o.base_grand_total::NUMERIC(18,6) AS grand_total,
    o.base_total_taxes_and_charges::NUMERIC(18,6) AS total_taxes,
    o.total_qty::NUMERIC(18,6) AS qty,
    o.currency,
    o.status,
    o.company,
    o.territory,
    o.cost_center,
    o.project,
    o.creation,
    o.modified
FROM raw.erpnext_sales_order o
INNER JOIN raw.erpnext_customer c ON o.customer = c.name
WHERE o.docstatus = 1
  AND c.disabled = 0
  AND (c.is_internal_customer = 0 OR c.is_internal_customer IS NULL);

-- Staging: Sales Order Items
DROP TABLE IF EXISTS staging.stg_sales_order_item CASCADE;
CREATE TABLE staging.stg_sales_order_item AS
SELECT
    name AS item_id,
    parent AS order_id,
    item_code,
    item_name,
    item_group,
    qty::NUMERIC(18,6),
    rate::NUMERIC(18,6),
    base_rate::NUMERIC(18,6),
    base_net_amount::NUMERIC(18,6) AS net_amount,
    base_amount::NUMERIC(18,6) AS amount,
    warehouse,
    uom,
    discount_percentage::NUMERIC(18,6),
    brand,
    cost_center,
    delivery_date
FROM raw.erpnext_sales_order_item
WHERE parent IN (SELECT order_id FROM staging.stg_sales_order);

-- Staging: Customers (active and external only, exclude internal customers)
DROP TABLE IF EXISTS staging.stg_customer CASCADE;
CREATE TABLE staging.stg_customer AS
SELECT
    name AS customer_id,
    customer_name,
    customer_type,
    customer_group,
    territory,
    email_id,
    mobile_no,
    credit_limit::NUMERIC(18,6),
    market_segment,
    industry,
    creation,
    modified
FROM raw.erpnext_customer
WHERE disabled = 0
  AND (is_internal_customer = 0 OR is_internal_customer IS NULL);

-- Staging: Items
DROP TABLE IF EXISTS staging.stg_item CASCADE;
CREATE TABLE staging.stg_item AS
SELECT
    name AS item_id,
    item_code,
    item_name,
    item_group,
    brand,
    is_stock_item = 1 AS is_stock,
    is_sales_item = 1 AS is_sales,
    is_purchase_item = 1 AS is_purchase,
    valuation_method,
    weight_per_unit::NUMERIC(18,6),
    weight_uom,
    stock_uom,
    purchase_uom,
    COALESCE(variant_of, '') AS variant_of,
    creation,
    modified
FROM raw.erpnext_item;

-- Staging: Warehouses (leaf nodes only)
DROP TABLE IF EXISTS staging.stg_warehouse CASCADE;
CREATE TABLE staging.stg_warehouse AS
SELECT
    name AS warehouse_id,
    warehouse_name,
    parent_warehouse,
    company,
    city,
    state,
    creation,
    modified
FROM raw.erpnext_warehouse
WHERE is_group = 0;

-- Staging: Stock Ledger (valid entries only)
DROP TABLE IF EXISTS staging.stg_stock_ledger CASCADE;
CREATE TABLE staging.stg_stock_ledger AS
SELECT
    name AS entry_id,
    posting_date,
    posting_time,
    voucher_type,
    voucher_no,
    item_code,
    warehouse,
    actual_qty::NUMERIC(18,6),
    qty_after_transaction::NUMERIC(18,6),
    incoming_rate::NUMERIC(18,6),
    outgoing_rate::NUMERIC(18,6),
    valuation_rate::NUMERIC(18,6),
    stock_value::NUMERIC(18,6),
    stock_value_difference::NUMERIC(18,6),
    batch_no,
    project,
    company,
    fiscal_year,
    creation,
    modified
FROM raw.erpnext_stock_ledger_entry
WHERE is_cancelled = '0';

-- Staging: Item Variant Attributes (all combinations)
DROP TABLE IF EXISTS staging.stg_item_variant_attribute CASCADE;
CREATE TABLE staging.stg_item_variant_attribute AS
SELECT
    parent AS item_code,
    attribute,
    attribute_value,
    numeric_values = 1 AS is_numeric,
    from_range::NUMERIC(18,6),
    to_range::NUMERIC(18,6),
    increment::NUMERIC(18,6)
FROM raw.erpnext_item_variant_attribute;

-- Add primary keys and indexes to staging tables
ALTER TABLE staging.stg_sales_invoice ADD PRIMARY KEY (invoice_id);
ALTER TABLE staging.stg_sales_invoice_item ADD PRIMARY KEY (item_id);
ALTER TABLE staging.stg_sales_order ADD PRIMARY KEY (order_id);
ALTER TABLE staging.stg_sales_order_item ADD PRIMARY KEY (item_id);
ALTER TABLE staging.stg_customer ADD PRIMARY KEY (customer_id);
ALTER TABLE staging.stg_item ADD PRIMARY KEY (item_id);
ALTER TABLE staging.stg_warehouse ADD PRIMARY KEY (warehouse_id);
ALTER TABLE staging.stg_stock_ledger ADD PRIMARY KEY (entry_id);

CREATE INDEX idx_stg_sales_invoice_item_invoice ON staging.stg_sales_invoice_item(invoice_id);
CREATE INDEX idx_stg_sales_invoice_item_item ON staging.stg_sales_invoice_item(item_code);
CREATE INDEX idx_stg_sales_order_item_order ON staging.stg_sales_order_item(order_id);
CREATE INDEX idx_stg_sales_order_item_item ON staging.stg_sales_order_item(item_code);
CREATE INDEX idx_stg_stock_ledger_item ON staging.stg_stock_ledger(item_code);
CREATE INDEX idx_stg_stock_ledger_warehouse ON staging.stg_stock_ledger(warehouse);
CREATE INDEX idx_stg_stock_ledger_posting_date ON staging.stg_stock_ledger(posting_date);
CREATE INDEX idx_stg_item_variant_item ON staging.stg_item_variant_attribute(item_code);
CREATE INDEX idx_stg_item_variant_attribute ON staging.stg_item_variant_attribute(attribute);
