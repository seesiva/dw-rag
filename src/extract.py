"""
Extract ERPNext tables from MariaDB source to PostgreSQL raw schema.

Usage:
    python src/extract.py
"""

import pandas as pd
from sqlalchemy import create_engine, inspect, text
import logging
import sys
from config import SOURCE_URL, TARGET_URL, CHUNK_SIZE

# Fix encoding for Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Tables to extract: (source_table, target_raw_table)
EXTRACT_TABLES = [
    # Sales & Inventory (Phase 1)
    ("tabSales Invoice", "erpnext_sales_invoice"),
    ("tabSales Invoice Item", "erpnext_sales_invoice_item"),
    ("tabSales Order", "erpnext_sales_order"),
    ("tabSales Order Item", "erpnext_sales_order_item"),
    ("tabCustomer", "erpnext_customer"),
    ("tabItem", "erpnext_item"),
    ("tabWarehouse", "erpnext_warehouse"),
    ("tabStock Ledger Entry", "erpnext_stock_ledger_entry"),
    ("tabItem Attribute", "erpnext_item_attribute"),
    ("tabItem Attribute Value", "erpnext_item_attribute_value"),
    ("tabItem Variant Attribute", "erpnext_item_variant_attribute"),
    # Manufacturing & Procurement (Phase 2)
    ("tabBOM", "erpnext_bom"),
    ("tabWork Order", "erpnext_work_order"),
    ("tabWork Order Item", "erpnext_work_order_item"),
    ("tabJob Card", "erpnext_job_card"),
    ("tabPurchase Order", "erpnext_purchase_order"),
    ("tabPurchase Order Item", "erpnext_purchase_order_item"),
    ("tabMaterial Request", "erpnext_material_request"),
    ("tabMaterial Request Item", "erpnext_material_request_item"),
]


def extract_table(src_engine, tgt_engine, src_table, tgt_table, chunk_size=CHUNK_SIZE):
    """
    Extract a single table from MariaDB to PostgreSQL raw schema.
    Idempotent: truncates target before loading.
    Uses if_exists='replace' to handle schema mismatches.
    """
    try:
        logger.info(f"Extracting {src_table} → raw.{tgt_table}")

        # Read from source using SQL query (handles case-insensitive table names)
        query = f"SELECT * FROM `{src_table}`"
        df = pd.read_sql(query, src_engine)

        # Clean text columns - replace problematic characters
        for col in df.select_dtypes(include=['object']).columns:
            try:
                # Replace BOM and problematic characters
                df[col] = df[col].apply(lambda x: str(x).replace('\ufeff', '').replace('\u202f', ' ') if pd.notna(x) else x)
            except:
                pass

        # Drop target table and recreate (handles schema mismatches)
        with tgt_engine.connect() as conn:
            conn.execute(text(f"DROP TABLE IF EXISTS raw.{tgt_table} CASCADE"))
            conn.commit()

        # Write to target with auto schema creation
        df.to_sql(tgt_table, tgt_engine, schema="raw", if_exists="replace", index=False, chunksize=chunk_size)

        row_count = len(df)
        logger.info(f"OK {src_table}: {row_count:,} rows")

    except Exception as e:
        logger.error(f"ERROR {src_table}: {str(e)[:100]}")
        raise


def create_raw_schema(tgt_engine):
    """Create raw schema in PostgreSQL if it doesn't exist."""
    with tgt_engine.connect() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))
        conn.commit()
        logger.info("✓ Raw schema created/verified")


def main():
    """Main extraction pipeline."""
    logger.info("=" * 60)
    logger.info("ERPNext DW Extract: MariaDB → PostgreSQL Raw Layer")
    logger.info("=" * 60)

    # Create engines
    src_engine = create_engine(SOURCE_URL, echo=False)
    tgt_engine = create_engine(TARGET_URL, echo=False)

    # Ensure schemas exist
    create_raw_schema(tgt_engine)

    # Extract tables
    for src_table, tgt_table in EXTRACT_TABLES:
        extract_table(src_engine, tgt_engine, src_table, tgt_table)

    logger.info("=" * 60)
    logger.info("Extraction complete!")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
