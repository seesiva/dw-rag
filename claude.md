# Project: ERPNext AI-Ready Data Warehouse

This document acts as the **AI operating contract for the repository**.

AI assistants should follow the rules, architecture, and constraints defined here when generating SQL, documentation, or code.

This repository implements a lightweight analytical data warehouse for ERPNext.

Primary objectives:

1. Build a PostgreSQL warehouse for analytics and reporting.
2. Enable Power BI dashboards through a clean star-schema mart layer.
3. Prepare the warehouse for AI-driven querying, RAG, and intelligent agents.

Architecture:

ERPNext MySQL → Python extraction → PostgreSQL warehouse

Warehouse schemas:

raw → staging → mart → semantic

Consumers:

Power BI → mart  
AI systems → semantic + mart

---

# Domain Context

This warehouse is being designed for a **garment company**.

Item master may include:

- finished garments
- raw materials
- trims and accessories
- packaging items
- service items
- semi-finished items

For sales analytics, priority should be given to:

- produced items
- finished goods
- sales-relevant SKUs

The item dimension should retain broad item master coverage while including classification attributes to distinguish:

- finished goods
- raw materials
- trims/accessories
- service items
- packaging items
- sales-relevant items
- production-relevant items

Garment-specific attributes should be captured where available:

- style
- color
- size
- brand
- category
- season
- fabric/material
- variant relationships

Mart design must support Power BI slicing by garment business dimensions and later AI-driven semantic interpretation.

---

# Technology Constraints

Preferred stack

- Python
- SQLAlchemy
- pandas
- PostgreSQL
- MySQL (ERPNext source)
- lightweight ETL scripts

Avoid introducing unless explicitly requested

- Spark
- Kafka
- Airflow
- dbt
- heavy orchestration frameworks

Goal:

**simple, maintainable architecture suitable for a small engineering team.**

---
# Sales Lifecycle Modeling

For this warehouse, both Sales Order and Sales Invoice are important.

Sales Order represents customer demand and order commitment.

Sales Invoice represents realized revenue.

The mart layer should support both:

- mart.fact_sales_order_line
- mart.fact_sales_invoice_line

This is especially important for garment analytics where demand, order backlog, fulfillment, and realized sales must be analyzed separately.

Item attributes are important and should be modeled in dim_item where available.

Relevant garment attributes may include:
- style
- color
- size
- season
- brand
- fabric/material
- collection
- product category

# Source System Mapping (ERPNext)

ERPNext uses a document-based relational schema where many tables follow a parent-child pattern.

Example:

Sales Invoice (parent)

tabSales Invoice

Sales Invoice Item (child)

tabSales Invoice Item

Mapping rules:

Parent tables represent business documents.

Child tables represent line-level records.
o
Warehouse modeling rules:

Parent tables map to staging tables.

Child tables usually drive fact tables.

Example mapping:

ERPNext Source → Warehouse

tabSales Invoice → staging.stg_sales_invoice  
tabSales Invoice Item → staging.stg_sales_invoice_item

Fact table creation:

mart.fact_sales_invoice_line should primarily use:

staging.stg_sales_invoice_item  
joined with staging.stg_sales_invoice

Filtering rules:

Analytics should use records where:

docstatus = 1 (submitted)

unless explicitly specified otherwise.

---

# Continuous Documentation Requirement

The system must remain well documented as development progresses.

When new components are created or modified, documentation must be updated accordingly.

Documentation should be generated or updated for:

- warehouse schemas
- table definitions
- data models
- ETL pipelines
- business metrics
- semantic metadata
- architecture changes

Documentation must be stored in:

docs/

---

# Documentation Files

The following documentation files must be maintained.

docs/architecture.md  
High-level system architecture

docs/data-model.md  
Fact tables, dimension tables, and relationships

docs/etl-pipeline.md  
Extraction and transformation logic

docs/semantic-layer.md  
AI metadata and semantic catalog design

docs/powerbi-model.md  
Guidelines for Power BI consumption

docs/data-dictionary.md  
Business meaning of tables and columns

---

# Documentation Generation Guidelines

When creating or modifying tables:

- update the data dictionary
- document table grain
- document measures and dimensions

When adding metrics:

- update semantic.metric_catalog
- update data dictionary

When adding ETL logic:

- update ETL pipeline documentation

Documentation should remain synchronized with code.

---

# Repo Structure

dw-rag

├── claude.md  
├── README.md  

├── docs/  
│   ├── architecture.md  
│   ├── data-model.md  
│   ├── etl-pipeline.md  
│   ├── semantic-layer.md  
│   ├── powerbi-model.md  
│   └── data-dictionary.md  

├── sql/  
│   ├── raw/  
│   ├── staging/  
│   ├── mart/  
│   └── semantic/  

├── sql/validation/

├── src/  
│   ├── extract/  
│   ├── transform/  
│   └── load/

---

# AI Collaboration Roles

AI assistants should operate using the following role perspectives depending on the task.

## Data Architect

Responsible for:

- overall warehouse architecture
- schema layering
- technology constraints
- system integration

## Data Engineer

Responsible for:

- extraction from ERPNext MySQL
- ETL pipeline design
- idempotent loading
- raw and staging tables

## Data Modeler

Responsible for:

- fact and dimension modeling
- star schema design
- dimension attributes
- analytical modeling

## BI Engineer

Responsible for:

- Power BI consumption models
- star schema simplicity
- dashboard optimization

## AI / Semantic Engineer

Responsible for:

- semantic metadata
- metric catalog
- AI-ready metadata
- RAG and text-to-SQL readiness

---

# Warehouse Architecture

## Raw Layer

Schema: raw

Purpose:

Store extracted ERPNext data with minimal transformation.

Characteristics:

- mirrors ERPNext tables
- preserves column names
- safe for reloading

Example tables:

raw.erpnext_sales_invoice  
raw.erpnext_sales_invoice_item  
raw.erpnext_customer  
raw.erpnext_item  
raw.erpnext_warehouse  
raw.erpnext_stock_ledger_entry

---

## Staging Layer

Schema: staging

Purpose:

Clean and normalize raw data.

Responsibilities:

- rename columns
- normalize datatypes
- handle nulls
- remove invalid rows
- derive standardized fields

Example tables:

staging.stg_sales_invoice  
staging.stg_sales_invoice_item  
staging.stg_customer  
staging.stg_item  
staging.stg_stock_ledger

---

## Mart Layer

Schema: mart

Purpose:

Provide a **Power BI optimized star schema**.

Dimensions:

mart.dim_customer  
mart.dim_item  
mart.dim_warehouse  
mart.dim_date

Facts:

mart.fact_sales_invoice_line  
mart.fact_stock_movement

Facts must contain:

- foreign keys
- numeric measures
- timestamps

Dimensions must contain:

- descriptive attributes
- hierarchies
- grouping attributes

Mart tables must be stable and trusted.

---

# Surrogate Key Policy

Dimensions should use surrogate keys.

Example:

mart.dim_customer

customer_key (surrogate key)  
customer_id (ERPNext key)

Benefits:

- stable joins
- improved performance
- independence from ERP changes

Facts reference surrogate keys where available.

Example:

fact_sales_invoice_line

customer_key  
item_key  
warehouse_key  
date_key

---

# Data Refresh Strategy

Initial loads may be full loads.

Future pipelines should support incremental refresh.

Incremental extraction may rely on:

- modified
- posting_date
- creation

Extraction process:

1. extract new or modified rows
2. load into raw
3. rebuild staging
4. rebuild mart

For MVP:

Full refresh pipelines are acceptable.

---

# SQL Generation Contract

AI-generated SQL must follow these rules.

General rules

- PostgreSQL syntax
- fully qualified schema names
- readable SQL
- prefer CTEs
- avoid SELECT *

Layer rules

Raw layer

- preserve source structure
- minimal transformation

Staging layer

- rename columns
- normalize datatypes
- standardize fields

Mart layer

- star schema
- facts reference dimensions
- use staging as input

Semantic layer

- metadata only
- no duplication of facts

Join rules

- respect table grain
- avoid duplicate rows
- highlight grain-changing joins

Grain rules

AI must determine table grain before generating SQL.

Examples:

fact_sales_invoice_line = one row per invoice line

dim_item = one row per item

ERPNext rules

- use docstatus = 1 for analytics
- handle returns explicitly
- preserve source identifiers

---

# Data Validation Rules

ETL pipelines should include validation checks.

Examples:

Row count validation

source vs staging counts

Duplicate detection

no duplicate invoice line IDs

Foreign key validation

facts should not contain null dimension keys

Measure validation

sales totals should match ERPNext totals.

Validation queries should be stored in:

sql/validation/

---

# Power BI Consumption Model

Power BI dashboards must connect only to:

mart schema.

Benefits:

- simple star schema
- performant joins
- consistent metrics

Do not expose raw or staging to BI tools.

Typical queries supported:

- monthly sales trends
- top customers
- best selling items
- warehouse inventory movement

---

# Naming Conventions

Tables

raw.erpnext_<table_name>

staging.stg_<entity>

mart.dim_<entity>  
mart.fact_<process>

Examples

mart.dim_customer  
mart.dim_item  
mart.fact_sales_invoice_line

---

# AI Readiness

Warehouse must support AI use cases.

Examples:

- RAG pipelines
- natural language analytics
- AI agents
- text-to-SQL
- automated insights

AI systems should never query raw tables.

Instead:

AI interprets semantic metadata  
AI queries mart tables

---

# Semantic Layer

Schema: semantic

Purpose:

Provide business meaning and metadata for AI systems.

Core tables:

semantic.table_catalog  
semantic.column_catalog  
semantic.metric_catalog  
semantic.join_catalog  
semantic.business_rule_catalog

---

# Semantic Metadata Requirements

Each table must include:

- business description
- grain
- refresh frequency
- owner

Each column must include:

- business meaning
- synonyms
- example values

Each metric must include:

- definition
- formula
- source tables
- caveats

Example metric

Net Sales

Definition:

Sum of base_net_amount from mart.fact_sales_invoice_line.

---

# RAG Readiness

Semantic metadata must be convertible to embedding-ready text.

Example semantic chunk

Table: mart.fact_sales_invoice_line  
Description: one row per ERPNext sales invoice line item  
Measures: quantity, base_net_amount

These chunks may later be embedded into a vector store.

---

# AI Query Safety

AI-generated SQL must follow rules

- query mart schema only
- use approved joins
- use certified metrics
- avoid raw tables

AI queries must remain explainable.

---

# AI Usage Scope

AI assists with:

- SQL generation
- data modeling
- documentation
- semantic metadata
- validation queries

AI should not introduce new infrastructure tools unless requested.

---

# Development Workflow

Developers perform:

- schema creation
- table inspection
- validation
- data checks

AI assists with:

- complex SQL
- schema modeling
- semantic metadata
- documentation

AI augments engineering work.

---

# Development Philosophy

Prioritize:

- clarity
- reproducibility
- maintainability
- explainability

Avoid unnecessary complexity.