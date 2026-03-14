# Warehouse Architecture

## Overview

The ERPNext Sales Analytics Warehouse is a 3-layer PostgreSQL analytical system designed to support Power BI dashboards, SQL analytics, and future AI systems.

```
ERPNext MySQL (MariaDB)
    ↓ (Daily extraction)
raw schema (PostgreSQL)
    ↓ (Staging transformations)
staging schema
    ↓ (Dimensional modeling)
mart schema (Star Schema)
    ↓
Power BI / Analytics / AI Systems
```

---

## Layer Definitions

### Raw Layer
- **Schema:** `raw`
- **Purpose:** Direct extracts from ERPNext with minimal transformation
- **Characteristics:**
  - Mirrors source table structure
  - Preserves ERPNext column names
  - Safe for complete reload
  - Idempotent: TRUNCATE + INSERT
- **Tables:** 11 source tables (erpnext_sales_invoice, erpnext_customer, etc.)
- **Grain:** 1:1 with source
- **Row Count:** ~1.5M total

### Staging Layer
- **Schema:** `staging`
- **Purpose:** Clean, normalize, and standardize raw data
- **Characteristics:**
  - Snake_case column naming
  - Proper data types (NUMERIC, DATE, BOOLEAN)
  - Filters applied (docstatus=1, disabled=0, is_group=0)
  - Remove cancelled/invalid records
  - Derive standardized fields
- **Tables:** 9 staging tables (stg_sales_invoice, stg_customer, etc.)
- **Grain:** Same as raw (1:1)
- **Row Count:** ~1.5M (filtered)

### Mart Layer (Star Schema)
- **Schema:** `mart`
- **Purpose:** Analytical model optimized for Power BI and SQL analytics
- **Structure:**
  - **Dimensions:** Customer, Item, Warehouse, Date, Item Attributes
  - **Facts:** Sales Orders, Sales Invoices, Stock Movements
- **Characteristics:**
  - Surrogate keys (customer_key, item_key, etc.)
  - Denormalized attributes
  - Strategic indexes on FK and dates
  - Idempotent: DROP + CREATE
- **Tables:** 8 tables (5 dimensions, 3 facts)
- **Grain:** Dimension = 1:1 per entity; Fact = 1 per transaction
- **Row Count:** ~1.5M across all tables

---

## Data Flow

### Extraction (MariaDB → raw)
```
Python (pandas)
├─ read_sql_table("tabSales Invoice") → DataFrame
├─ TRUNCATE raw.erpnext_sales_invoice
└─ DataFrame.to_sql(schema="raw", if_exists="append", chunksize=10000)

Handles large tables (1.26M+ rows) in 10K-row batches
```

### Transformation (raw → staging)
```
SQL CTEs
├─ Filter: docstatus=1, disabled=0, is_group=0
├─ Rename: Column names → snake_case
├─ Cast: DECIMAL(18,6), DATE, BOOLEAN
├─ Coalesce: Handle NULLs
└─ Denormalize: Add derived fields

Example:
  raw.erpnext_sales_invoice
    ├─ Filter: docstatus = 1
    ├─ Rename: name → invoice_id
    ├─ Cast: base_net_total::NUMERIC(18,6)
    └─ → staging.stg_sales_invoice
```

### Dimensional Modeling (staging → mart)
```
Star Schema Joins:
  ┌─ fact_sales_invoice_line
  ├─ Joins: dim_customer, dim_item, dim_warehouse, dim_date
  └─ Creates: customer_key, item_key, warehouse_key, invoice_date_id

  ┌─ fact_sales_order_line
  ├─ Same joins as above
  └─ Tracks: order status, delivery date

  ┌─ fact_stock_movement
  ├─ Joins: dim_item, dim_warehouse, dim_date
  └─ Tracks: qty_after_transaction, valuation_rate, movement_type
```

---

## Idempotency & Rerunability

### Raw Layer (Extraction)
```sql
TRUNCATE TABLE raw.erpnext_sales_invoice;
INSERT INTO raw.erpnext_sales_invoice (...)
SELECT * FROM mariadb_source;
```
**Result:** Safe to rerun. Clears and reloads.

### Staging Layer (Transformation)
```sql
DROP TABLE IF EXISTS staging.stg_sales_invoice CASCADE;
CREATE TABLE staging.stg_sales_invoice AS
SELECT ... FROM raw.erpnext_sales_invoice WHERE docstatus = 1;
```
**Result:** Safe to rerun. Drops and recreates.

### Mart Layer (Dimensional Modeling)
```sql
DROP TABLE IF EXISTS mart.dim_customer CASCADE;
CREATE TABLE mart.dim_customer AS
SELECT ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key, ...
FROM staging.stg_customer;
```
**Result:** Safe to rerun. Drops and recreates.

---

## Key Architectural Decisions

### 1. Surrogate Keys
- Dimensions use `_key` columns (customer_key, item_key, warehouse_key)
- Auto-incremented by ROW_NUMBER()
- Advantages:
  - Avoids multi-column joins
  - Supports future slowly-changing dimensions
  - Cleaner fact table structure

### 2. Submitted Records Only
- All facts filter to `docstatus = 1`
- ERPNext document statuses:
  - 0 = Draft
  - 1 = Submitted
  - 2 = Cancelled
- Ensures facts = posted transactions only

### 3. Item Attributes in Long Format
- One row per item + attribute combination
- 138,830 rows (item_code, attribute, attribute_value)
- Enables Power BI slicers dynamically
- Alternative (wide format with separate columns) would require schema changes per attribute

### 4. Return Handling
- `is_return` flag in fact_sales_invoice_line
- `signed_net_amount` = negative for returns, positive for sales
- Simplifies revenue calculation: `SUM(signed_net_amount) = net revenue`

### 5. Fiscal Year (Apr–Mar)
- India garment industry standard
- Calculated: `if month >= 4 then year else year-1`
- Enables "FY 2025-26" analysis

### 6. Strategic Indexes
- FK columns: fact.customer_key, fact.item_key, fact.warehouse_key
- Date columns: dim_date.full_date, fact.invoice_date_id
- Composite: dim_item_attribute(item_code, attribute)
- Supports large table scans (1.26M stock ledger)

---

## Data Quality & Validation

### Filters Applied at Staging
```
stg_sales_invoice:  docstatus = 1 (submitted only)
stg_sales_order:    docstatus = 1
stg_customer:       disabled = 0 (active customers)
stg_warehouse:      is_group = 0 (leaf nodes only)
stg_stock_ledger:   is_cancelled = '0'
```

### Foreign Key Integrity
```sql
-- No orphan keys in facts
SELECT COUNT(DISTINCT customer_key) FROM fact_sales_invoice_line
WHERE customer_key IS NOT NULL

-- Should be <= COUNT(*) FROM dim_customer
```

### Validation Queries (sql/validation/01_row_counts.sql)
- Row count reconciliation: raw → staging → mart
- FK integrity checks
- Submitted record filter verification
- Sample data inspection

---

## Performance Considerations

### Indexing Strategy
```
Raw Layer:
  - Minimal indexes (for quick reloads)

Staging Layer:
  - FK indexes (parent references)
  - Date indexes (posting_date)

Mart Layer:
  - PK: fact tables
  - FK: all dimension references
  - Date: invoice_date_id, order_date_id
  - Composite: item_code + attribute
```

### Large Table Handling
- Stock Ledger: 1.26M rows
- Extract in 10K-row chunks (pandas chunksize)
- Use TRUNCATE (faster than DELETE)
- Indexes created after INSERT

### Query Optimization
- Star join typically faster than snowflake
- Surrogate keys enable bitmap index scans
- Materialized dimensions support Power BI caching
- Consider aggregate tables for common queries (future)

---

## Security & Access

### PostgreSQL Roles (Recommended)
```sql
-- Read-only analytics user
CREATE ROLE analytics_user WITH LOGIN PASSWORD 'xxx';
GRANT USAGE ON SCHEMA mart TO analytics_user;
GRANT SELECT ON ALL TABLES IN SCHEMA mart TO analytics_user;

-- ETL process user (with write)
CREATE ROLE etl_process WITH LOGIN PASSWORD 'xxx';
GRANT USAGE ON SCHEMA raw, staging, mart TO etl_process;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw, staging, mart TO etl_process;
```

### Data Access
- Power BI: Read-only access to `mart` schema
- Analytics queries: Read-only access to `mart` and `staging`
- ETL processes: Full write access to all schemas
- Raw schema: Rarely accessed directly (data dictionary only)

---

## Maintenance & Monitoring

### Daily Operations
1. Run extraction (src/extract.py)
2. Build staging
3. Build mart
4. Run validation
5. Notify if validation fails

### Weekly
- Review row count trends
- Check disk usage
- Monitor query performance

### Monthly
- Archive old fact data (optional, for very large systems)
- Reindex staging and mart
- Update data dictionary

### Monitoring Queries
```sql
-- Check table sizes
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname IN ('raw', 'staging', 'mart')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check last load date
SELECT MAX(dw_load_date) FROM mart.dim_customer;

-- Check fact row counts
SELECT 'sales_order' as fact, COUNT(*) FROM mart.fact_sales_order_line
UNION ALL
SELECT 'sales_invoice', COUNT(*) FROM mart.fact_sales_invoice_line
UNION ALL
SELECT 'stock_movement', COUNT(*) FROM mart.fact_stock_movement;
```

---

## Disaster Recovery

### Backup Strategy
```bash
# Backup mart schema only (fast, no raw/staging)
pg_dump -U postgres dw_rag -n mart > dw_rag_mart_$(date +%Y%m%d).sql

# Backup all schemas
pg_dump -U postgres dw_rag > dw_rag_full_$(date +%Y%m%d).sql
```

### Recovery
```bash
# Restore from backup
psql -U postgres dw_rag < dw_rag_full_20260314.sql

# Or re-extract from source
python src/extract.py && psql -U postgres -d dw_rag -f sql/staging/01_stg_all.sql && ...
```

---

## Future Enhancements

1. **Incremental Loading**
   - Track `modified` timestamp
   - Load only changed records
   - Requires CDC or change tracking

2. **Slowly Changing Dimensions (SCD)**
   - Type 2: Track historical versions
   - Add effective_date, end_date, is_current

3. **Semantic Layer**
   - `semantic` schema with business rules
   - Table/column catalogs for AI systems
   - Metric definitions

4. **Real-time Sync**
   - Replace batch ETL with CDC
   - Event-driven updates
   - Requires Kafka/Debezium setup

5. **Aggregate Mart**
   - Pre-aggregated fact tables
   - Monthly/quarterly summaries
   - Improves Power BI dashboard performance
