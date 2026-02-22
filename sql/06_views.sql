-- File: 06_views.sql
-- Project: MTG Card Database
-- Description: Views defintions
-- Author: Dave Sonnie
-- Copyright (c) 2026 Dave Sonnie

DROP VIEW IF EXISTS vw_card_profile;
CREATE OR REPLACE VIEW vw_card_profile AS
WITH 
types AS (
    SELECT
        ctb.mtg_card_id,
        string_agg(ct.card_type_name, ' ') AS card_types_text
    FROM card_type_bridge ctb 
    JOIN card_type ct 
        ON ct.card_type_id = ctb.card_type_id
    GROUP BY 
        ctb.mtg_card_id
),
subtypes AS (
    SELECT
        cstb.mtg_card_id,
        string_agg(cst.card_subtype_name, ' ' ORDER BY cst.card_subtype_id) AS card_subtypes_text
    FROM card_subtype_bridge cstb
    JOIN card_subtype cst
        ON cst.card_subtype_id = cstb.card_subtype_id
    GROUP BY 
        cstb.mtg_card_id
),
supertypes AS (
    SELECT
        csptb.mtg_card_id,
        string_agg(cspt.card_supertype_name, ' ' ORDER BY cspt.card_supertype_id) AS card_supertypes_text
    FROM card_supertype_bridge csptb
    JOIN card_supertype cspt
        ON cspt.card_supertype_id = csptb.card_supertype_id
    GROUP BY 
        csptb.mtg_card_id
)
SELECT
    c.mtg_card_id,
    c.mtg_card_name as card_name,
    mc.mana_cost_text as mana,
    mc.mana_cost_total as cmc,
    t.card_types_text as types,
    st.card_subtypes_text as subtypes,
    spt.card_supertypes_text as supertypes
FROM mtg_card c
LEFT JOIN types t
    ON t.mtg_card_id = c.mtg_card_id
LEFT JOIN subtypes st
    ON st.mtg_card_id = c.mtg_card_id
LEFT JOIN supertypes spt
    ON spt.mtg_card_id = c.mtg_card_id
LEFT JOIN mana_cost mc
    ON mc.mana_cost_id = c.mana_cost_id;