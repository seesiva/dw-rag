-- Create raw schema and core tables for ERPNext extraction
-- Idempotent: safe to rerun

CREATE SCHEMA IF NOT EXISTS raw;

-- Sales Invoices
DROP TABLE IF EXISTS raw.erpnext_sales_invoice CASCADE;
CREATE TABLE raw.erpnext_sales_invoice (
    name VARCHAR(140) PRIMARY KEY,
    creation TIMESTAMP,
    modified TIMESTAMP,
    modified_by VARCHAR(140),
    owner VARCHAR(140),
    docstatus INT,
    customer VARCHAR(140),
    customer_name VARCHAR(140),
    customer_group VARCHAR(140),
    posting_date DATE,
    due_date DATE,
    po_date DATE,
    po_no VARCHAR(140),
    base_net_total DECIMAL(18,6),
    base_grand_total DECIMAL(18,6),
    base_total_taxes_and_charges DECIMAL(18,6),
    total_qty DECIMAL(18,6),
    currency VARCHAR(140),
    is_return INT,
    return_against VARCHAR(140),
    conversion_rate DECIMAL(21,9),
    cost_center VARCHAR(140),
    campaign VARCHAR(140),
    company VARCHAR(140),
    status VARCHAR(140),
    territory VARCHAR(140),
    project VARCHAR(140)
);

-- Sales Invoice Items
DROP TABLE IF EXISTS raw.erpnext_sales_invoice_item CASCADE;
CREATE TABLE raw.erpnext_sales_invoice_item (
    name VARCHAR(140) PRIMARY KEY,
    parent VARCHAR(140),
    parenttype VARCHAR(140),
    idx INT,
    item_code VARCHAR(140),
    item_name VARCHAR(140),
    item_group VARCHAR(140),
    qty DECIMAL(18,6),
    rate DECIMAL(18,6),
    base_rate DECIMAL(18,6),
    base_net_rate DECIMAL(18,6),
    base_net_amount DECIMAL(18,6),
    base_amount DECIMAL(18,6),
    warehouse VARCHAR(140),
    uom VARCHAR(140),
    discount_percentage DECIMAL(18,6),
    discount_amount DECIMAL(18,6),
    brand VARCHAR(140),
    cost_center VARCHAR(140),
    so_detail VARCHAR(140),
    delivery_note VARCHAR(140),
    net_amount DECIMAL(18,6),
    amount DECIMAL(18,6)
);

-- Sales Orders
DROP TABLE IF EXISTS raw.erpnext_sales_order CASCADE;
CREATE TABLE raw.erpnext_sales_order (
    name VARCHAR(140) PRIMARY KEY,
    creation TIMESTAMP,
    modified TIMESTAMP,
    modified_by VARCHAR(140),
    docstatus INT,
    customer VARCHAR(140),
    customer_name VARCHAR(140),
    transaction_date DATE,
    posting_date DATE,
    delivery_date DATE,
    base_net_total DECIMAL(18,6),
    base_grand_total DECIMAL(18,6),
    base_total_taxes_and_charges DECIMAL(18,6),
    total_qty DECIMAL(18,6),
    currency VARCHAR(140),
    status VARCHAR(140),
    company VARCHAR(140),
    cost_center VARCHAR(140),
    project VARCHAR(140),
    territory VARCHAR(140)
);

-- Sales Order Items
DROP TABLE IF EXISTS raw.erpnext_sales_order_item CASCADE;
CREATE TABLE raw.erpnext_sales_order_item (
    name VARCHAR(140) PRIMARY KEY,
    parent VARCHAR(140),
    parenttype VARCHAR(140),
    idx INT,
    item_code VARCHAR(140),
    item_name VARCHAR(140),
    item_group VARCHAR(140),
    qty DECIMAL(18,6),
    rate DECIMAL(18,6),
    base_rate DECIMAL(18,6),
    base_net_rate DECIMAL(18,6),
    base_net_amount DECIMAL(18,6),
    base_amount DECIMAL(18,6),
    warehouse VARCHAR(140),
    uom VARCHAR(140),
    discount_percentage DECIMAL(18,6),
    brand VARCHAR(140),
    cost_center VARCHAR(140),
    delivery_date DATE,
    net_amount DECIMAL(18,6),
    amount DECIMAL(18,6)
);

-- Customers
DROP TABLE IF EXISTS raw.erpnext_customer CASCADE;
CREATE TABLE raw.erpnext_customer (
    name VARCHAR(140) PRIMARY KEY,
    creation TIMESTAMP,
    modified TIMESTAMP,
    customer_name VARCHAR(140),
    customer_type VARCHAR(140),
    customer_group VARCHAR(140),
    territory VARCHAR(140),
    disabled INT,
    email_id VARCHAR(140),
    mobile_no VARCHAR(140),
    credit_limit DECIMAL(18,6),
    market_segment VARCHAR(140),
    industry VARCHAR(140)
);

-- Items
DROP TABLE IF EXISTS raw.erpnext_item CASCADE;
CREATE TABLE raw.erpnext_item (
    name VARCHAR(140) PRIMARY KEY,
    creation TIMESTAMP,
    modified TIMESTAMP,
    item_name VARCHAR(140),
    item_group VARCHAR(140),
    is_stock_item INT,
    is_sales_item INT,
    is_purchase_item INT,
    brand VARCHAR(140),
    item_code VARCHAR(140),
    valuation_method VARCHAR(140),
    description TEXT,
    weight_per_unit DECIMAL(18,6),
    weight_uom VARCHAR(140),
    stock_uom VARCHAR(140),
    purchase_uom VARCHAR(140),
    variant_of VARCHAR(140),
    docstatus INT
);

-- Warehouses
DROP TABLE IF EXISTS raw.erpnext_warehouse CASCADE;
CREATE TABLE raw.erpnext_warehouse (
    name VARCHAR(140) PRIMARY KEY,
    warehouse_name VARCHAR(140),
    parent_warehouse VARCHAR(140),
    company VARCHAR(140),
    is_group INT,
    disabled INT,
    city VARCHAR(140),
    state VARCHAR(140),
    address_line_1 VARCHAR(140),
    address_line_2 VARCHAR(140)
);

-- Stock Ledger Entry
DROP TABLE IF EXISTS raw.erpnext_stock_ledger_entry CASCADE;
CREATE TABLE raw.erpnext_stock_ledger_entry (
    name VARCHAR(140) PRIMARY KEY,
    creation TIMESTAMP,
    modified TIMESTAMP,
    posting_date DATE,
    posting_time TIME,
    voucher_type VARCHAR(140),
    voucher_no VARCHAR(140),
    item_code VARCHAR(140),
    warehouse VARCHAR(140),
    actual_qty DECIMAL(18,6),
    qty_after_transaction DECIMAL(18,6),
    incoming_rate DECIMAL(18,6),
    outgoing_rate DECIMAL(18,6),
    valuation_rate DECIMAL(18,6),
    stock_value DECIMAL(18,6),
    stock_value_difference DECIMAL(18,6),
    batch_no VARCHAR(140),
    serial_no TEXT,
    project VARCHAR(140),
    company VARCHAR(140),
    is_cancelled VARCHAR(140),
    fiscal_year VARCHAR(140),
    stock_queue TEXT
);

-- Item Attributes
DROP TABLE IF EXISTS raw.erpnext_item_attribute CASCADE;
CREATE TABLE raw.erpnext_item_attribute (
    name VARCHAR(140) PRIMARY KEY,
    creation TIMESTAMP,
    modified TIMESTAMP,
    attribute_name VARCHAR(140),
    docstatus INT
);

-- Item Attribute Values
DROP TABLE IF EXISTS raw.erpnext_item_attribute_value CASCADE;
CREATE TABLE raw.erpnext_item_attribute_value (
    name VARCHAR(140) PRIMARY KEY,
    parent VARCHAR(140),
    parenttype VARCHAR(140),
    idx INT,
    attribute_value VARCHAR(140)
);

-- Item Variant Attributes (linking items to their attribute values)
DROP TABLE IF EXISTS raw.erpnext_item_variant_attribute CASCADE;
CREATE TABLE raw.erpnext_item_variant_attribute (
    name VARCHAR(140) PRIMARY KEY,
    parent VARCHAR(140),
    parenttype VARCHAR(140),
    idx INT,
    attribute VARCHAR(140),
    attribute_value VARCHAR(140),
    numeric_values INT,
    from_range DECIMAL(18,6),
    to_range DECIMAL(18,6),
    increment DECIMAL(18,6)
);

CREATE INDEX idx_sales_invoice_customer ON raw.erpnext_sales_invoice(customer);
CREATE INDEX idx_sales_invoice_posting_date ON raw.erpnext_sales_invoice(posting_date);
CREATE INDEX idx_sales_invoice_item_parent ON raw.erpnext_sales_invoice_item(parent);
CREATE INDEX idx_sales_order_customer ON raw.erpnext_sales_order(customer);
CREATE INDEX idx_sales_order_item_parent ON raw.erpnext_sales_order_item(parent);
CREATE INDEX idx_stock_ledger_item ON raw.erpnext_stock_ledger_entry(item_code);
CREATE INDEX idx_stock_ledger_warehouse ON raw.erpnext_stock_ledger_entry(warehouse);
CREATE INDEX idx_stock_ledger_posting_date ON raw.erpnext_stock_ledger_entry(posting_date);
CREATE INDEX idx_item_variant_attr_parent ON raw.erpnext_item_variant_attribute(parent);
