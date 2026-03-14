# ETL Pipeline

## Overview

The ETL pipeline consists of three stages:
1. **Extract** — MariaDB → PostgreSQL raw schema
2. **Transform** — raw → staging (clean and normalize)
3. **Load** — staging → mart (dimensional modeling)

---

## Stage 1: Extract

### Source
- **Database:** MariaDB (ERPNext instance)
- **Connection:** `mysql+pymysql://root:root@localhost/1bd3e0294da19198`
- **Tables:** 11 source tables

### Process
**File:** `src/extract.py`

```python
def extract_table(src_engine, tgt_engine, src_table, tgt_table):
    # 1. Read from MariaDB
    df = pd.read_sql_table(src_table, src_engine)

    # 2. Truncate target
    TRUNCATE TABLE raw.{tgt_table}

    # 3. Write to PostgreSQL in chunks
    df.to_sql(tgt_table, tgt_engine, schema='raw',
              if_exists='append', chunksize=10000)
```

### Tables Extracted

| Source Table | Raw Table | Rows | Chunk Size |
|---|---|---|---|
| tabSales Invoice | erpnext_sales_invoice | 1,482 | 10K |
| tabSales Invoice Item | erpnext_sales_invoice_item | 5,724 | 10K |
| tabSales Order | erpnext_sales_order | 4,574 | 10K |
| tabSales Order Item | erpnext_sales_order_item | 33,191 | 10K |
| tabCustomer | erpnext_customer | 34 | 10K |
| tabItem | erpnext_item | 34,761 | 10K |
| tabWarehouse | erpnext_warehouse | 105 | 10K |
| tabStock Ledger Entry | erpnext_stock_ledger_entry | 1,260,906 | 10K |
| tabItem Attribute | erpnext_item_attribute | 87 | 10K |
| tabItem Attribute Value | erpnext_item_attribute_value | 6,041 | 10K |
| tabItem Variant Attribute | erpnext_item_variant_attribute | 138,830 | 10K |

### Configuration
**File:** `src/config.py`

```python
SOURCE_URL = "mysql+pymysql://root:root@localhost/1bd3e0294da19198"
TARGET_URL = "postgresql://postgres:postgres@localhost/dw_rag"
CHUNK_SIZE = 10000
```

### Execution

```bash
cd src
python extract.py
```

**Output:**
```
============================================================
ERPNext DW Extract: MariaDB → PostgreSQL Raw Layer
============================================================
Extracting tabSales Invoice → raw.erpnext_sales_invoice
✓ tabSales Invoice: 1,482 rows
Extracting tabSales Invoice Item → raw.erpnext_sales_invoice_item
✓ tabSales Invoice Item: 5,724 rows
...
============================================================
Extraction complete!
============================================================
```

### Idempotency
- **Method:** TRUNCATE + INSERT
- **Safe to rerun:** Yes
- **Result:** Complete reload of raw schema

### Performance
- Time: ~2-5 minutes (depends on network and disk)
- Handles large tables (1.26M) via chunking
- No locks on source

---

## Stage 2: Transform (Staging)

### Purpose
- Rename columns to snake_case
- Cast data types (NUMERIC, DATE, BOOLEAN)
- Filter invalid records (docstatus, disabled)
- Add derived fields

### Process
**File:** `sql/staging/01_stg_all.sql`

Each staging table:
```sql
DROP TABLE IF EXISTS staging.stg_sales_invoice CASCADE;
CREATE TABLE staging.stg_sales_invoice AS
SELECT
    name AS invoice_id,
    customer,
    posting_date,
    base_net_total::NUMERIC(18,6) AS net_total,
    CASE WHEN is_return = 1 THEN TRUE ELSE FALSE END AS is_return,
    creation,
    modified
FROM raw.erpnext_sales_invoice
WHERE docstatus = 1;  -- Submitted only
```

### Filters Applied

| Table | Filter | Rationale |
|-------|--------|-----------|
| stg_sales_invoice | docstatus = 1 | Posted invoices only |
| stg_sales_order | docstatus = 1 | Posted orders only |
| stg_customer | disabled = 0 | Active customers only |
| stg_warehouse | is_group = 0 | Leaf warehouses only |
| stg_stock_ledger | is_cancelled = '0' | Valid transactions only |

### Data Type Conversions

| Source | Staging | Reason |
|--------|---------|--------|
| VARCHAR(140) | VARCHAR | Preserve text |
| DECIMAL(18,6) | NUMERIC(18,6) | Maintain precision |
| DATETIME | TIMESTAMP | Preserve timestamp |
| INT(1) | BOOLEAN | Better semantics for flags |
| DATE | DATE | Preserve date type |

### Transformation Rules

#### Rename Columns
```
tabSales Invoice.name                    → stg_sales_invoice.invoice_id
tabSales Invoice.base_net_total         → stg_sales_invoice.net_total
tabSales Invoice Item.parent            → stg_sales_invoice_item.invoice_id
```

#### Normalize Data
```
is_return = 1  → is_return = TRUE
is_return = 0  → is_return = FALSE
disabled = 1   → excluded from stg_customer
is_group = 1   → excluded from stg_warehouse
```

#### Add Derived Fields
```
None added at staging level (kept minimal)
Derived fields added at mart level
```

### Execution

```bash
psql -U postgres -d dw_rag -f sql/staging/01_stg_all.sql
```

**Output:**
```
CREATE TABLE
DROP TABLE
CREATE TABLE
...
```

### Idempotency
- **Method:** DROP + CREATE
- **Safe to rerun:** Yes
- **Cascades:** Drops dependent mart tables

### Performance
- Time: ~30 seconds
- No data loss (filtered records logged implicitly)
- Indexes created after table creation

### Row Count Expectations
```
raw → staging: ~15-20% reduction (filtering submitted + active)
  raw.erpnext_sales_invoice (1,482)
  → stg_sales_invoice (1,482, all are docstatus=1)

raw → staging: Similar reduction rate for other tables
```

---

## Stage 3: Load (Mart)

### Purpose
- Create dimensional model (star schema)
- Add surrogate keys
- Denormalize attributes
- Create indexes for query performance

### Process
**Files:** `sql/mart/01_dim_date.sql` through `sql/mart/08_fact_stock_movement.sql`

#### Dimension Creation (Example: dim_customer)
```sql
DROP TABLE IF EXISTS mart.dim_customer CASCADE;
CREATE TABLE mart.dim_customer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
    customer_id,
    customer_name,
    customer_type,
    customer_group,
    ...
    NOW() AS dw_load_date
FROM staging.stg_customer
ORDER BY customer_id;

ALTER TABLE mart.dim_customer ADD PRIMARY KEY (customer_key);
CREATE UNIQUE INDEX idx_dim_customer_id ON mart.dim_customer(customer_id);
```

#### Fact Creation (Example: fact_sales_invoice_line)
```sql
DROP TABLE IF EXISTS mart.fact_sales_invoice_line CASCADE;
CREATE TABLE mart.fact_sales_invoice_line AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ii.item_id) AS fact_key,
    ii.item_id,
    i.invoice_id,
    dc.customer_key,        -- FK to dim_customer
    di.item_key,            -- FK to dim_item
    dw.warehouse_key,       -- FK to dim_warehouse
    dd.date_id,             -- FK to dim_date
    ii.qty,
    ii.net_amount,
    CASE WHEN i.is_return THEN -1 * ii.net_amount
         ELSE ii.net_amount END AS signed_net_amount,
    NOW() AS dw_load_date
FROM staging.stg_sales_invoice_item ii
INNER JOIN staging.stg_sales_invoice i ON ii.invoice_id = i.invoice_id
LEFT JOIN mart.dim_customer dc ON i.customer = dc.customer_id
LEFT JOIN mart.dim_item di ON ii.item_code = di.item_code
LEFT JOIN mart.dim_warehouse dw ON ii.warehouse = dw.warehouse_id
LEFT JOIN mart.dim_date dd ON i.posting_date = dd.full_date;
```

### Execution Order

1. **Create date dimension first** (all facts depend on it)
   ```bash
   psql -U postgres -d dw_rag -f sql/mart/01_dim_date.sql
   ```

2. **Create other dimensions** (in any order)
   ```bash
   psql -U postgres -d dw_rag -f sql/mart/02_dim_customer.sql
   psql -U postgres -d dw_rag -f sql/mart/03_dim_item.sql
   psql -U postgres -d dw_rag -f sql/mart/04_dim_item_attribute.sql
   psql -U postgres -d dw_rag -f sql/mart/05_dim_warehouse.sql
   ```

3. **Create facts** (depend on dimensions)
   ```bash
   psql -U postgres -d dw_rag -f sql/mart/06_fact_sales_order_line.sql
   psql -U postgres -d dw_rag -f sql/mart/07_fact_sales_invoice_line.sql
   psql -U postgres -d dw_rag -f sql/mart/08_fact_stock_movement.sql
   ```

### Idempotency
- **Method:** DROP + CREATE
- **Safe to rerun:** Yes
- **Cascades:** Each file independent

### Performance
- Time: ~2 minutes (fact tables large)
- Large fact tables: 1.26M stock movements
- Indexes created after table creation

### Surrogate Keys

Generated via `ROW_NUMBER()`:
```sql
ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key
```

**Advantages:**
- No business logic in keys
- Stable (doesn't change if customer ID changes)
- Supports slowly-changing dimensions
- Cleaner join syntax

---

## Complete Pipeline Execution

### One-Shot Script

```bash
# From dw-rag directory

# 1. Extract
python src/extract.py

# 2. Transform (staging)
psql -U postgres -d dw_rag -f sql/staging/01_stg_all.sql

# 3. Load (mart) - dimensions
psql -U postgres -d dw_rag -f sql/mart/01_dim_date.sql
psql -U postgres -d dw_rag -f sql/mart/02_dim_customer.sql
psql -U postgres -d dw_rag -f sql/mart/03_dim_item.sql
psql -U postgres -d dw_rag -f sql/mart/04_dim_item_attribute.sql
psql -U postgres -d dw_rag -f sql/mart/05_dim_warehouse.sql

# 4. Load (mart) - facts
psql -U postgres -d dw_rag -f sql/mart/06_fact_sales_order_line.sql
psql -U postgres -d dw_rag -f sql/mart/07_fact_sales_invoice_line.sql
psql -U postgres -d dw_rag -f sql/mart/08_fact_stock_movement.sql

# 5. Validate
psql -U postgres -d dw_rag -f sql/validation/01_row_counts.sql
```

### Automated Script

Create `run_etl.sh`:
```bash
#!/bin/bash
set -e

echo "Starting ETL Pipeline..."

echo "Step 1: Extract..."
python src/extract.py || exit 1

echo "Step 2: Staging..."
psql -U postgres -d dw_rag -f sql/staging/01_stg_all.sql || exit 1

echo "Step 3: Mart..."
for f in sql/mart/*.sql; do
    echo "  Running $(basename $f)..."
    psql -U postgres -d dw_rag -f "$f" || exit 1
done

echo "Step 4: Validation..."
psql -U postgres -d dw_rag -f sql/validation/01_row_counts.sql

echo "ETL Pipeline Complete!"
```

```bash
chmod +x run_etl.sh
./run_etl.sh
```

### Typical Execution Time

| Stage | Time | Notes |
|-------|------|-------|
| Extract | 2-5 min | Dependent on network, I/O |
| Staging | 30 sec | SQL transformation |
| Dim date | 5 sec | Small, 4K rows |
| Dim customer | <1 sec | 34 rows |
| Dim item | 2 sec | 34K rows |
| Dim item_attribute | 10 sec | 138K rows |
| Dim warehouse | <1 sec | 105 rows |
| Fact sales order | 5 sec | 33K rows + joins |
| Fact sales invoice | 3 sec | 5.7K rows + joins |
| Fact stock movement | 30 sec | 1.26M rows, large |
| Validation | 10 sec | Data quality checks |
| **Total** | **~6-12 min** | Full pipeline |

---

## Error Handling

### Common Issues

#### PostgreSQL Connection Failed
```
Error: could not translate host name "localhost" to address
```
**Fix:**
```bash
# Verify PostgreSQL is running
pg_isready -h localhost -p 5432

# Check connection string in src/config.py
```

#### MariaDB Connection Failed
```
Error: Can't connect to MySQL server on 'localhost'
```
**Fix:**
```bash
# Verify MariaDB is running
mariadb -u root -proot -e "SELECT VERSION();"

# Check source database exists
mariadb -u root -proot -e "SHOW DATABASES;" | grep 1bd3e0294da19198
```

#### Duplicate Key Error
```
ERROR: duplicate key value violates unique constraint
```
**Fix:**
- Stage was not TRUNCATE'd properly
- Run: `TRUNCATE TABLE raw.{table} CASCADE;`
- Re-extract

#### Table Not Found
```
ERROR: relation "raw.erpnext_sales_invoice" does not exist
```
**Fix:**
- Raw schema doesn't exist
- Run: `psql -U postgres -d dw_rag -f sql/raw/01_create_raw_schema.sql`

### Recovery

If pipeline fails partway:
```sql
-- Check last successful load
SELECT MAX(dw_load_date) FROM mart.fact_sales_invoice_line;

-- Rerun from specific stage
-- E.g., if facts failed, rerun facts only:
psql -U postgres -d dw_rag -f sql/mart/06_fact_sales_order_line.sql
```

---

## Monitoring

### Row Count Checks

```sql
-- Expected row counts
SELECT 'raw' as layer, 'sales_invoice', COUNT(*) FROM raw.erpnext_sales_invoice
UNION ALL
SELECT 'staging', 'sales_invoice', COUNT(*) FROM staging.stg_sales_invoice
UNION ALL
SELECT 'mart', 'fact_sales_invoice', COUNT(*) FROM mart.fact_sales_invoice_line;
```

### Table Sizes

```sql
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname IN ('raw', 'staging', 'mart')
ORDER BY pg_total_relation_size DESC;
```

### Validate Load Dates

```sql
SELECT 'dim_customer' as table_name, MAX(dw_load_date) FROM mart.dim_customer
UNION ALL
SELECT 'fact_sales_invoice_line', MAX(dw_load_date) FROM mart.fact_sales_invoice_line
UNION ALL
SELECT 'fact_stock_movement', MAX(dw_load_date) FROM mart.fact_stock_movement;
```

### Check for Orphan Foreign Keys

```sql
-- Customers in facts but not in dim
SELECT COUNT(DISTINCT f.customer_key)
FROM mart.fact_sales_invoice_line f
WHERE f.customer_key NOT IN (SELECT customer_key FROM mart.dim_customer);
-- Should return 0

-- Same for items, warehouses, dates
```

---

## Incremental Loading (Future)

Currently all pipelines are full-reload (TRUNCATE + INSERT).

For incremental loading, use:
```sql
-- Track modified timestamp
SELECT * FROM raw.erpnext_sales_invoice
WHERE modified > (SELECT MAX(modified) FROM staging.stg_sales_invoice);
```

Requires:
- Tracking table (last_load_date)
- Handling of deletes (use soft deletes)
- Upsert logic (INSERT ... ON CONFLICT)
