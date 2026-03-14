# Documentation Index

Complete documentation for the ERPNext Sales Analytics Data Warehouse.

---

## Quick Navigation

| Document | Purpose | Audience |
|----------|---------|----------|
| [architecture.md](architecture.md) | Warehouse design, layers, data flow, idempotency | Architects, ETL developers |
| [data-model.md](data-model.md) | Dimensional model, tables, relationships | Data analysts, BI developers |
| [etl-pipeline.md](etl-pipeline.md) | Extraction, transformation, loading processes | ETL developers, data engineers |
| [powerbi-model.md](powerbi-model.md) | Power BI connection, DAX measures, dashboards | BI/Tableau developers |
| [data-dictionary.md](data-dictionary.md) | Complete column definitions and meanings | All users, reference |

---

## Start Here

### For Setup & Execution
→ See [../README.md](../README.md) (Quick start guide)

### For Understanding the Design
1. Start with [architecture.md](architecture.md) — understand the 3-layer pipeline
2. Then [data-model.md](data-model.md) — understand star schema and relationships
3. Reference [data-dictionary.md](data-dictionary.md) as needed

### For Building ETL
→ [etl-pipeline.md](etl-pipeline.md) — extraction, transformation, loading processes

### For Power BI Development
→ [powerbi-model.md](powerbi-model.md) — connections, measures, dashboard recommendations

---

## Document Summaries

### architecture.md
**17 pages | Core Design Document**

Explains:
- 3-layer warehouse architecture (raw → staging → mart)
- Data flow: MariaDB extraction → PostgreSQL transformation
- Idempotency & rerunability
- Key design decisions (surrogate keys, submitted records, attributes, returns)
- Data quality validation
- Performance considerations
- Security & access control
- Maintenance & monitoring
- Disaster recovery

**Read this first to understand the big picture.**

---

### data-model.md
**20 pages | Data Structure Reference**

Defines:
- Star schema diagram
- 5 Dimension tables:
  - dim_date (calendar, 4K rows)
  - dim_customer (customer master, 34 rows)
  - dim_item (product master, 34.7K rows)
  - dim_item_attribute (product attributes, 138K rows)
  - dim_warehouse (location master, 105 rows)
- 3 Fact tables:
  - fact_sales_order_line (orders, 33K rows)
  - fact_sales_invoice_line (invoices, 5.7K rows)
  - fact_stock_movement (inventory, 1.26M rows)
- Relationships & cardinality
- Data type standards
- Naming conventions
- Sample queries

**Use this as primary reference for table/column definitions.**

---

### etl-pipeline.md
**18 pages | Process Documentation**

Details:
- Stage 1: Extract (MariaDB → raw schema)
  - 11 source tables
  - Chunking strategy (10K rows)
  - Idempotent TRUNCATE+INSERT
- Stage 2: Transform (raw → staging)
  - Filtering (docstatus=1, active records)
  - Rename & type casting
  - Transformation rules
- Stage 3: Load (staging → mart)
  - Dimensional modeling
  - Surrogate key generation
  - Index creation
- Execution order & timing
- Error handling & recovery
- Monitoring queries
- Incremental loading (future)

**Follow this for running the pipeline.**

---

### powerbi-model.md
**18 pages | BI Integration Guide**

Covers:
- PostgreSQL connection setup
- Tables to import (dimensions + facts)
- Relationships & cardinality
- Data type formatting
- 18+ DAX measures (sales, orders, inventory, customer)
- Hierarchies (date, product, customer)
- 5 dashboard page recommendations
- Sample queries for reference
- Performance optimization tips
- Troubleshooting
- Row-level security (RLS)
- Refresh scheduling & monitoring

**Use this to set up Power BI dashboards.**

---

### data-dictionary.md
**22 pages | Complete Column Reference**

Lists:
- All 5 dimensions with every column defined
- All 3 facts with every column defined
- Column type, business meaning, examples
- Filters & business rules applied
- Key metrics & calculation patterns
- Glossary of terms
- Common SQL patterns

**Reference this when building queries or dashboards.**

---

## Common Questions

### "How do I execute the ETL?"
→ [../README.md](../README.md) + [etl-pipeline.md](etl-pipeline.md#complete-pipeline-execution)

### "What columns are in fact_sales_invoice_line?"
→ [data-dictionary.md](data-dictionary.md#fact_sales_invoice_line)

### "How do I connect Power BI?"
→ [powerbi-model.md](powerbi-model.md#connection-setup)

### "What's the business key for customers?"
→ [data-model.md](data-model.md#dim_customer) or [data-dictionary.md](data-dictionary.md#dim_customer)

### "How do I calculate current inventory?"
→ [data-dictionary.md](data-dictionary.md#current-inventory-per-itemwarehouse)

### "What's signed_net_amount?"
→ [data-model.md](data-model.md#fact_sales_invoice_line) or [data-dictionary.md](data-dictionary.md#signed_net_amount)

### "How do I handle returns?"
→ [data-model.md](data-model.md#fact_sales_invoice_line) - see "is_return" and "signed_net_amount"

### "What DAX measures are available?"
→ [powerbi-model.md](powerbi-model.md#measures-dax)

---

## For Different Roles

### Data Warehouse Architect
1. [architecture.md](architecture.md) — complete understanding
2. [data-model.md](data-model.md) — validate design
3. [etl-pipeline.md](etl-pipeline.md) — review extraction approach

### ETL Developer / Data Engineer
1. [etl-pipeline.md](etl-pipeline.md) — execution & monitoring
2. [data-model.md](data-model.md) — understand target schema
3. [data-dictionary.md](data-dictionary.md) — column definitions

### BI Developer / Power BI Developer
1. [powerbi-model.md](powerbi-model.md) — setup & measures
2. [data-model.md](data-model.md) — relationships & hierarchies
3. [data-dictionary.md](data-dictionary.md) — metric definitions

### SQL Analyst / Report Writer
1. [data-dictionary.md](data-dictionary.md) — column reference
2. [data-model.md](data-model.md) — table relationships
3. [etl-pipeline.md](etl-pipeline.md#monitoring) — row count expectations

### Business Analyst / Stakeholder
1. [../README.md](../README.md) — overview & capabilities
2. [powerbi-model.md](powerbi-model.md#recommended-dashboard-pages) — dashboard examples
3. [data-dictionary.md](data-dictionary.md#glossary) — terminology

---

## Key Concepts

### The 3-Layer Architecture
```
raw → staging → mart
```
- **raw:** Direct extracts, unchanged
- **staging:** Cleaned, normalized, filtered
- **mart:** Star schema, optimized for analytics

See [architecture.md](architecture.md#layer-definitions)

### Star Schema
```
                    dim_date
                       |
dim_customer -----fact_sales-----dim_warehouse
      |          _invoice_line        |
      └──────────────────────────────┘
              └─ dim_item
```
See [data-model.md](data-model.md)

### Surrogate Keys
- Every dimension has a _key column (customer_key, item_key)
- Facts reference these keys, not the business keys
- Supports future slowly-changing dimensions

See [architecture.md](architecture.md#1-surrogate-keys)

### Return Handling
- Invoices include both sales AND returns
- `is_return` flag identifies returns
- `signed_net_amount` = negative for returns, positive for sales
- `SUM(signed_net_amount)` = accurate net revenue

See [data-model.md](data-model.md#fact_sales_invoice_line)

### Item Attributes
- One row per item + attribute combo (138K rows)
- Enables Power BI slicing: "Show sales by COLOUR"
- Long format: (item_code, attribute, attribute_value)

See [data-model.md](data-model.md#dim_item_attribute)

---

## File Locations

```
dw-rag/
├── README.md                    Quick start guide
├── WAREHOUSE_DESIGN.md          Design overview
├── claude.md                    Project charter
├── BUILD_SUMMARY.txt            Build summary
├── docs/                        (THIS FOLDER)
│   ├── README.md                This file
│   ├── architecture.md          Warehouse design & layers
│   ├── data-model.md            Star schema & tables
│   ├── etl-pipeline.md          Extraction & transformation
│   ├── powerbi-model.md         BI integration
│   └── data-dictionary.md       Column reference
├── src/
│   ├── config.py                DB configuration
│   └── extract.py               ETL extraction
└── sql/
    ├── raw/                     Raw schema creation
    ├── staging/                 Staging transformations
    ├── mart/                    Mart dimensions & facts
    └── validation/              Data quality checks
```

---

## Quick Reference

### Tables & Row Counts
| Table | Grain | Rows | Reference |
|-------|-------|------|-----------|
| dim_date | 1 day | 4K | [data-model.md](data-model.md#dim_date) |
| dim_customer | 1 customer | 34 | [data-model.md](data-model.md#dim_customer) |
| dim_item | 1 item | 34.7K | [data-model.md](data-model.md#dim_item) |
| dim_item_attribute | 1 item + attr | 138K | [data-model.md](data-model.md#dim_item_attribute) |
| dim_warehouse | 1 warehouse | 105 | [data-model.md](data-model.md#dim_warehouse) |
| fact_sales_order_line | 1 order line | 33K | [data-model.md](data-model.md#fact_sales_order_line) |
| fact_sales_invoice_line | 1 invoice line | 5.7K | [data-model.md](data-model.md#fact_sales_invoice_line) |
| fact_stock_movement | 1 ledger entry | 1.26M | [data-model.md](data-model.md#fact_stock_movement) |

### Key Columns by Table
| Column | Table | Reference |
|--------|-------|-----------|
| customer_key | dim_customer | [data-dictionary.md](data-dictionary.md#dim_customer) |
| item_key | dim_item | [data-dictionary.md](data-dictionary.md#dim_item) |
| warehouse_key | dim_warehouse | [data-dictionary.md](data-dictionary.md#dim_warehouse) |
| date_id | dim_date | [data-dictionary.md](data-dictionary.md#dim_date) |
| signed_net_amount | fact_sales_invoice_line | [data-dictionary.md](data-dictionary.md#signed_net_amount) |
| is_return | fact_sales_invoice_line | [data-dictionary.md](data-dictionary.md#is_return) |

---

## Version History

- **v1.0** (2026-03-14): Initial build
  - 5 dimensions, 3 facts, ~1.5M rows
  - Item attributes for garment analysis
  - Return handling with signed amounts
  - Ready for Power BI

---

## Support

For questions:
1. Check relevant documentation (see Quick Navigation above)
2. Search [data-dictionary.md](data-dictionary.md) for column definitions
3. See [etl-pipeline.md](etl-pipeline.md#troubleshooting) for common issues
4. Reference SQL examples in [data-dictionary.md](data-dictionary.md#common-calculation-patterns)
