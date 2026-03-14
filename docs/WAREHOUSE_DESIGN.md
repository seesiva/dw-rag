# ERPNext Sales Analytics Warehouse — Design Document

## Executive Summary

A complete PostgreSQL analytical warehouse (raw → staging → mart) for ERPNext sales and inventory analytics. Supports Power BI dashboards and AI-driven queries through a clean star schema.

**Total Data Volume:** ~1.5M rows (dominated by 1.26M stock ledger entries)
**Tables Extracted:** 11 core source tables
**Warehouse Tables:** 13 (5 dimensions, 3 facts, 5 staging)

---

## Warehouse Layers

### Raw Layer (`raw` schema)
- Direct extracts from MariaDB
- Column names preserved as-is
- Safe for complete reload
- 11 source tables

### Staging Layer (`staging` schema)
- Cleaned and normalized
- Snake_case column naming
- Proper data types (NUMERIC, DATE, BOOLEAN)
- Filters: submitted records only (docstatus=1)
- Deactivated entities excluded

### Mart Layer (`mart` schema)
- Star schema optimized for analytics
- Surrogate keys for dimensional consistency
- Ready for Power BI / Tableau / analytics
- 3 fact tables, 5 dimension tables

---

## Dimensional Model

### Dimensions

**dim_date** (Calendar)
- Grain: 1 day (2020–2030)
- Fields: date_id, full_date, year, quarter, month, week, day_of_week, day_name, is_weekend, fiscal_year (Apr–Mar)
- Purpose: Time-based analysis

**dim_customer** (Customer Master)
- Grain: 1 per unique customer (34 rows)
- Fields: customer_key, customer_id, customer_name, customer_type, customer_group, territory, email_id, mobile_no, credit_limit, market_segment, industry
- Purpose: Customer segmentation, analytics by group/territory

**dim_item** (Product Master)
- Grain: 1 per unique item (34,761 rows)
- Fields: item_key, item_id, item_code, item_name, item_group, brand, is_stock, is_sales, is_purchase, valuation_method, weight, UOM
- Purpose: Product-level analysis

**dim_item_attribute** (Product Attributes)
- Grain: 1 per item + attribute combination (138,830 rows)
- Fields: attribute_key, item_code, attribute (COLOUR, SIZE, COMPOSITION, etc.), attribute_value, is_numeric
- Purpose: Enables Power BI filtering by garment properties (color, size, composition, etc.)
- Example: Item ABC-123 has attributes: COLOUR=NAVY, SIZE=M, COMPOSITION=100% COTTON

**dim_warehouse** (Location Master)
- Grain: 1 per warehouse (105 rows)
- Fields: warehouse_key, warehouse_id, warehouse_name, parent_warehouse, company, city, state
- Purpose: Location-based inventory analysis

### Facts

**fact_sales_order_line** (Sales Order Detail)
- Grain: 1 row per order line item (33,191 rows)
- Foreign Keys: customer_key, item_key, warehouse_key, order_date_id, delivery_date_id
- Measures: qty, net_amount, amount, discount_percentage, gross_amount, unit_price
- Attributes: order_id, status, company, territory
- Use Case: Sales pipeline analysis, order fulfillment tracking

**fact_sales_invoice_line** (Sales Invoice Detail)
- Grain: 1 row per invoice line item (5,724 rows)
- Foreign Keys: customer_key, item_key, warehouse_key, invoice_date_id, due_date_id
- Measures: qty, net_amount, amount, discount_percentage, gross_amount, unit_price, signed_net_amount
- Attributes: invoice_id, is_return, company, territory
- Special: signed_net_amount negates returns for accurate revenue calculation
- Use Case: Revenue analysis, handles sales and returns together

**fact_stock_movement** (Inventory Transactions)
- Grain: 1 row per stock ledger entry (1,260,906 rows)
- Foreign Keys: item_key, warehouse_key, date_id
- Measures: actual_qty, qty_after_transaction, incoming_rate, outgoing_rate, valuation_rate, stock_value, stock_value_difference
- Attributes: entry_id, voucher_type (Receipt/Issue/Transfer), voucher_no, batch_no, movement_type (IN/OUT/ZERO), fiscal_year, project
- Use Case: Inventory audit, stock valuation, movement analysis

---

## Key Design Decisions

### 1. Surrogate Keys
- Dimensions use auto-incrementing _key columns (customer_key, item_key, etc.)
- Avoids multi-column joins; supports slowly-changing dimensions later
- Facts reference _key columns

### 2. Submitted Records Only
- All facts filter to docstatus = 1 (submitted ERPNext documents)
- Excludes drafts, cancelled, pending approval
- Ensures consistency with ERPNext GL/books

### 3. Item Attributes in Long Format
- dim_item_attribute has 1 row per item+attribute combo
- Each row: (item_code, attribute, attribute_value)
- Enables Power BI slicers: "Show sales by COLOR"
- Alternative (wide format) would require schema changes per attribute

### 4. Handling Returns
- fact_sales_invoice_line has is_return flag
- signed_net_amount automatically negates returns
- Simplifies Power BI calculations: SUM(signed_net_amount) = net revenue

### 5. Idempotent Pipelines
- All scripts use TRUNCATE + INSERT (safe to rerun)
- No incremental logic yet (future enhancement)
- Good for daily batch loads

### 6. Fiscal Year (Apr–Mar)
- dim_date includes fiscal_year field
- Calculated as: if month >= April then year, else year-1
- Aligns with typical garment/export industry fiscal calendar

---

## Data Quality & Validation

### Validation Rules (in sql/validation/)
1. Row count reconciliation: raw → staging → mart
2. Submitted filter: All facts contain only docstatus=1 records
3. FK integrity: No orphan dimension keys in facts
4. Return handling: is_return flag properly propagated

### Run Validation
```bash
psql -U postgres -d dw_rag -f sql/validation/01_row_counts.sql
```

---

## Power BI Integration

### Connection String
```
Driver: PostgreSQL Unicode
Server: localhost
Database: dw_rag
User: postgres
Password: postgres
```

### Recommended Relationships
- fact_sales_invoice_line → dim_customer (customer_key)
- fact_sales_invoice_line → dim_item (item_key)
- fact_sales_invoice_line → dim_warehouse (warehouse_key)
- fact_sales_invoice_line → dim_date (invoice_date_id)
- fact_stock_movement → dim_item (item_key)
- fact_stock_movement → dim_warehouse (warehouse_key)

---

## Files Structure

```
dw-rag/
├── claude.md                          (Project charter)
├── README.md                          (Quick start)
├── WAREHOUSE_DESIGN.md                (This file)
├── src/
│   ├── config.py                      (DB connections)
│   └── extract.py                     (ETL extraction)
├── sql/
│   ├── raw/01_create_raw_schema.sql   (Create raw tables)
│   ├── staging/01_stg_all.sql         (Cleaning & normalization)
│   ├── mart/
│   │   ├── 01_dim_date.sql
│   │   ├── 02_dim_customer.sql
│   │   ├── 03_dim_item.sql
│   │   ├── 04_dim_item_attribute.sql
│   │   ├── 05_dim_warehouse.sql
│   │   ├── 06_fact_sales_order_line.sql
│   │   ├── 07_fact_sales_invoice_line.sql
│   │   └── 08_fact_stock_movement.sql
│   └── validation/01_row_counts.sql   (QA checks)
└── backup/
    └── 1bd3e0294da19198-2026-01-27.sql (Source ERPNext backup)
```

Generated: 2026-03-14
