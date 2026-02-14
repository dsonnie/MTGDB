"""
File: MTGStaging.py
Project: MTG Card Database
Description: Generates code to create the staging table from the flat csv file
Author: Dave Sonnie
Copyright (c) 2026 Dave Sonnie
"""

# This Python script prints the psql command to create the staging table based on the header in the csv file
# This script does not run the command, only produces the necessary text to do so; 
# Use or adjust as necessary based on the specific implementation
import csv

csv_file = 'cards.csv'
table_name = 'staging_cards'

with open(csv_file, newline="", encoding="utf-8") as f: 
    reader = csv.reader(f)
    headers = next(reader)

columns = ',\n'.join(
    f'"{h.strip()}" TEXT' for h in headers
)

create_sql = f'CREATE TABLE {table_name} ({columns});';
print(create_sql)

# Psql command to copy cards to the staging table
# \copy staging_cards FROM 'cards.csv' WITH (FORMAT csv, HEADER true);