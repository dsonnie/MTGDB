"""
File: 01_staging_prep.py
Project: MTG Card Database
Description: Generates code to create the staging table from the flat csv file
Author: Dave Sonnie
Copyright (c) 2026 Dave Sonnie
"""

# This Python script prints the psql command to create the staging table based on the header in the csv file
# This script does not run the command, only produces the necessary text to do so; 
# Use or adjust as necessary based on the specific implementation
import csv
import os
import psycopg
from pathlib import Path
from dotenv import load_dotenv

load_dotenv() # For .env file

BASE_DIR = Path(__file__).resolve().parent
CSV_FILE_NAME = 'cards.csv'
CSV_FILE_PATH = BASE_DIR / CSV_FILE_NAME
TABLE_NAME = 'staging_cards'

DB_CONFIG = {
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT"),
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}

# ---------- Query Build ----------
# Build the staging table creation query from the csv headers
with open(CSV_FILE_PATH, newline="", encoding="utf-8") as f: 
    reader = csv.reader(f)
    headers = next(reader)

columns = ',\n'.join(
    f'"{h.strip()}" TEXT' for h in headers
)

# Build query
create_sql = f'CREATE TABLE IF NOT EXISTS {TABLE_NAME} ({columns});';

# ---------- EXECUTE ----------
with psycopg.connect(**DB_CONFIG) as conn:
    with conn.cursor() as cur:

        # Cleanup old staging table if it exists
        cur.execute(f'DROP TABLE IF EXISTS {TABLE_NAME} CASCADE;')
        # Create table
        cur.execute(create_sql)

        # Bulk load CSV
        with open(CSV_FILE_PATH, "r", encoding="utf-8") as f:
            with cur.copy(f"COPY {TABLE_NAME} FROM STDIN WITH CSV HEADER") as copy:
                copy.write(f.read())

    conn.commit()

print("Table created and data loaded successfully.")

# Psql command to copy cards to the staging table
# \copy staging_cards FROM 'cards.csv' WITH (FORMAT csv, HEADER true);