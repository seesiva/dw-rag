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

## Operational Readiness Fact Tables

### fact_material_shortage

**Purpose:** Monitor current stock status across warehouses. Identifies items at zero or negative stock that block production and delivery.

**Grain:** 1 row per item + warehouse combination (current snapshot)

**Key Columns:**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| item_key | INTEGER | FK to dim_item | 1045 |
| warehouse_key | INTEGER | FK to dim_warehouse | 12 |
| item_code | VARCHAR | ERPNext item code | GAR-2024-001 |
| item_name | VARCHAR | Item display name | Shirt Size M Red |
| item_group | VARCHAR | Product category | Finished Goods |
| warehouse | VARCHAR | Warehouse name | Mumbai WH |
| current_qty | NUMERIC(18,6) | Latest qty on hand | -5.00 |
| is_shortfall | BOOLEAN | TRUE if qty <= 0 | TRUE |
| stock_status | VARCHAR | Status: 'Negative', 'Zero Stock', 'Available' | Negative |
| last_stock_movement_date | DATE | Last transaction date | 2026-03-14 |
| is_stock | BOOLEAN | Item is tracked in inventory? | TRUE |
| is_sales | BOOLEAN | Item is saleable? | TRUE |
| is_purchase | BOOLEAN | Item is purchasable? | FALSE |
| brand | VARCHAR | Product brand | RAGA |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 10:30:00 |

**Query Examples:**

```sql
-- Items in critical shortage (negative stock)
SELECT item_code, item_name, warehouse, current_qty
FROM fact_material_shortage
WHERE stock_status = 'Negative'
ORDER BY current_qty ASC;

-- Stock shortage by warehouse
SELECT warehouse, COUNT(*) as shortage_count, SUM(current_qty) as total_shortage_qty
FROM fact_material_shortage
WHERE is_shortfall = TRUE
GROUP BY warehouse
ORDER BY shortage_count DESC;

-- Sales items with no stock
SELECT item_code, item_name, COUNT(DISTINCT warehouse) as warehouses_short
FROM fact_material_shortage
WHERE is_stock = TRUE AND is_sales = TRUE AND is_shortfall = TRUE
GROUP BY item_code, item_name
ORDER BY warehouses_short DESC;
```

---

### fact_sales_order_readiness

**Purpose:** Track sales order fulfillment status and delivery gaps. Identifies orders overdue, due soon, or pending delivery.

**Grain:** 1 row per sales order

**Key Columns:**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| fact_key | INTEGER | Primary key | 1234 |
| order_id | VARCHAR | ERPNext order ID | SO-2026-00156 |
| customer_key | INTEGER | FK to dim_customer | 8 |
| customer_name | VARCHAR | Customer display name | BLUE DIAMOND |
| order_date | DATE | Order creation date | 2026-03-01 |
| expected_delivery_date | DATE | Promised delivery date | 2026-03-20 |
| order_status | VARCHAR | ERPNext status | To Deliver and Bill |
| fulfillment_status | VARCHAR | Status: 'Overdue', 'Due Today', 'Due This Week', 'Pending', 'Closed' | Overdue |
| is_overdue | BOOLEAN | TRUE if past delivery date | TRUE |
| days_past_due | INTEGER | Days late (0 if not overdue) | 5 |
| days_until_due | INTEGER | Days until due (0 if overdue) | 0 |
| qty_ordered | NUMERIC(18,6) | Total order quantity | 100.00 |
| line_count | INTEGER | Number of line items | 3 |
| net_total | NUMERIC(18,6) | Order total before tax | 45000.00 |
| grand_total | NUMERIC(18,6) | Order total after tax | 53100.00 |
| company | VARCHAR | Legal entity | RAGA TEX INDIA |
| territory | VARCHAR | Sales territory | North India |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 10:30:00 |

**Query Examples:**

```sql
-- Overdue orders requiring escalation
SELECT order_id, customer_name, expected_delivery_date, days_past_due, grand_total
FROM fact_sales_order_readiness
WHERE is_overdue = TRUE
ORDER BY days_past_due DESC;

-- Orders due this week
SELECT order_id, customer_name, expected_delivery_date, qty_ordered
FROM fact_sales_order_readiness
WHERE fulfillment_status = 'Due This Week'
ORDER BY expected_delivery_date;

-- Fulfillment by territory
SELECT territory, COUNT(*) as order_count,
       COUNT(CASE WHEN is_overdue THEN 1 END) as overdue_count,
       ROUND(100.0 * COUNT(CASE WHEN is_overdue THEN 1 END) / COUNT(*), 1) as overdue_pct
FROM fact_sales_order_readiness
WHERE order_status != 'Closed'
GROUP BY territory
ORDER BY overdue_pct DESC;
```

---

### fact_item_master_readiness

**Purpose:** Monitor item master data completeness. Identifies items with missing critical attributes that block downstream processes.

**Grain:** 1 row per item

**Key Columns:**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| item_key | INTEGER | FK to dim_item | 502 |
| item_code | VARCHAR | Item code | GAR-2024-SHIRT-M-BLU |
| item_name | VARCHAR | Item display name | Shirt Size M Blue |
| item_group | VARCHAR | Product category | Finished Goods |
| brand | VARCHAR | Brand/manufacturer | RAGA |
| has_item_group | BOOLEAN | Item group assigned? | TRUE |
| has_brand | BOOLEAN | Brand assigned? | TRUE |
| has_weight | BOOLEAN | Weight recorded? | FALSE |
| has_stock_uom | BOOLEAN | Stock UOM defined? | TRUE |
| has_purchase_uom | BOOLEAN | Purchase UOM defined? | TRUE |
| is_sales | BOOLEAN | Marked as saleable? | TRUE |
| is_stock | BOOLEAN | Marked as stocked? | TRUE |
| is_purchase | BOOLEAN | Marked as purchasable? | FALSE |
| is_sales_item | BOOLEAN | Is saleable (derived)? | TRUE |
| is_stock_item | BOOLEAN | Is stocked (derived)? | TRUE |
| is_purchase_item | BOOLEAN | Is purchasable (derived)? | FALSE |
| has_recent_sales_activity | BOOLEAN | Appears in recent sales? | TRUE |
| sales_readiness_score | NUMERIC(5,1) | Sales item completeness (0-100) | 75.0 |
| stock_readiness_score | NUMERIC(5,1) | Stock item completeness (0-100) | 50.0 |
| purchase_readiness_score | NUMERIC(5,1) | Purchase item completeness (0-100) | 0.0 |
| readiness_status | VARCHAR | 'COMPLETE' or 'INCOMPLETE' | INCOMPLETE |
| creation | TIMESTAMP | Item creation date in ERP | 2025-06-15 08:00:00 |
| modified | TIMESTAMP | Last modified date in ERP | 2026-03-10 14:22:00 |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 10:30:00 |

**Query Examples:**

```sql
-- Items with incomplete master data
SELECT item_code, item_name, readiness_status, sales_readiness_score, stock_readiness_score
FROM fact_item_master_readiness
WHERE readiness_status = 'INCOMPLETE'
ORDER BY sales_readiness_score, stock_readiness_score;

-- Sales items missing brand
SELECT item_code, item_name, sales_readiness_score
FROM fact_item_master_readiness
WHERE is_sales = TRUE AND has_brand = FALSE AND has_recent_sales_activity = TRUE
ORDER BY item_code;

-- Data completeness summary
SELECT
    SUM(CASE WHEN readiness_status = 'COMPLETE' THEN 1 END) as complete_count,
    SUM(CASE WHEN readiness_status = 'INCOMPLETE' THEN 1 END) as incomplete_count,
    ROUND(100.0 * SUM(CASE WHEN readiness_status = 'COMPLETE' THEN 1 END) / COUNT(*), 1) as pct_complete
FROM fact_item_master_readiness
WHERE is_sales = TRUE OR is_stock = TRUE;
```

---

### fact_work_order_readiness

**Purpose:** Monitor work order production status and identify work orders that haven't had job cards created or are overdue.

**Grain:** 1 row per work order

**Key Columns:**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| fact_key | INTEGER | Primary key | 156 |
| work_order_id | VARCHAR | Work order ID | WO-2026-00012 |
| item_key | INTEGER | FK to dim_item | 2145 |
| item_code | VARCHAR | Product code | GAR-2024-SHIRT-L-RED |
| item_name | VARCHAR | Product display name | Shirt Size L Red |
| bom_no | VARCHAR | Associated BOM | BOM-SHIRT-001 |
| status | VARCHAR | Work order status | In Process |
| planned_qty | NUMERIC(18,6) | Planned production qty | 500.00 |
| produced_qty | NUMERIC(18,6) | Actual produced qty | 250.00 |
| planned_start_date | DATE | Planned start | 2026-03-10 |
| planned_end_date | DATE | Planned end | 2026-03-15 |
| actual_start_date | DATE | Actual start | 2026-03-11 |
| completion_pct | NUMERIC(5,1) | % of planned produced | 50.0 |
| production_status | VARCHAR | Status: 'Not Started', 'In Progress', 'Completed' | In Progress |
| is_overdue | BOOLEAN | Past planned end date? | FALSE |
| days_overdue | INTEGER | Days late (0 if on time) | 0 |
| has_job_cards | BOOLEAN | Job cards created? | FALSE |
| job_card_count | INTEGER | Number of job cards | 0 |
| material_item_count | INTEGER | Number of material lines | 8 |
| readiness_flag | VARCHAR | Status: MISSING_JOB_CARDS, OVERDUE, etc. | MISSING_JOB_CARDS |
| company | VARCHAR | Legal entity | RAGA TEX INDIA |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 10:30:00 |

**Query Examples:**

```sql
-- Work orders missing job cards (blocks labor tracking)
SELECT work_order_id, item_code, planned_qty, produced_qty, job_card_count
FROM fact_work_order_readiness
WHERE has_job_cards = FALSE AND production_status != 'Completed'
ORDER BY planned_end_date;

-- Overdue work orders
SELECT work_order_id, item_code, planned_end_date, days_overdue, completion_pct
FROM fact_work_order_readiness
WHERE is_overdue = TRUE AND production_status IN ('Not Started', 'In Progress')
ORDER BY days_overdue DESC;

-- Work order completion status
SELECT
    production_status,
    COUNT(*) as wo_count,
    ROUND(AVG(completion_pct), 1) as avg_completion,
    COUNT(CASE WHEN has_job_cards = FALSE THEN 1 END) as missing_job_cards
FROM fact_work_order_readiness
GROUP BY production_status
ORDER BY wo_count DESC;
```

---

### fact_purchase_readiness

**Purpose:** Monitor purchase order fulfillment and identify items pending receipt that block production.

**Grain:** 1 row per purchase order line item

**Key Columns:**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| fact_key | INTEGER | Primary key | 489 |
| po_id | VARCHAR | Purchase order ID | PO-2026-00089 |
| item_key | INTEGER | FK to dim_item | 1203 |
| warehouse_key | INTEGER | FK to dim_warehouse | 5 |
| supplier | VARCHAR | Supplier name | COTTON MILLS LTD |
| item_code | VARCHAR | Item code | RAW-COTTON-001 |
| item_name | VARCHAR | Item name | Raw Cotton (Grade A) |
| ordered_qty | NUMERIC(18,6) | Qty ordered | 1000.00 |
| received_qty | NUMERIC(18,6) | Qty received | 600.00 |
| pending_qty | NUMERIC(18,6) | Qty still pending | 400.00 |
| rate | NUMERIC(18,6) | Unit rate | 45.50 |
| base_rate | NUMERIC(18,6) | Base rate | 45.50 |
| amount | NUMERIC(18,6) | Line total | 45500.00 |
| po_date | DATE | PO creation date | 2026-02-20 |
| po_expected_delivery_date | DATE | Expected delivery | 2026-03-10 |
| po_status | VARCHAR | PO status | To Receive and Bill |
| receipt_status | VARCHAR | 'Not Received', 'Partially Received', 'Fully Received' | Partially Received |
| is_overdue | BOOLEAN | Past expected date? | TRUE |
| days_pending | INTEGER | Days waiting | 4 |
| days_until_due | INTEGER | Days until due (0 if overdue) | 0 |
| fulfillment_status | VARCHAR | RECEIVED, PARTIALLY_RECEIVED, PENDING_RECEIPT, OVERDUE | OVERDUE |
| company | VARCHAR | Legal entity | RAGA TEX INDIA |
| warehouse | VARCHAR | Receiving warehouse | Mumbai WH |
| dw_load_date | TIMESTAMP | Load timestamp | 2026-03-14 10:30:00 |

**Query Examples:**

```sql
-- Items pending receipt that are overdue (critical)
SELECT po_id, supplier, item_code, item_name, pending_qty, days_pending
FROM fact_purchase_readiness
WHERE is_overdue = TRUE AND receipt_status IN ('Not Received', 'Partially Received')
ORDER BY days_pending DESC;

-- Purchase order fulfillment by supplier
SELECT
    supplier,
    COUNT(*) as po_lines,
    SUM(CASE WHEN receipt_status = 'Fully Received' THEN 1 END) as fully_received,
    SUM(CASE WHEN receipt_status = 'Partially Received' THEN 1 END) as partially_received,
    SUM(CASE WHEN receipt_status = 'Not Received' THEN 1 END) as not_received
FROM fact_purchase_readiness
GROUP BY supplier
ORDER BY supplier;

-- Items awaiting receipt for more than N days
SELECT po_id, item_code, item_name, pending_qty, expected_delivery, days_pending
FROM fact_purchase_readiness
WHERE pending_qty > 0 AND days_pending > 7
ORDER BY days_pending DESC;
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
