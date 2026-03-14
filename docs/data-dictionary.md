# Data Dictionary

Complete reference for all tables, columns, and business meanings.

---

## Dimension Tables

### dim_date
**Purpose:** Calendar dimension for time-based analysis.
**Grain:** 1 row per calendar day
**Row Count:** ~4,000 (2020-2030)
**Primary Key:** date_id

| Column | Type | Business Meaning | Example |
|--------|------|------------------|---------|
| date_id | INTEGER | Date in YYYYMMDD format (surrogate key) | 20260314 |
| full_date | DATE | Actual calendar date | 2026-03-14 |
| year | INTEGER | Calendar year | 2026 |
| quarter | INTEGER | Calendar quarter (1-4) | 1 |
| month | INTEGER | Calendar month (1-12) | 3 |
| month_name | VARCHAR | Full month name | March |
| week_of_year | INTEGER | ISO week number | 11 |
| day_of_week | INTEGER | Day of week (0=Sun, 6=Sat) | 6 |
| day_name | VARCHAR | Full day name | Saturday |
| day_of_month | INTEGER | Day within month (1-31) | 14 |
| is_weekend | BOOLEAN | Is this day a weekend? | TRUE |
| fiscal_year | VARCHAR | Fiscal year (Apr-Mar) | 2025-26 |

---

### dim_customer
**Purpose:** Customer master for segmentation and grouping.
**Grain:** 1 row per unique customer
**Row Count:** 34
**Primary Key:** customer_key
**Business Key:** customer_id
**Filters:** Active (disabled=0)

| Column | Type | Business Meaning | Example | Notes |
|--------|------|------------------|---------|-------|
| customer_key | INTEGER | Surrogate key for joining | 1 | Auto-generated |
| customer_id | VARCHAR | ERPNext customer name | RAN-CUST-0001 | Unique, business key |
| customer_name | VARCHAR | Customer display name | Ragatex Ltd | May differ from ID |
| customer_type | VARCHAR | Type of customer | Company, Individual | From ERPNext |
| customer_group | VARCHAR | Customer segment | Premium, Bulk, Regular | For grouping/analysis |
| territory | VARCHAR | Sales region/territory | North India, South | Aligns with sales org |
| email_id | VARCHAR | Contact email | contact@company.com | Can be NULL |
| mobile_no | VARCHAR | Contact phone | +91-9876543210 | Can be NULL |
| credit_limit | NUMERIC(18,6) | Credit limit in company currency | 100000.00 | Can be 0 |
| market_segment | VARCHAR | Market classification | Domestic, Export | Optional |
| industry | VARCHAR | Industry classification | Textile, Retail | Optional |
| dw_load_date | TIMESTAMP | When loaded to warehouse | 2026-03-14 08:00:00 | System field |

---

### dim_item
**Purpose:** Product master for product-level analysis.
**Grain:** 1 row per unique item
**Row Count:** 34,761
**Primary Key:** item_key
**Business Key:** item_id

| Column | Type | Business Meaning | Example | Notes |
|--------|------|------------------|---------|-------|
| item_key | INTEGER | Surrogate key for joining | 1 | Auto-generated |
| item_id | VARCHAR | ERPNext item name | FAB-02912 | Unique, business key |
| item_code | VARCHAR | Item code | FAB-02912 | Can join to item attributes |
| item_name | VARCHAR | Item display name | Cotton Twill 54" | For reporting |
| item_group | VARCHAR | Product category | Fabric, Trims, Packing | For grouping/analysis |
| brand | VARCHAR | Brand/manufacturer | XYZ Mills | Can be NULL |
| is_stock | BOOLEAN | Is this item stocked? | TRUE | Determines if tracked |
| is_sales | BOOLEAN | Can item be sold? | TRUE | Item can be in sales orders |
| is_purchase | BOOLEAN | Can item be purchased? | FALSE | Item can be in purchase orders |
| valuation_method | VARCHAR | Stock valuation method | FIFO, Moving Average | For COGS calculation |
| weight_per_unit | NUMERIC(18,6) | Weight of one unit | 0.5 | Can be NULL |
| weight_uom | VARCHAR | Weight unit of measure | kg, lb | Can be NULL |
| stock_uom | VARCHAR | Stock/inventory unit | pcs, meters, kg | How item is tracked in stock |
| purchase_uom | VARCHAR | Purchase unit | rolls, cases, kg | How item is purchased |
| variant_of | VARCHAR | Parent item (if this is a variant) | FAB-02900 | NULL if not a variant |
| dw_load_date | TIMESTAMP | When loaded to warehouse | 2026-03-14 08:00:00 | System field |

---

### dim_item_attribute
**Purpose:** Item attributes for product property analysis (long format).
**Grain:** 1 row per item + attribute combination
**Row Count:** 138,830
**Primary Key:** attribute_key
**Indexes:** item_code, attribute

| Column | Type | Business Meaning | Example | Notes |
|--------|------|------------------|---------|-------|
| attribute_key | INTEGER | Surrogate key | 1 | Auto-generated |
| item_code | VARCHAR | Link to item | FAB-02912 | Join to dim_item.item_code |
| attribute | VARCHAR | Attribute name/type | COLOUR, SIZE, COMPOSITION | Enables Power BI slicing |
| attribute_value | VARCHAR | Value of attribute | GREY/WHITE, M, 100% COTTON | Specific property |
| is_numeric | BOOLEAN | Is this a numeric range? | FALSE | TRUE for numeric values |
| from_range | NUMERIC(18,6) | Range minimum (if numeric) | 1.0 | Can be NULL |
| to_range | NUMERIC(18,6) | Range maximum (if numeric) | 100.0 | Can be NULL |
| increment | NUMERIC(18,6) | Range increment (if numeric) | 0.5 | Can be NULL |
| dw_load_date | TIMESTAMP | When loaded to warehouse | 2026-03-14 08:00:00 | System field |

**Sample Attributes:**
- COLOUR (NAVY, WHITE, RED, etc.)
- SIZE (XS, S, M, L, XL, etc.)
- COMPOSITION (100% COTTON, 50% COTTON 50% POLYESTER, etc.)
- WIDTH (measure values in inches/cm)
- LENGTH (measure values in meters)

---

### dim_warehouse
**Purpose:** Location master for warehouse-level analysis.
**Grain:** 1 row per warehouse (leaf nodes only)
**Row Count:** 105
**Primary Key:** warehouse_key
**Business Key:** warehouse_id
**Filters:** Leaf warehouses (is_group=0)

| Column | Type | Business Meaning | Example | Notes |
|--------|------|------------------|---------|-------|
| warehouse_key | INTEGER | Surrogate key for joining | 1 | Auto-generated |
| warehouse_id | VARCHAR | ERPNext warehouse name | WH-DELHI | Unique, business key |
| warehouse_name | VARCHAR | Warehouse display name | Delhi Warehouse | For reporting |
| parent_warehouse | VARCHAR | Parent warehouse | WH-NORTH | Hierarchy reference |
| company | VARCHAR | Legal entity | Company A Ltd | Multi-company support |
| city | VARCHAR | City location | Delhi | For geographic analysis |
| state | VARCHAR | State/province | Delhi | For regional analysis |
| dw_load_date | TIMESTAMP | When loaded to warehouse | 2026-03-14 08:00:00 | System field |

---

## Fact Tables

### fact_sales_invoice_line
**Purpose:** Sales invoice line items (includes both sales and returns).
**Grain:** 1 row per invoice line item
**Row Count:** 5,724
**Primary Key:** fact_key
**Filters:** Submitted invoices only (docstatus=1)
**Foreign Keys:**
  - customer_key → dim_customer
  - item_key → dim_item
  - warehouse_key → dim_warehouse
  - invoice_date_id → dim_date
  - due_date_id → dim_date

| Column | Type | Business Meaning | Example | Formula |
|--------|------|------------------|---------|---------|
| fact_key | INTEGER | Surrogate key | 1 | Auto-generated |
| item_id | VARCHAR | Line item ID | SI-2026-00123-1 | ERPNext reference |
| invoice_id | VARCHAR | Invoice ID | SI-2026-00123 | ERPNext reference |
| customer_key | INTEGER | FK to dim_customer | 1 | Join on customer_id |
| item_key | INTEGER | FK to dim_item | 100 | Join on item_id |
| warehouse_key | INTEGER | FK to dim_warehouse | 5 | Join on warehouse_id |
| invoice_date_id | INTEGER | FK to dim_date | 20260314 | Join on posting_date |
| due_date_id | INTEGER | FK to dim_date | 20260314 | Join on due_date |
| is_return | BOOLEAN | Is this a return transaction? | FALSE | ERPNext is_return field |
| company | VARCHAR | Legal entity | Company A Ltd | For multi-company analysis |
| territory | VARCHAR | Sales territory | North India | From customer master |
| qty | NUMERIC(18,6) | Quantity sold | 100.00 | base_net_amount / rate |
| net_amount | NUMERIC(18,6) | Net amount (after discount) | 50000.00 | base_net_amount field |
| amount | NUMERIC(18,6) | Gross amount (before discount) | 55000.00 | base_amount field |
| discount_percentage | NUMERIC(18,6) | Discount % | 10.00 | From line item |
| gross_amount | NUMERIC(18,6) | Qty × Rate (recalc) | 55000.00 | Qty × unit_price |
| unit_price | NUMERIC(18,6) | Price per unit | 550.00 | rate field |
| signed_net_amount | NUMERIC(18,6) | Signed for returns | -50000.00 | IF is_return THEN -net_amount ELSE net_amount |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 08:00:00 | System field |

**Key Metrics:**
- `SUM(signed_net_amount)` = Net revenue (automatically accounts for returns)
- `SUM(qty)` = Total quantity sold
- `COUNT(DISTINCT invoice_id)` = Number of invoices
- `AVERAGE(signed_net_amount)` = Average transaction value

---

### fact_sales_order_line
**Purpose:** Sales order line items (demand/pipeline).
**Grain:** 1 row per order line item
**Row Count:** 33,191
**Primary Key:** fact_key
**Filters:** Submitted orders only (docstatus=1)
**Foreign Keys:**
  - customer_key → dim_customer
  - item_key → dim_item
  - warehouse_key → dim_warehouse
  - order_date_id → dim_date
  - delivery_date_id → dim_date

| Column | Type | Business Meaning | Example | Notes |
|--------|------|------------------|---------|-------|
| fact_key | INTEGER | Surrogate key | 1 | Auto-generated |
| item_id | VARCHAR | Line item ID | SO-2026-00456-1 | ERPNext reference |
| order_id | VARCHAR | Order ID | SO-2026-00456 | ERPNext reference |
| customer_key | INTEGER | FK to dim_customer | 1 | Join on customer_id |
| item_key | INTEGER | FK to dim_item | 100 | Join on item_id |
| warehouse_key | INTEGER | FK to dim_warehouse | 5 | Join on warehouse_id |
| order_date_id | INTEGER | FK to dim_date | 20260314 | Join on posting_date |
| delivery_date_id | INTEGER | FK to dim_date | 20260328 | Join on delivery_date |
| status | VARCHAR | Order status | To Deliver, Completed | ERPNext status field |
| company | VARCHAR | Legal entity | Company A Ltd | For multi-company analysis |
| territory | VARCHAR | Sales territory | North India | From customer master |
| qty | NUMERIC(18,6) | Order quantity | 100.00 | From line item |
| net_amount | NUMERIC(18,6) | Net order value | 50000.00 | Qty × Rate - Discount |
| amount | NUMERIC(18,6) | Gross order value | 55000.00 | Qty × Rate |
| discount_percentage | NUMERIC(18,6) | Discount % | 10.00 | From line item |
| gross_amount | NUMERIC(18,6) | Qty × Rate | 55000.00 | Recalculated |
| unit_price | NUMERIC(18,6) | Price per unit | 550.00 | rate field |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 08:00:00 | System field |

**Key Metrics:**
- `SUM(net_amount)` = Total order value
- `SUM(qty)` = Total quantity ordered
- `COUNT(DISTINCT order_id)` = Number of orders
- `AVERAGE(net_amount / qty)` = Average unit price

---

### fact_stock_movement
**Purpose:** Inventory transactions (complete audit trail).
**Grain:** 1 row per stock ledger entry
**Row Count:** 1,260,906
**Primary Key:** fact_key
**Filters:** Non-cancelled entries (is_cancelled='0')
**Foreign Keys:**
  - item_key → dim_item
  - warehouse_key → dim_warehouse
  - date_id → dim_date

| Column | Type | Business Meaning | Example | Notes |
|--------|------|------------------|---------|-------|
| fact_key | INTEGER | Surrogate key | 1 | Auto-generated |
| entry_id | VARCHAR | Stock ledger entry ID | SLE-2026-00789 | ERPNext reference |
| item_key | INTEGER | FK to dim_item | 100 | Join on item_code |
| warehouse_key | INTEGER | FK to dim_warehouse | 5 | Join on warehouse_id |
| date_id | INTEGER | FK to dim_date | 20260314 | Join on posting_date |
| voucher_type | VARCHAR | Type of transaction | Receipt, Issue, Transfer | From stock ledger |
| voucher_no | VARCHAR | Transaction ID | PR-2026-00001 | Document number |
| company | VARCHAR | Legal entity | Company A Ltd | For multi-company analysis |
| project | VARCHAR | Project reference | Project A | Can be NULL |
| batch_no | VARCHAR | Batch/lot number | BATCH-001 | Can be NULL |
| fiscal_year | VARCHAR | Fiscal year | 2025-26 | For period analysis |
| actual_qty | NUMERIC(18,6) | Qty in/out this transaction | 100.00 | Positive = IN, Negative = OUT |
| qty_after_transaction | NUMERIC(18,6) | Running balance | 500.00 | Inventory level after transaction |
| incoming_rate | NUMERIC(18,6) | Cost (inbound) | 550.00 | For inbound transactions |
| outgoing_rate | NUMERIC(18,6) | Cost (outbound) | 550.00 | For outbound transactions |
| valuation_rate | NUMERIC(18,6) | Rate used for valuation | 550.00 | Per ERPNext valuation method |
| stock_value | NUMERIC(18,6) | Value of inventory | 275000.00 | qty_after_transaction × valuation_rate |
| stock_value_difference | NUMERIC(18,6) | Value change | 55000.00 | Qty change × rate |
| movement_type | VARCHAR | IN / OUT / ZERO | IN | Derived from actual_qty sign |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 08:00:00 | System field |

**Key Metrics:**
- `MAX(qty_after_transaction)` (per item/warehouse, latest date) = Current stock
- `SUM(stock_value_difference)` = Inventory value change
- `SUM(actual_qty WHERE movement_type='IN')` = Total inbound
- `SUM(actual_qty WHERE movement_type='OUT')` = Total outbound

---

## Staging Tables (Reference)

Staging tables are intermediate, not used for reporting. They are cleaned versions of raw tables.

| Staging Table | Purpose | Row Count |
|---|---|---|
| stg_sales_invoice | Submitted invoices only | ~1,482 |
| stg_sales_invoice_item | Submitted invoice items | ~5,724 |
| stg_sales_order | Submitted orders only | ~4,574 |
| stg_sales_order_item | Submitted order items | ~33,191 |
| stg_customer | Active customers | 34 |
| stg_item | All items | 34,761 |
| stg_warehouse | Leaf warehouses | 105 |
| stg_stock_ledger | Non-cancelled entries | ~1,260,906 |
| stg_item_variant_attribute | Item attributes | 138,830 |

---

## Key Business Rules

1. **Submitted Records Only:** Facts contain only docstatus=1 (posted/submitted documents)
2. **Active Entities:** Customers with disabled=0, warehouses with is_group=0
3. **Return Handling:** signed_net_amount automatically negates returns
4. **Fiscal Year:** Apr-Mar (Apr = FY start)
5. **Surrogate Keys:** All dimension FKs use auto-generated _key columns
6. **Latest Stock:** Use PARTITION BY item_key, warehouse_key and ORDER BY date_id DESC to get current levels
7. **Currency:** All amounts in company currency (INR assumed)

---

## Common Calculation Patterns

### Revenue (Sales Only)
```sql
SELECT SUM(signed_net_amount)
FROM fact_sales_invoice_line
WHERE is_return = FALSE
```

### Return Rate %
```sql
SELECT
    SUM(CASE WHEN is_return THEN qty ELSE 0 END) /
    SUM(qty) * 100 AS return_rate_pct
FROM fact_sales_invoice_line
```

### Current Inventory (per item/warehouse)
```sql
SELECT item_key, warehouse_key, qty_after_transaction
FROM fact_stock_movement
WHERE (item_key, warehouse_key, date_id) IN (
    SELECT item_key, warehouse_key, MAX(date_id)
    FROM fact_stock_movement
    GROUP BY item_key, warehouse_key
)
```

### Monthly Trend
```sql
SELECT
    d.month,
    d.year,
    SUM(f.signed_net_amount) as revenue
FROM fact_sales_invoice_line f
JOIN dim_date d ON f.invoice_date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month
```

### Customer Segment Analysis
```sql
SELECT
    c.customer_group,
    SUM(f.signed_net_amount) as revenue,
    COUNT(DISTINCT f.customer_key) as num_customers
FROM fact_sales_invoice_line f
JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE f.is_return = FALSE
GROUP BY c.customer_group
ORDER BY revenue DESC
```

---

## Glossary

| Term | Definition |
|------|-----------|
| **Surrogate Key** | Auto-generated sequential number (e.g., customer_key) |
| **Business Key** | Natural key from source (e.g., customer_id) |
| **Grain** | Level of detail (1 row = what?) |
| **Fact** | Transactional table with measures |
| **Dimension** | Lookup table with attributes |
| **Star Schema** | Facts joined to dimensions |
| **Slowly Changing Dimension** | Dimension that changes over time |
| **docstatus** | ERPNext document status (0=Draft, 1=Submitted, 2=Cancelled) |
| **Valuation Rate** | Cost per unit for inventory valuation |
| **Fiscal Year** | Financial reporting year (Apr-Mar for India) |
