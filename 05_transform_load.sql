-- File: 05_transform_load.sql
-- Project: MTG Card Database
-- Description: Transform and Load ETL
-- Author: Dave Sonnie
-- Copyright (c) 2026 Dave Sonnie

-- Transformation and Load step
-- Processes cards from the staging table into the cards table

\set start_ts `date +%s.%N`
\echo Script started at :start_ts
-- Populate main tables from staging
SELECT insert_mtg_card(
    s.uuid,
    s.name,
    s."manaCost",
    s.types,
    s.subtypes,
    s.supertypes,
    s.keywords,
    s.text,
    s.artist,
    s."setCode",
    s.availability,
    s.rarity,
    s.power,
    s.toughness, 
    s."colorIdentity"
)
FROM staging_cards s;

\set end_ts `date +%s.%N`
\echo Script ended at :end_ts

SELECT
    (:end_ts::numeric - :start_ts::numeric) AS elapsed_seconds;