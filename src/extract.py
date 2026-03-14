"""
Extract ERPNext tables from MariaDB source to PostgreSQL raw schema.

Usage:
    python src/extract.py
"""

import pandas as pd
from sqlalchemy import create_engine, inspect, text
import logging
from config import SOURCE_URL, TARGET_URL, CHUNK_SIZE

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Tables to extract: (source_table, target_raw_table)
EXTRACT_TABLES = [
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
]


def extract_table(src_engine, tgt_engine, src_table, tgt_table, chunk_size=CHUNK_SIZE):
    """
    Extract a single table from MariaDB to PostgreSQL raw schema.
    Idempotent: truncates target before loading.
    """
    try:
        logger.info(f"Extracting {src_table} → raw.{tgt_table}")

        # Read from source
        df = pd.read_sql_table(src_table, src_engine)

        # Truncate target table (idempotent)
        with tgt_engine.connect() as conn:
            conn.execute(text(f"TRUNCATE TABLE raw.{tgt_table}"))
            conn.commit()

        # Write to target in chunks
        df.to_sql(tgt_table, tgt_engine, schema="raw", if_exists="append", index=False, chunksize=chunk_size)

        row_count = len(df)
        logger.info(f"✓ {src_table}: {row_count:,} rows")

    except Exception as e:
        logger.error(f"✗ Failed to extract {src_table}: {str(e)}")
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
