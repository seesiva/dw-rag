# ERPNext Sales Analytics Data Warehouse

A lightweight analytical data warehouse for ERPNext built with Python, SQL, and PostgreSQL.

**Warehouse Schemas:**
- `raw` — extracted ERPNext tables (direct from source)
- `staging` — cleaned and normalized data
- `mart` — star schema optimized for Power BI and analytics

---

## Architecture

```
ERPNext MySQL (MariaDB)
    ↓
raw schema (PostgreSQL)
    ↓
staging schema (cleaned)
    ↓
mart schema (star schema)
    ↓
Power BI / Analytics Dashboards
```

---

## Setup

### 1. Create PostgreSQL Target Database

```bash
# Create the warehouse database
createdb dw_rag
```

### 2. Install Python Dependencies

```bash
pip install sqlalchemy pandas pymysql psycopg2-binary
```

### 3. Verify Source Database Access

```bash
mariadb -u root -proot 1bd3e0294da19198 -e "SELECT COUNT(*) FROM tabSales Invoice;"
```

---

## Execution

### Full Pipeline (Extract + Transform + Validate)

```bash
# 1. Extract raw data from MariaDB to PostgreSQL
cd src
python extract.py

# 2. Build staging layer (cleaned data)
psql -U postgres -d dw_rag -f ../sql/staging/01_stg_all.sql

# 3. Build mart dimensions
psql -U postgres -d dw_rag -f ../sql/mart/01_dim_date.sql
psql -U postgres -d dw_rag -f ../sql/mart/02_dim_customer.sql
psql -U postgres -d dw_rag -f ../sql/mart/03_dim_item.sql
psql -U postgres -d dw_rag -f ../sql/mart/04_dim_item_attribute.sql
psql -U postgres -d dw_rag -f ../sql/mart/05_dim_warehouse.sql

# 4. Build mart facts
psql -U postgres -d dw_rag -f ../sql/mart/06_fact_sales_order_line.sql
psql -U postgres -d dw_rag -f ../sql/mart/07_fact_sales_invoice_line.sql
psql -U postgres -d dw_rag -f ../sql/mart/08_fact_stock_movement.sql

# 5. Validate data quality
psql -U postgres -d dw_rag -f ../sql/validation/01_row_counts.sql
```

### Run All at Once

```bash
# From the dw-rag directory
python src/extract.py && \
psql -U postgres -d dw_rag -f sql/staging/01_stg_all.sql && \
psql -U postgres -d dw_rag -f sql/mart/*.sql && \
psql -U postgres -d dw_rag -f sql/validation/01_row_counts.sql
```

---

## Warehouse Schema

### Dimensions

| Table | Grain | Rows | Purpose |
|-------|-------|------|---------|
| `dim_date` | One per calendar day | ~4,000 | Date hierarchy (year, month, week, day) |
| `dim_customer` | One per customer | 34 | Customer master with group, territory |
| `dim_item` | One per item | 34,761 | Product master with group, brand |
| `dim_item_attribute` | One per item+attribute combo | 138,830 | Item attributes (color, size, composition) |
| `dim_warehouse` | One per warehouse | 105 | Location master |

### Facts

| Table | Grain | Rows | Purpose |
|-------|-------|------|---------|
| `fact_sales_order_line` | One per order line | 33,191 | Sales order analytics |
| `fact_sales_invoice_line` | One per invoice line | 5,724 | Sales invoice analytics, handles returns |
| `fact_stock_movement` | One per inventory transaction | 1,260,906 | Stock movement audit trail |

---

## Key Metrics

### Sales Order Analysis
```sql
-- Monthly sales by customer
SELECT
    c.customer_name,
    d.month_name,
    SUM(f.qty) AS total_qty,
    SUM(f.net_amount) AS total_value
FROM mart.fact_sales_order_line f
JOIN mart.dim_customer c ON f.customer_key = c.customer_key
JOIN mart.dim_date d ON f.order_date_id = d.date_id
GROUP BY c.customer_name, d.month_name
ORDER BY d.month_name, total_value DESC;
```

### Sales Invoice Analysis
```sql
-- Revenue by item group (excluding returns)
SELECT
    i.item_group,
    SUM(CASE WHEN f.is_return THEN f.net_amount ELSE f.net_amount END) AS net_revenue,
    SUM(f.qty) AS qty_sold
FROM mart.fact_sales_invoice_line f
JOIN mart.dim_item i ON f.item_key = i.item_key
WHERE f.is_return = FALSE
GROUP BY i.item_group
ORDER BY net_revenue DESC;
```

### Inventory Analysis
```sql
-- Current stock by item and warehouse
SELECT
    i.item_name,
    w.warehouse_name,
    (SELECT qty_after_transaction
     FROM mart.fact_stock_movement sm2
     WHERE sm2.item_key = f.item_key
       AND sm2.warehouse_key = f.warehouse_key
     ORDER BY sm2.date_id DESC
     LIMIT 1) AS current_qty
FROM mart.fact_stock_movement f
JOIN mart.dim_item i ON f.item_key = i.item_key
JOIN mart.dim_warehouse w ON f.warehouse_key = w.warehouse_key
GROUP BY i.item_name, w.warehouse_name, f.item_key, f.warehouse_key;
```

---

## Source Tables Extracted

| ERPNext Table | Raw Table | Rows | Purpose |
|---|---|---|---|
| tabSales Invoice | erpnext_sales_invoice | 1,482 | Invoice headers |
| tabSales Invoice Item | erpnext_sales_invoice_item | 5,724 | Invoice line items |
| tabSales Order | erpnext_sales_order | 4,574 | Order headers |
| tabSales Order Item | erpnext_sales_order_item | 33,191 | Order line items |
| tabCustomer | erpnext_customer | 34 | Customer master |
| tabItem | erpnext_item | 34,761 | Product master |
| tabWarehouse | erpnext_warehouse | 105 | Location master |
| tabStock Ledger Entry | erpnext_stock_ledger_entry | 1,260,906 | Stock transactions |
| tabItem Attribute | erpnext_item_attribute | 87 | Attribute definitions |
| tabItem Attribute Value | erpnext_item_attribute_value | 6,041 | Attribute values |
| tabItem Variant Attribute | erpnext_item_variant_attribute | 138,830 | Item attribute assignments |

---

## Data Integrity Rules

- **Submitted records only:** All staging tables filter to `docstatus=1` (submitted ERPNext documents)
- **Active entities only:** Customers with `disabled=0`, warehouses with `is_group=0`
- **Numeric casting:** All amounts/quantities cast to `NUMERIC(18,6)` for precision
- **Idempotency:** All pipelines use TRUNCATE+INSERT (safe to rerun)
- **Dimensional integrity:** Fact tables use surrogate keys from dimension tables

---

## Power BI Connection

Connect Power BI to the `mart` schema:

1. **Data Source:** PostgreSQL
   - Server: localhost
   - Database: dw_rag
   - Schema: mart

2. **Tables to Import:**
   - dim_customer, dim_item, dim_warehouse, dim_date
   - fact_sales_invoice_line, fact_sales_order_line, fact_stock_movement
   - dim_item_attribute (for slicing by color, size, etc.)

3. **Relationships to Create:**
   - fact_sales_invoice_line → dim_customer (customer_key)
   - fact_sales_invoice_line → dim_item (item_key)
   - fact_sales_invoice_line → dim_warehouse (warehouse_key)
   - fact_sales_invoice_line → dim_date (invoice_date_id)
   - fact_stock_movement → dim_item (item_key)
   - fact_stock_movement → dim_warehouse (warehouse_key)
   - dim_item_attribute → dim_item (item_code)

---

## Development Notes

- **Extract method:** pandas `read_sql_table` + `to_sql` with chunking
- **Large tables:** Stock Ledger (1.26M rows) extracted in 10K-row chunks
- **Staging transformations:** SQL CTEs with star-join logic
- **Mart design:** Surrogate keys (item_key, customer_key, etc.) for dimensional consistency
- **Indices:** Strategic indexes on foreign keys and date fields for query performance

---

## Troubleshooting

**Issue: PostgreSQL connection refused**
```bash
# Check PostgreSQL is running
pg_isready -h localhost -p 5432

# Verify credentials in src/config.py
```

**Issue: MariaDB access denied**
```bash
# Verify source database credentials
mariadb -u root -proot 1bd3e0294da19198 -e "SELECT VERSION();"
```

**Issue: TRUNCATE fails on large tables**
```bash
# Increase work_mem in PostgreSQL config
ALTER DATABASE dw_rag SET work_mem = '256MB';
```

---

## References

- [CLAUDE.md](./claude.md) — Project architecture specification
- [ERPNext Documentation](https://docs.erpnext.com)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Power BI Documentation](https://learn.microsoft.com/power-bi/)
