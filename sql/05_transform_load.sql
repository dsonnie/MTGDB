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
DO $$
DECLARE
    r               staging_cards%ROWTYPE;
    v_count         INTEGER := 0;
    v_segment_start TIMESTAMPTZ := clock_timestamp();
    v_load_start    TIMESTAMPTZ := clock_timestamp();
    v_segment_ms    NUMERIC;
    v_total_ms      NUMERIC;
BEGIN
    FOR r IN SELECT * FROM staging_cards LOOP
        PERFORM insert_mtg_card(
            r.uuid,
            r.name,
            r."manaCost",
            r.types,
            r.subtypes,
            r.supertypes,
            r.keywords,
            r.text,
            r.artist,
            r."setCode",
            r.availability,
            r.rarity,
            r.power,
            r.toughness,
            r."colorIdentity"
        );
        v_count := v_count + 1;
        IF MOD(v_count, 1000) = 0 THEN
            v_segment_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_segment_start)) * 1000;
            v_total_ms   := EXTRACT(EPOCH FROM (clock_timestamp() - v_load_start)) * 1000;
            RAISE NOTICE 'Processed % of 105682 | Segment: %ms | Elapsed: %ms',
                v_count,
                ROUND(v_segment_ms),
                ROUND(v_total_ms);
            v_segment_start := clock_timestamp();
            COMMIT;
        END IF;
    END LOOP;
    v_total_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_load_start)) * 1000;
    RAISE NOTICE 'Load complete. % cards processed. Total time: %ms',
        v_count,
        ROUND(v_total_ms);
END;
$$;

\set end_ts `date +%s.%N`
\echo Script ended at :end_ts

SELECT
    (:end_ts::numeric - :start_ts::numeric) AS elapsed_seconds;


/*
psql:/work/sql/05_transform_load.sql:56: NOTICE:  Load complete. 105682 cards processed. Total time: 830871ms
DO
Script ended at 1772893900.872452351
 elapsed_seconds
-----------------
   830.888592369
(1 row)
*/