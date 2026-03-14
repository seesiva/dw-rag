"""
Database connection configuration for ERPNext DW pipeline.
"""

# Source: ERPNext MySQL backup restored to MariaDB
SOURCE_URL = "mysql+pymysql://root:root@localhost/1bd3e0294da19198"

# Target: PostgreSQL warehouse
TARGET_URL = "postgresql://postgres:postgres@localhost/dw_rag"

# ETL Configuration
CHUNK_SIZE = 10000  # Rows per batch for large table extraction
ECHO_SQL = False    # Set to True to see all SQL statements
