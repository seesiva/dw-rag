# Power BI Model

## Connection Setup

### Data Source Configuration

**Type:** PostgreSQL

**Connection String:**
```
Server: localhost
Database: dw_rag
User: postgres
Password: postgres
Port: 5432
```

**Direct Query vs Import:**
- **Import (Recommended):** Better performance, smaller dashboards
- **Direct Query:** Always fresh data, slower queries on large tables

### Authentication

For production:
```sql
-- Create read-only analytics user
CREATE ROLE powerbi_user WITH LOGIN PASSWORD 'secure_password';
GRANT USAGE ON SCHEMA mart TO powerbi_user;
GRANT SELECT ON ALL TABLES IN SCHEMA mart TO powerbi_user;
```

---

## Tables to Import

### Dimensions

| Table | Row Count | Purpose | Import Size |
|-------|-----------|---------|-------------|
| dim_date | ~4,000 | Calendar, time hierarchy | <1 MB |
| dim_customer | 34 | Customer attributes | <10 KB |
| dim_item | 34,761 | Product attributes | ~5 MB |
| dim_warehouse | 105 | Location attributes | <100 KB |
| dim_item_attribute | 138,830 | Product slicers | ~20 MB |

### Facts

| Table | Row Count | Purpose | Import Size |
|-------|-----------|---------|-------------|
| fact_sales_invoice_line | 5,724 | Sales facts | ~2 MB |
| fact_sales_order_line | 33,191 | Order facts | ~10 MB |
| fact_stock_movement | 1,260,906 | Stock facts | ~150 MB |

**Total Import Size:** ~190 MB (manageable)

---

## Relationships

### Auto-Detected Relationships

Power BI will automatically detect these relationships when importing tables:

```
fact_sales_invoice_line ──→ dim_customer (customer_key)
                         ──→ dim_item (item_key)
                         ──→ dim_warehouse (warehouse_key)
                         ──→ dim_date (invoice_date_id)

fact_sales_order_line    ──→ dim_customer (customer_key)
                         ──→ dim_item (item_key)
                         ──→ dim_warehouse (warehouse_key)
                         ──→ dim_date (order_date_id)

fact_stock_movement      ──→ dim_item (item_key)
                         ──→ dim_warehouse (warehouse_key)
                         ──→ dim_date (date_id)

dim_item_attribute       ──→ dim_item (item_code)
```

### Manual Relationships to Verify

After import, verify:

| From | To | Cardinality | Active |
|------|----|----|--------|
| fact_sales_invoice_line.customer_key | dim_customer.customer_key | Many-to-One | Yes |
| fact_sales_invoice_line.item_key | dim_item.item_key | Many-to-One | Yes |
| fact_sales_invoice_line.warehouse_key | dim_warehouse.warehouse_key | Many-to-One | Yes |
| fact_sales_invoice_line.invoice_date_id | dim_date.date_id | Many-to-One | Yes |
| fact_sales_order_line.customer_key | dim_customer.customer_key | Many-to-One | Yes |
| fact_sales_order_line.item_key | dim_item.item_key | Many-to-One | Yes |
| fact_stock_movement.item_key | dim_item.item_key | Many-to-One | Yes |
| fact_stock_movement.warehouse_key | dim_warehouse.warehouse_key | Many-to-One | Yes |
| dim_item_attribute.item_code | dim_item.item_code | Many-to-One | No |

---

## Data Types & Formatting

### Configure in Power BI

After importing, set data types:

| Column | Type | Format | Category |
|--------|------|--------|----------|
| date_id | Whole Number | - | - |
| full_date | Date | M/d/yyyy | - |
| year | Whole Number | - | - |
| month | Whole Number | - | - |
| qty | Decimal Number | 0.00 | - |
| net_amount | Currency | Currency | - |
| signed_net_amount | Currency | Currency | - |
| stock_value | Currency | Currency | - |
| customer_key | Whole Number | - | - |
| item_key | Whole Number | - | - |
| warehouse_key | Whole Number | - | - |

---

## Measures (DAX)

Create these calculated measures in Power BI for consistency.

### Sales Metrics

```dax
-- Total Revenue (Sales only, excludes returns)
Revenue_Sales =
CALCULATE(
    SUM(fact_sales_invoice_line[signed_net_amount]),
    fact_sales_invoice_line[is_return] = FALSE()
)

-- Total Return Value
Revenue_Returns =
CALCULATE(
    SUM(fact_sales_invoice_line[signed_net_amount]),
    fact_sales_invoice_line[is_return] = TRUE()
)

-- Net Revenue (Sales - Returns)
Revenue_Net =
SUM(fact_sales_invoice_line[signed_net_amount])

-- Total Quantity Sold
Qty_Sold =
CALCULATE(
    SUM(fact_sales_invoice_line[qty]),
    fact_sales_invoice_line[is_return] = FALSE()
)

-- Average Order Value
AOV =
DIVIDE(
    [Revenue_Sales],
    DISTINCTCOUNT(fact_sales_invoice_line[invoice_id])
)

-- Revenue by Invoice
Revenue_Per_Invoice =
DIVIDE(
    [Revenue_Net],
    DISTINCTCOUNT(fact_sales_invoice_line[invoice_id])
)
```

### Order Metrics

```dax
-- Total Order Value
Order_Value =
SUM(fact_sales_order_line[net_amount])

-- Total Order Quantity
Order_Qty =
SUM(fact_sales_order_line[qty])

-- Order Count
Orders =
DISTINCTCOUNT(fact_sales_order_line[order_id])

-- Avg Items per Order
Items_Per_Order =
DIVIDE(
    COUNTROWS(fact_sales_order_line),
    [Orders]
)
```

### Inventory Metrics

```dax
-- Current Stock (Latest per Item/Warehouse)
Current_Stock =
MAXX(
    FILTER(
        fact_stock_movement,
        fact_stock_movement[date_id] =
        CALCULATE(MAX(fact_stock_movement[date_id]))
    ),
    fact_stock_movement[qty_after_transaction]
)

-- Stock Value
Stock_Value =
MAXX(
    FILTER(
        fact_stock_movement,
        fact_stock_movement[date_id] =
        CALCULATE(MAX(fact_stock_movement[date_id]))
    ),
    fact_stock_movement[stock_value]
)

-- Total Inbound Qty
Inbound_Qty =
CALCULATE(
    SUM(fact_stock_movement[actual_qty]),
    fact_stock_movement[movement_type] = "IN"
)

-- Total Outbound Qty
Outbound_Qty =
CALCULATE(
    SUM(fact_stock_movement[actual_qty]),
    fact_stock_movement[movement_type] = "OUT"
)

-- Stock Turnover (Outbound / Avg Stock)
Stock_Turnover =
DIVIDE(
    [Outbound_Qty],
    AVERAGE(fact_stock_movement[qty_after_transaction])
)
```

### Customer Metrics

```dax
-- Customer Count
Customers =
DISTINCTCOUNT(fact_sales_invoice_line[customer_key])

-- Revenue per Customer
Revenue_Per_Customer =
DIVIDE(
    [Revenue_Net],
    [Customers]
)

-- Active Customers (with sales)
Active_Customers =
DISTINCTCOUNT(fact_sales_invoice_line[customer_key])
```

---

## Hierarchies

Create hierarchies for drill-down analysis:

### Date Hierarchy
```
Fiscal Year
├─ Quarter
├─ Month
└─ Week
```

**Set up in Power BI:**
1. Select dim_date
2. Right-click → New Hierarchy
3. Add: Year → Month → Week → Day

### Product Hierarchy
```
Item Group
├─ Brand
└─ Item
```

**Set up in Power BI:**
1. Select dim_item
2. Right-click → New Hierarchy
3. Add: Item Group → Brand → Item Name

### Customer Hierarchy
```
Territory
├─ Customer Group
└─ Customer
```

**Set up in Power BI:**
1. Select dim_customer
2. Right-click → New Hierarchy
3. Add: Territory → Customer Group → Customer Name

---

## Recommended Dashboard Pages

### 1. Sales Overview
**Visuals:**
- Revenue KPI card (vs prior period)
- Orders KPI card
- Qty Sold KPI card
- Revenue trend (line chart, by month)
- Revenue by customer group (column chart)
- Top 10 customers (table)
- Return rate % (KPI card)

**Slicers:**
- Date range (dim_date.full_date)
- Territory
- Customer Group

### 2. Product Analysis
**Visuals:**
- Revenue by item group (pie chart)
- Revenue by brand (bar chart)
- Top 20 items by revenue (table)
- Sales by color (dim_item_attribute[COLOUR])
- Sales by composition (dim_item_attribute[COMPOSITION])
- Sales by size (dim_item_attribute[SIZE])
- Item trend (line chart)

**Slicers:**
- Item Group
- Brand
- Attribute (COLOUR, COMPOSITION, etc.)

### 3. Inventory
**Visuals:**
- Total Stock Value KPI
- Current Stock by Warehouse (clustered bar)
- Stock Movement Trend (area chart)
- Stock Inbound vs Outbound (combo chart)
- Inventory by Item Group (table)
- Stock Turnover by Item (scatter)

**Slicers:**
- Warehouse
- Item Group
- Date Range

### 4. Customer Segmentation
**Visuals:**
- Customer count by group (donut chart)
- Revenue by customer (scatter, size = qty)
- Top customers (matrix: customer × month)
- Customer growth trend (line chart)
- Territory performance (map, if lat/long available)

**Slicers:**
- Territory
- Customer Group

### 5. Detailed Transactions
**Visuals:**
- Sales invoice detail (table: invoice_id, customer, qty, amount, date)
- Order detail (table: order_id, customer, qty, amount, status)
- Stock movement (table: item, warehouse, qty, type, date)

**Slicers:**
- Date range
- Customer
- Item
- Warehouse

---

## Sample Dashboard Queries (for reference)

### Revenue Trend (Monthly)
```sql
SELECT
    d.year,
    d.month_name,
    SUM(f.signed_net_amount) as revenue,
    COUNT(DISTINCT f.invoice_id) as invoices
FROM fact_sales_invoice_line f
JOIN dim_date d ON f.invoice_date_id = d.date_id
WHERE f.is_return = FALSE
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;
```

### Top 10 Items by Revenue
```sql
SELECT
    i.item_name,
    i.item_group,
    SUM(f.qty) as qty_sold,
    SUM(f.signed_net_amount) as revenue
FROM fact_sales_invoice_line f
JOIN dim_item i ON f.item_key = i.item_key
WHERE f.is_return = FALSE
GROUP BY i.item_name, i.item_group
ORDER BY revenue DESC
LIMIT 10;
```

### Sales by Color
```sql
SELECT
    a.attribute_value as color,
    SUM(f.qty) as qty_sold,
    SUM(f.signed_net_amount) as revenue
FROM fact_sales_invoice_line f
JOIN dim_item_attribute a ON f.item_key = a.item_key
WHERE a.attribute = 'COLOUR'
    AND f.is_return = FALSE
GROUP BY a.attribute_value
ORDER BY revenue DESC;
```

---

## Performance Tips

1. **Import Strategy:** Import all dimensions and facts (total ~190 MB)
2. **Aggregations:** Create aggregations for slow queries:
   - By month/territory
   - By item group/warehouse
3. **Slicers:** Use standard slicers (not cascading) for simplicity
4. **Drill-through:** Enable drill-through from summary to detail
5. **Bookmarks:** Save common filter combinations as bookmarks
6. **Query Folding:** Filter early (in SQL) to reduce data volume

---

## Troubleshooting

### Slow Dashboard
- Check data refresh time: Monitor → Refresh History
- Reduce time range in slicers
- Use aggregations for large fact tables
- Consider moving to DirectQuery for stock movement

### Incorrect Totals
- Verify relationships are active
- Check for hidden columns
- Validate measure formula (use CALCULATE for context)

### Missing Data
- Check filter context in Power BI
- Verify null handling in measures
- Ensure fact FK join dim on correct key

### Slow Refresh
- Optimize PostgreSQL query (EXPLAIN ANALYZE)
- Reduce fact table scope (e.g., last 2 years only)
- Use incremental refresh if available

---

## Security

### Row-Level Security (RLS)

To restrict data by territory:

```dax
[Territory] = USERNAME()
```

Apply to dim_customer table.

### Column-Level Security

Hide sensitive columns:
- credit_limit (Finance only)
- cost details (Admin only)

### Connection Security

Use encrypted connections:
```
Server=localhost
Port=5432
Encrypted=true
```

---

## Maintenance

### Refresh Schedule
- **Recommended:** Daily at off-peak hours (e.g., 2 AM)
- **Alternative:** Real-time with DirectQuery (slower)

### Monitor Refresh
- Set up email alerts for failed refreshes
- Track refresh duration trends
- Adjust schedule if consistently exceeds SLA

### Update Model
- When warehouse schema changes
- Add new measures/hierarchies quarterly
- Archive old dashboards when new versions ready
