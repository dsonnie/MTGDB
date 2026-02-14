# MTG Card Database (PostgreSQL)

A normalized PostgreSQL database project that models Magic: The Gathering card data, with a focus on relational design, ETL workflow, and performance-aware schema structure. This project demonstrates staging-table ingestion, bridge tables, constraint design, and stored procedures for reusable lookup/insert logic.

## Goals

- Design a fully normalized relational schema for MTG card data
- Implement staging → transform → production ETL flow
- Decompose complex attributes (such as mana costs) into relational components
- Use bridge tables for many-to-many relationships
- Apply keys, constraints, and indexes appropriately
- Demonstrate database engineering practices suitable for junior DBA / data roles

## Features

- PostgreSQL schema with normalized core entities
- Staging table for raw CSV ingestion
- Bridge tables for multi-valued relationships (types, subtypes, mana pips)
- Stored functions for **get-or-insert** patterns
- Bulk CSV loading via `psql \copy`
- Constraint-driven deduplication and referential integrity
- Indexes on alternate keys and lookup columns

## Example Schema Areas

- Cards
- Card types and subtypes
- Mana costs and mana pips
- Bridge tables for card ↔ type and cost ↔ pip relationships

## ETL Workflow (Typical)

1. Load raw CSV into staging tables
2. Normalize and transform data
3. Insert into production tables using lookup functions
4. Enforce uniqueness and foreign keys
5. Query via relational joins and reusable CTEs

## Tech Stack

- PostgreSQL
- SQL (DDL, DML, functions)
- Python (ETL helpers and loaders)
- Git / GitHub

## How to Load Data (Example)

From `psql`:

```sql
\copy staging_cards FROM 'cards.csv' WITH (FORMAT csv, HEADER true);
