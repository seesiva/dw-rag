# Data Model

## Star Schema Overview

```
                    dim_date
                       |
     dim_customer ------|------ dim_warehouse
            |           |           |
            |      fact_sales      |
            |      _invoice_line   |
            |           |           |
     dim_item ----------|-----------|
            |
     dim_item_attribute
```

---

## Dimensions

### dim_date
Calendar dimension for time-based analysis.

| Column | Type | Description |
|--------|------|-------------|
| date_id | INTEGER | YYYYMMDD format (e.g., 20260314) |
| full_date | DATE | Calendar date |
| year | INTEGER | 4-digit year |
| quarter | INTEGER | 1-4 |
| month | INTEGER | 1-12 |
| month_name | VARCHAR | January, February, etc. |
| week_of_year | INTEGER | ISO week number |
| day_of_week | INTEGER | 0=Sunday, 6=Saturday |
| day_name | VARCHAR | Monday, Tuesday, etc. |
| day_of_month | INTEGER | 1-31 |
| is_weekend | BOOLEAN | TRUE/FALSE |
| fiscal_year | VARCHAR | FY format (e.g., "2025-26") |

**Grain:** 1 row per calendar day
**Row Count:** ~4,000 (2020-2030)
**Primary Key:** date_id
**Unique:** full_date

**Use Cases:**
- Date filtering in Power BI dashboards
- Fiscal year analysis
- Trend analysis by month, quarter
- Weekday vs weekend comparison

---

### dim_customer
Customer master dimension.

| Column | Type | Description |
|--------|------|-------------|
| customer_key | INTEGER | Surrogate key |
| customer_id | VARCHAR | ERPNext customer name (primary key) |
| customer_name | VARCHAR | Display name |
| customer_type | VARCHAR | Individual, Company, etc. |
| customer_group | VARCHAR | Premium, Regular, Bulk, etc. |
| territory | VARCHAR | Sales region/territory |
| email_id | VARCHAR | Contact email |
| mobile_no | VARCHAR | Phone number |
| credit_limit | NUMERIC(18,6) | Credit limit amount |
| market_segment | VARCHAR | Market classification |
| industry | VARCHAR | Industry classification |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per unique customer
**Row Count:** 34
**Primary Key:** customer_key
**Unique:** customer_id
**Indexes:** customer_id, customer_group, territory

**Use Cases:**
- Customer segmentation
- Territory-level analysis
- Credit limit monitoring
- Customer type breakdowns
- Market segment analysis

---

### dim_item
Product master dimension.

| Column | Type | Description |
|--------|------|-------------|
| item_key | INTEGER | Surrogate key |
| item_id | VARCHAR | ERPNext item name (primary key) |
| item_code | VARCHAR | Item code |
| item_name | VARCHAR | Display name |
| item_group | VARCHAR | Product category |
| brand | VARCHAR | Brand/manufacturer |
| is_stock | BOOLEAN | Stocked item? |
| is_sales | BOOLEAN | Saleable? |
| is_purchase | BOOLEAN | Purchasable? |
| valuation_method | VARCHAR | FIFO, LIFO, Moving Average |
| weight_per_unit | NUMERIC(18,6) | Weight per unit |
| weight_uom | VARCHAR | Weight unit (kg, lb, etc.) |
| stock_uom | VARCHAR | Stock unit (pcs, meters, etc.) |
| purchase_uom | VARCHAR | Purchase unit |
| variant_of | VARCHAR | Parent item (if variant) |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per unique item
**Row Count:** 34,761
**Primary Key:** item_key
**Unique:** item_id
**Indexes:** item_id, item_code, item_group, brand

**Use Cases:**
- Product-level sales analysis
- Item group rollup
- Stock vs non-stock item comparison
- Brand performance
- Variant tracking

---

### dim_item_attribute
Product attributes dimension (long format).

| Column | Type | Description |
|--------|------|-------------|
| attribute_key | INTEGER | Surrogate key |
| item_code | VARCHAR | Links to dim_item.item_code |
| attribute | VARCHAR | Attribute name (COLOUR, SIZE, COMPOSITION, etc.) |
| attribute_value | VARCHAR | Attribute value (NAVY, M, 100% COTTON, etc.) |
| is_numeric | BOOLEAN | Numeric range attribute? |
| from_range | NUMERIC(18,6) | Range start (if numeric) |
| to_range | NUMERIC(18,6) | Range end (if numeric) |
| increment | NUMERIC(18,6) | Range increment (if numeric) |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per item + attribute combination
**Row Count:** 138,830
**Primary Key:** attribute_key
**Indexes:** item_code, attribute, attribute_value, (item_code, attribute)

**Example Data:**
```
item_code  | attribute    | attribute_value
-----------|--------------|------------------
FAB-02912  | COMPOSITION  | 100 % COTTON
FAB-02912  | WIDTH        | 54
FAB-02912  | COLOUR       | GREY/WHITE
PAN-00432  | COLOUR       | OLIVE GREEN
PAN-00432  | LENGTH       | 22
```

**Use Cases:**
- **Power BI slicing:** "Show sales by COLOUR"
- Product attribute breakdowns
- Garment property analysis
- Attribute value comparisons
- Size/color trend analysis

---

### dim_warehouse
Location master dimension.

| Column | Type | Description |
|--------|------|-------------|
| warehouse_key | INTEGER | Surrogate key |
| warehouse_id | VARCHAR | ERPNext warehouse name (primary key) |
| warehouse_name | VARCHAR | Display name |
| parent_warehouse | VARCHAR | Parent warehouse (if sub-warehouse) |
| company | VARCHAR | Company/legal entity |
| city | VARCHAR | City location |
| state | VARCHAR | State/province |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per unique warehouse (leaf nodes only)
**Row Count:** 105
**Primary Key:** warehouse_key
**Unique:** warehouse_id
**Indexes:** warehouse_id, warehouse_name, company

**Use Cases:**
- Location-level inventory analysis
- Warehouse capacity/stock analysis
- Regional breakdown
- Shipping point analysis

---

## Facts

### fact_sales_order_line
Sales order line item facts.

| Column | Type | Description |
|--------|------|-------------|
| fact_key | INTEGER | Surrogate key |
| item_id | VARCHAR | ERPNext line item ID |
| order_id | VARCHAR | ERPNext order ID |
| customer_key | INTEGER | FK → dim_customer |
| item_key | INTEGER | FK → dim_item |
| warehouse_key | INTEGER | FK → dim_warehouse |
| order_date_id | INTEGER | FK → dim_date (posting_date) |
| delivery_date_id | INTEGER | FK → dim_date (delivery_date) |
| status | VARCHAR | Order status (Draft, To Deliver, Completed, etc.) |
| company | VARCHAR | Legal entity |
| territory | VARCHAR | Sales territory |
| qty | NUMERIC(18,6) | Order quantity |
| net_amount | NUMERIC(18,6) | Qty × Rate - Discount |
| amount | NUMERIC(18,6) | Qty × Rate |
| discount_percentage | NUMERIC(18,6) | Discount % |
| gross_amount | NUMERIC(18,6) | Qty × Rate (recalculated) |
| unit_price | NUMERIC(18,6) | Rate per unit |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per sales order line item
**Row Count:** 33,191
**Primary Key:** fact_key
**Foreign Keys:** customer_key, item_key, warehouse_key, order_date_id, delivery_date_id
**Indexes:** customer_key, item_key, warehouse_key, order_date_id, order_id

**Filters Applied:**
- Only submitted orders (docstatus = 1)
- Non-cancelled orders only

**Use Cases:**
- Sales order analysis
- Order pipeline tracking
- Fulfillment monitoring
- Territory-level order analysis
- Delivery date forecasting

---

### fact_sales_invoice_line
Sales invoice line item facts (handles both sales and returns).

| Column | Type | Description |
|--------|------|-------------|
| fact_key | INTEGER | Surrogate key |
| item_id | VARCHAR | ERPNext line item ID |
| invoice_id | VARCHAR | ERPNext invoice ID |
| customer_key | INTEGER | FK → dim_customer |
| item_key | INTEGER | FK → dim_item |
| warehouse_key | INTEGER | FK → dim_warehouse |
| invoice_date_id | INTEGER | FK → dim_date (posting_date) |
| due_date_id | INTEGER | FK → dim_date (due_date) |
| is_return | BOOLEAN | Return transaction? |
| company | VARCHAR | Legal entity |
| territory | VARCHAR | Sales territory |
| qty | NUMERIC(18,6) | Invoice quantity (positive or negative) |
| net_amount | NUMERIC(18,6) | Qty × Rate - Discount |
| amount | NUMERIC(18,6) | Qty × Rate |
| discount_percentage | NUMERIC(18,6) | Discount % |
| gross_amount | NUMERIC(18,6) | Qty × Rate (recalculated) |
| unit_price | NUMERIC(18,6) | Rate per unit |
| signed_net_amount | NUMERIC(18,6) | Net amount (negative if return) |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per sales invoice line item
**Row Count:** 5,724
**Primary Key:** fact_key
**Foreign Keys:** customer_key, item_key, warehouse_key, invoice_date_id, due_date_id
**Indexes:** customer_key, item_key, warehouse_key, invoice_date_id, invoice_id, is_return

**Filters Applied:**
- Only submitted invoices (docstatus = 1)
- Non-cancelled invoices only

**Key Metrics:**
```sql
-- Total Revenue (handles returns automatically)
SELECT SUM(signed_net_amount) FROM fact_sales_invoice_line

-- Sales only (excludes returns)
SELECT SUM(signed_net_amount) FROM fact_sales_invoice_line WHERE is_return = FALSE

-- Returns only
SELECT SUM(signed_net_amount) FROM fact_sales_invoice_line WHERE is_return = TRUE

-- Qty sold (absolute)
SELECT SUM(qty) FROM fact_sales_invoice_line WHERE is_return = FALSE
```

**Use Cases:**
- Revenue analysis
- Sales by customer, item, territory
- Return rate analysis
- Month-over-month revenue trends
- Customer profitability

---

### fact_stock_movement
Inventory transaction facts (stock ledger).

| Column | Type | Description |
|--------|------|-------------|
| fact_key | INTEGER | Surrogate key |
| entry_id | VARCHAR | ERPNext stock ledger entry ID |
| item_key | INTEGER | FK → dim_item |
| warehouse_key | INTEGER | FK → dim_warehouse |
| date_id | INTEGER | FK → dim_date (posting_date) |
| voucher_type | VARCHAR | Receipt, Issue, Transfer, Journal, etc. |
| voucher_no | VARCHAR | Voucher/document number |
| company | VARCHAR | Legal entity |
| project | VARCHAR | Project reference |
| batch_no | VARCHAR | Batch/lot number |
| fiscal_year | VARCHAR | Fiscal year |
| actual_qty | NUMERIC(18,6) | Qty in/out this transaction |
| qty_after_transaction | NUMERIC(18,6) | Inventory balance after transaction |
| incoming_rate | NUMERIC(18,6) | Cost rate (inbound) |
| outgoing_rate | NUMERIC(18,6) | Cost rate (outbound) |
| valuation_rate | NUMERIC(18,6) | Valuation rate used |
| stock_value | NUMERIC(18,6) | Inventory value at this rate |
| stock_value_difference | NUMERIC(18,6) | Value change from transaction |
| movement_type | VARCHAR | IN, OUT, or ZERO |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per stock ledger entry
**Row Count:** 1,260,906
**Primary Key:** fact_key
**Foreign Keys:** item_key, warehouse_key, date_id
**Indexes:** item_key, warehouse_key, date_id, voucher_type, movement_type

**Filters Applied:**
- Non-cancelled entries only (is_cancelled = '0')

**Key Metrics:**
```sql
-- Current stock
SELECT qty_after_transaction
FROM fact_stock_movement
WHERE item_key = X AND warehouse_key = Y
ORDER BY date_id DESC LIMIT 1

-- Stock value by warehouse
SELECT warehouse_key, SUM(stock_value)
FROM fact_stock_movement
WHERE date_id = (SELECT MAX(date_id) FROM fact_stock_movement)
GROUP BY warehouse_key

-- Inbound/outbound by month
SELECT date_id,
       SUM(CASE WHEN movement_type = 'IN' THEN actual_qty ELSE 0 END) as qty_in,
       SUM(CASE WHEN movement_type = 'OUT' THEN actual_qty ELSE 0 END) as qty_out
FROM fact_stock_movement
GROUP BY date_id
```

**Use Cases:**
- Inventory audit trail
- Stock valuation
- Movement analysis by warehouse
- Receipt/Issue tracking
- Period-end reconciliation
- Stock rotation analysis

---

### fact_material_shortage
Operational readiness: Current stock status for all items.

| Column | Type | Description |
|--------|------|-------------|
| item_key | INTEGER | FK → dim_item |
| warehouse_key | INTEGER | FK → dim_warehouse |
| item_code | VARCHAR | Item code |
| item_name | VARCHAR | Item display name |
| item_group | VARCHAR | Product category |
| warehouse | VARCHAR | Warehouse name |
| current_qty | NUMERIC(18,6) | Latest quantity on hand |
| is_shortfall | BOOLEAN | TRUE if qty <= 0 (critical shortage) |
| stock_status | VARCHAR | 'Negative', 'Zero Stock', or 'Available' |
| last_stock_movement_date | DATE | Last transaction date for this item+warehouse |
| is_stock | BOOLEAN | Is this a stocked item? |
| is_sales | BOOLEAN | Is this a saleable item? |
| is_purchase | BOOLEAN | Is this a purchasable item? |
| brand | VARCHAR | Product brand |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per item + warehouse (current stock snapshot)
**Row Count:** Varies with item+warehouse combinations
**Primary Key:** item_key, warehouse_key
**Foreign Keys:** item_key, warehouse_key
**Indexes:** is_shortfall, stock_status, item_code

**Use Cases:**
- Identify items at zero or negative stock blocking operations
- Monitor stock shortages by warehouse
- Prioritize procurement for critical items
- Power BI operational dashboard for stock status

---

### fact_sales_order_readiness
Operational readiness: Sales order fulfillment tracking and gap analysis.

| Column | Type | Description |
|--------|------|-------------|
| fact_key | INTEGER | Surrogate key |
| order_id | VARCHAR | ERPNext sales order ID |
| customer_key | INTEGER | FK → dim_customer |
| customer | VARCHAR | Customer ID |
| customer_name | VARCHAR | Customer name |
| order_date | DATE | Order transaction date |
| order_posted_date | DATE | Order posting date |
| expected_delivery_date | DATE | Committed delivery date |
| delivery_date_id | INTEGER | FK → dim_date |
| order_status | VARCHAR | Current order status |
| fulfillment_status | VARCHAR | 'Closed', 'Overdue', 'Due Today', 'Due This Week', 'Pending' |
| is_overdue | BOOLEAN | TRUE if past delivery date |
| days_past_due | INTEGER | Days overdue (0 if not overdue) |
| days_until_due | INTEGER | Days remaining until due (0 if overdue) |
| qty_ordered | NUMERIC(18,6) | Total quantity ordered |
| line_count | INTEGER | Number of line items in order |
| net_total | NUMERIC(18,6) | Order net total |
| grand_total | NUMERIC(18,6) | Order total with taxes |
| company | VARCHAR | Legal entity |
| territory | VARCHAR | Sales territory |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per sales order
**Row Count:** ~4,500 (varies with order volume)
**Primary Key:** fact_key
**Foreign Keys:** customer_key, delivery_date_id
**Indexes:** customer_key, fulfillment_status, is_overdue, order_id, expected_delivery_date

**Use Cases:**
- Identify overdue deliveries requiring escalation
- Track orders due this week
- Monitor fulfillment progress
- Territory-level delivery performance
- Power BI operational dashboard for order fulfillment

---

### fact_item_master_readiness
Operational readiness: Item master data completeness checks.

| Column | Type | Description |
|--------|------|-------------|
| item_key | INTEGER | FK → dim_item |
| item_code | VARCHAR | Item code |
| item_name | VARCHAR | Item display name |
| item_group | VARCHAR | Product category |
| brand | VARCHAR | Product brand |
| has_item_group | BOOLEAN | Item group assigned? |
| has_brand | BOOLEAN | Brand assigned? |
| has_weight | BOOLEAN | Weight recorded? |
| has_stock_uom | BOOLEAN | Stock UOM defined? |
| has_purchase_uom | BOOLEAN | Purchase UOM defined? |
| is_sales | BOOLEAN | Marked as saleable? |
| is_stock | BOOLEAN | Marked as stocked? |
| is_purchase | BOOLEAN | Marked as purchasable? |
| is_sales_item | BOOLEAN | Is saleable (derived) |
| is_stock_item | BOOLEAN | Is stocked (derived) |
| is_purchase_item | BOOLEAN | Is purchasable (derived) |
| has_recent_sales_activity | BOOLEAN | Appears in recent sales orders? |
| sales_readiness_score | NUMERIC(5,1) | 0-100 score for sales-item completeness |
| stock_readiness_score | NUMERIC(5,1) | 0-100 score for stock-item completeness |
| purchase_readiness_score | NUMERIC(5,1) | 0-100 score for purchase-item completeness |
| readiness_status | VARCHAR | 'COMPLETE' or 'INCOMPLETE' |
| valuation_method | VARCHAR | Valuation method (FIFO, Moving Average, etc.) |
| creation | TIMESTAMP | Item creation date in ERP |
| modified | TIMESTAMP | Last modified date in ERP |
| dw_load_date | TIMESTAMP | Data warehouse load timestamp |

**Grain:** 1 row per item (master data completeness)
**Row Count:** ~36,740 (total items in system)
**Primary Key:** item_key
**Foreign Keys:** item_key
**Indexes:** readiness_status, sales_readiness_score, stock_readiness_score, is_sales, is_stock, has_recent_sales_activity

**Use Cases:**
- Identify items with incomplete master data
- Monitor data quality by item type (sales vs stock vs purchase)
- Find items missing critical attributes (brand, UOM, weight)
- Prioritize data entry work
- Power BI data governance dashboard

---

### fact_work_order_readiness
Operational readiness: Work order production status and job card readiness.

| Column | Type | Description |
|--------|------|-------------|
| fact_key | INTEGER | Primary key |
| work_order_id | VARCHAR | Work order ID |
| item_key | INTEGER | FK → dim_item |
| item_code | VARCHAR | Product code |
| item_name | VARCHAR | Product name |
| bom_no | VARCHAR | Associated BOM ID |
| status | VARCHAR | Work order status |
| planned_qty | NUMERIC(18,6) | Planned quantity to produce |
| produced_qty | NUMERIC(18,6) | Actual quantity produced |
| planned_start_date | DATE | Planned production start |
| planned_end_date | DATE | Planned production end |
| actual_start_date | DATE | Actual production start |
| completion_pct | NUMERIC(5,1) | % of planned qty produced |
| production_status | VARCHAR | 'Not Started', 'In Progress', 'Completed' |
| is_overdue | BOOLEAN | TRUE if past planned end date |
| days_overdue | INTEGER | Days past due (0 if on time) |
| has_job_cards | BOOLEAN | Are job cards created? |
| job_card_count | INTEGER | Number of job cards |
| material_item_count | INTEGER | Number of material lines |
| readiness_flag | VARCHAR | 'MISSING_JOB_CARDS', 'OVERDUE', 'COMPLETED', 'IN_PROGRESS' |
| company | VARCHAR | Legal entity |
| dw_load_date | TIMESTAMP | Load timestamp |

**Grain:** 1 row per work order
**Use Cases:**
- Identify work orders missing job cards (blocking labor tracking)
- Monitor production schedule adherence
- Identify overdue production work
- Production execution dashboard

---

### fact_purchase_readiness
Operational readiness: Purchase order fulfillment and receipt tracking.

| Column | Type | Description |
|--------|------|-------------|
| fact_key | INTEGER | Primary key |
| po_id | VARCHAR | Purchase order ID |
| item_key | INTEGER | FK → dim_item |
| warehouse_key | INTEGER | FK → dim_warehouse |
| supplier | VARCHAR | Supplier name |
| item_code | VARCHAR | Item code |
| item_name | VARCHAR | Item name |
| ordered_qty | NUMERIC(18,6) | Quantity ordered |
| received_qty | NUMERIC(18,6) | Quantity received |
| pending_qty | NUMERIC(18,6) | Qty still pending receipt |
| rate | NUMERIC(18,6) | Unit rate |
| base_rate | NUMERIC(18,6) | Base unit rate |
| amount | NUMERIC(18,6) | Line total amount |
| po_date | DATE | PO creation date |
| po_expected_delivery_date | DATE | PO delivery target |
| po_status | VARCHAR | PO status (Draft, To Receive, etc.) |
| receipt_status | VARCHAR | 'Not Received', 'Partially Received', 'Fully Received' |
| is_overdue | BOOLEAN | TRUE if past expected date |
| days_pending | INTEGER | Days waiting for receipt |
| days_until_due | INTEGER | Days until due (0 if overdue) |
| fulfillment_status | VARCHAR | 'RECEIVED', 'PARTIALLY_RECEIVED', 'PENDING_RECEIPT', 'OVERDUE' |
| company | VARCHAR | Legal entity |
| warehouse | VARCHAR | Receiving warehouse |
| dw_load_date | TIMESTAMP | Load timestamp |

**Grain:** 1 row per PO line item
**Use Cases:**
- Identify items pending receipt blocking production
- Monitor supplier delivery performance
- Track overdue purchase orders
- Procurement dashboard for supply chain visibility

---

## Relationships Summary

### Transactional Facts
| From | To | Join | Cardinality |
|------|----|----|-------------|
| fact_sales_invoice_line | dim_customer | customer_key | Many-to-One |
| fact_sales_invoice_line | dim_item | item_key | Many-to-One |
| fact_sales_invoice_line | dim_warehouse | warehouse_key | Many-to-One |
| fact_sales_invoice_line | dim_date (invoice) | invoice_date_id | Many-to-One |
| fact_sales_invoice_line | dim_date (due) | due_date_id | Many-to-One |
| fact_sales_order_line | dim_customer | customer_key | Many-to-One |
| fact_sales_order_line | dim_item | item_key | Many-to-One |
| fact_sales_order_line | dim_warehouse | warehouse_key | Many-to-One |
| fact_sales_order_line | dim_date (order) | order_date_id | Many-to-One |
| fact_sales_order_line | dim_date (delivery) | delivery_date_id | Many-to-One |
| fact_stock_movement | dim_item | item_key | Many-to-One |
| fact_stock_movement | dim_warehouse | warehouse_key | Many-to-One |
| fact_stock_movement | dim_date | date_id | Many-to-One |

### Operational Readiness Facts (Phase 1)
| From | To | Join | Cardinality |
|------|----|----|-------------|
| fact_material_shortage | dim_item | item_key | Many-to-One |
| fact_material_shortage | dim_warehouse | warehouse_key | Many-to-One |
| fact_sales_order_readiness | dim_customer | customer_key | Many-to-One |
| fact_sales_order_readiness | dim_date | delivery_date_id | Many-to-One |
| fact_item_master_readiness | dim_item | item_key | Many-to-One |

### Manufacturing & Procurement Facts (Phase 2)
| From | To | Join | Cardinality |
|------|----|----|-------------|
| fact_work_order_readiness | dim_item | item_key | Many-to-One |
| fact_purchase_readiness | dim_item | item_key | Many-to-One |
| fact_purchase_readiness | dim_warehouse | warehouse_key | Many-to-One |

### Attribute Dimension
| From | To | Join | Cardinality |
|------|----|----|-------------|
| dim_item_attribute | dim_item | item_code | Many-to-One |

---

## Data Type Standards

| Type | Usage | Example |
|------|-------|---------|
| INTEGER | IDs, keys, counts | customer_key, qty after transaction |
| VARCHAR | Text, codes, names | customer_name, item_code |
| NUMERIC(18,6) | Amounts, rates, quantities | base_net_total, valuation_rate |
| DATE | Date fields | posting_date, due_date |
| TIMESTAMP | Audit timestamps | dw_load_date, modified |
| BOOLEAN | Flags | is_return, is_weekend |

---

## Naming Conventions

| Object | Pattern | Example |
|--------|---------|---------|
| Dimension PK | {table}_key | customer_key |
| Dimension surrogate | dim_{entity} | dim_customer |
| Fact table | fact_{process} | fact_sales_invoice_line |
| Fact measure | {metric} | net_amount, actual_qty |
| Fact FK | {dimension}_key | customer_key |
| Date FK | {event}_date_id | invoice_date_id |
| Flags | is_{attribute} | is_return, is_weekend |

---

## Sample Queries

### Top 10 Customers by Revenue
```sql
SELECT c.customer_name, c.customer_group,
       SUM(f.signed_net_amount) as revenue
FROM fact_sales_invoice_line f
JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE f.is_return = FALSE
GROUP BY c.customer_name, c.customer_group
ORDER BY revenue DESC LIMIT 10;
```

### Sales by Color
```sql
SELECT attr.attribute_value as color,
       SUM(f.qty) as qty_sold,
       SUM(f.signed_net_amount) as revenue
FROM fact_sales_invoice_line f
JOIN dim_item_attribute attr ON f.item_key = attr.item_key
WHERE attr.attribute = 'COLOUR'
GROUP BY attr.attribute_value
ORDER BY revenue DESC;
```

### Current Inventory
```sql
SELECT i.item_name, w.warehouse_name,
       (SELECT qty_after_transaction
        FROM fact_stock_movement sm
        WHERE sm.item_key = f.item_key
          AND sm.warehouse_key = f.warehouse_key
        ORDER BY sm.date_id DESC LIMIT 1) as current_qty
FROM fact_stock_movement f
JOIN dim_item i ON f.item_key = i.item_key
JOIN dim_warehouse w ON f.warehouse_key = w.warehouse_key
WHERE f.date_id = (SELECT MAX(date_id) FROM fact_stock_movement)
GROUP BY i.item_name, w.warehouse_name, f.item_key, f.warehouse_key;
```
