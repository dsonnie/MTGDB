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

working_dir = 'Postgres' + os.sep + 'Postgres-MTG'
csv_file = 'cards.csv'
table_name = 'staging_cards'

# Docker Postgres
DATABASE_URL = "postgresql://mtg_admin@localhost:5432/mtg_db"

with open(csv_file, newline="", encoding="utf-8") as f: 
    reader = csv.reader(f)
    headers = next(reader)

columns = ',\n'.join(
    f'"{h.strip()}" TEXT' for h in headers
)

# Build query
create_sql = f"""
CREATE TABLE IF NOT EXISTS {table_name} (
{columns}
);
"""

#create_sql = f'CREATE TABLE IF NOT EXISTS {table_name} ({columns});';
#print(create_sql)


# ---------- EXECUTE ----------
with psycopg.connect(DATABASE_URL) as conn:
    with conn.cursor() as cur:

        # Cleanup old staging table if it exists
        cur.execute(f'DROP TABLE IF EXISTS {table_name} CASCADE;')
        # Create table
        cur.execute(create_sql)

        # Bulk load CSV
        with open(csv_file, "r", encoding="utf-8") as f:
            with cur.copy(f"COPY {table_name} FROM STDIN WITH CSV HEADER") as copy:
                copy.write(f.read())

    conn.commit()

print("Table created and data loaded successfully.")

# Psql command to copy cards to the staging table
# \copy staging_cards FROM 'cards.csv' WITH (FORMAT csv, HEADER true);