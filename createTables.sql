-- File: createTables.sql
-- Project: MTG Card Database
-- Description: Normalized schema for MTG cards
-- Author: Dave Sonnie
-- Copyright (c) 2026 Dave Sonnie


-- Flush dependants first
DROP TABLE IF EXISTS card_type_bridge;
DROP TABLE IF EXISTS card_subtype_bridge;
DROP TABLE IF EXISTS card_supertype_bridge;
DROP TABLE IF EXISTS card_format_bridge;
DROP TABLE IF EXISTS card_name_mtg_set_bridge;
DROP TABLE IF EXISTS card_ability_bridge;
DROP TABLE IF EXISTS card_color_identity_bridge;
DROP TABLE IF EXISTS mtg_card;
DROP TABLE IF EXISTS mana_cost_mana_pip;
--
-- Tables
--
-- Mana Pips
DROP TABLE IF EXISTS mana_pip;
CREATE TABLE mana_pip (
    mana_pip_id       SERIAL    PRIMARY KEY,
    mana_pip_symbol   TEXT      NOT NULL,
    mana_pip_cost     INTEGER   NOT NULL,
    CONSTRAINT ak_mana_pip_symbol UNIQUE (mana_pip_symbol)
);
-- Helper function to get or insert mana pip
DROP FUNCTION IF EXISTS get_or_insert_mana_pip;
CREATE OR REPLACE FUNCTION get_or_insert_mana_pip (
    p_mana_pip_symbol   TEXT
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE 
    v_mana_pip_id     INTEGER;
    v_symbol          TEXT := UPPER(TRIM(p_mana_pip_symbol));
    v_mana_pip_cost   INTEGER := 1; -- default cost of a pip is 1, we will check for generic and X later
BEGIN
    -- Validate pip cost
    IF UPPER(v_symbol) = 'X' THEN    
        v_mana_pip_cost := 0; -- X counts as zero in the cost sum
    ELSIF v_symbol ~ '^\d+$' THEN
        v_mana_pip_cost := v_symbol::INTEGER; -- If the token is a digit, it's a generic cost pip. The cost value is equal to the token itself
    END IF;
    INSERT INTO mana_pip (mana_pip_symbol, mana_pip_cost)
    VALUES (v_symbol, v_mana_pip_cost)
    ON CONFLICT (mana_pip_symbol)
    DO UPDATE SET mana_pip_symbol = EXCLUDED.mana_pip_symbol
    RETURNING mana_pip_id INTO v_mana_pip_id;
    RETURN v_mana_pip_id;
END;
$$;

-- Mana Cost
-- Cost is ultimately collected from the bridge table between mana_cost and mana_pip
-- Cost total is used for quick filtering
-- Cost text is used to check for duplicates
DROP TABLE IF EXISTS mana_cost;
CREATE TABLE mana_cost (
    mana_cost_id      SERIAL    PRIMARY KEY,
    mana_cost_text    TEXT, 
    mana_cost_total   INTEGER   DEFAULT 0,
    CONSTRAINT ak_mana_cost_text UNIQUE (mana_cost_text)
);
-- Helper function to get or insert mana_cost
DROP FUNCTION IF EXISTS get_or_insert_mana_cost(text);
CREATE OR REPLACE FUNCTION get_or_insert_mana_cost (
    p_mana_cost_text    TEXT
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_mana_cost_id     INTEGER;
    v_mana_cost_text   TEXT := UPPER(p_mana_cost_text);
    v_token            TEXT;
    v_mana_pip_id      INT;
BEGIN
    -- Insert new rows only, we can skip everything else if this cost_text conflicts with an existing row
    INSERT INTO mana_cost (mana_cost_text)
    VALUES (v_mana_cost_text)
    ON CONFLICT (mana_cost_text)
        DO NOTHING
    RETURNING mana_cost_id INTO v_mana_cost_id;
    -- If v_mana_cost_id is null we had a conflict
    -- Short circuit to avoid unnecessary parsing of pips
    IF v_mana_cost_id IS NULL THEN
        SELECT mana_cost_id
        INTO v_mana_cost_id
        FROM mana_cost
        WHERE mana_cost_text = p_mana_cost_text
        LIMIT 1;
        RETURN v_mana_cost_id;
    END IF;
    -- Otherwise, no conflicts: parse the pips
    -- Iterate over the tokens in the text to get_or_insert pips
    FOR v_token IN
        SELECT m[1] 
        FROM regexp_matches(p_mana_cost_text, '\{([^}]+)\}', 'g') 
        AS m
    LOOP
        -- Get or insert pip
        v_mana_pip_id := get_or_insert_mana_pip(v_token);
        -- Add bridge table entry
        INSERT INTO mana_cost_mana_pip (mana_cost_id, mana_pip_id)
        VALUES (v_mana_cost_id, v_mana_pip_id);
    END LOOP;
    RETURN v_mana_cost_id;
END;
$$;
-- Bridge table between mana_cost and mana_pip
-- Each pip on a card is added separately here
DROP TABLE IF EXISTS mana_cost_mana_pip;
CREATE TABLE mana_cost_mana_pip (
    mana_cost_mana_pip_id   SERIAL    PRIMARY KEY,
    mana_cost_id            INTEGER   NOT NULL      REFERENCES mana_cost(mana_cost_id),
    mana_pip_id             INTEGER   NOT NULL      REFERENCES mana_pip(mana_pip_id)
);
-- Trigger function for updating mana cost total
DROP FUNCTION IF EXISTS trg_update_total_cost();
CREATE FUNCTION trg_update_total_cost()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_cost INTEGER := 0;
BEGIN
    -- Get the sum of costs of pips related to this cost
    SELECT SUM(mana_pip.mana_pip_cost)
    INTO v_total_cost 
    FROM mana_cost_mana_pip
    JOIN mana_pip
    ON mana_pip.mana_pip_id = mana_cost_mana_pip.mana_pip_id
    WHERE mana_cost_mana_pip.mana_cost_id = NEW.mana_cost_id;
    -- Update the mana_cost record's total cost
    UPDATE mana_cost
    SET mana_cost_total = v_total_cost
    WHERE mana_cost_id = NEW.mana_cost_id;
    RETURN NEW;
END;
$$;
-- Add the trigger to update the total cost
DROP TRIGGER IF EXISTS trigger_update_total_cost ON mana_cost_mana_pip;
CREATE TRIGGER trigger_update_total_cost
AFTER INSERT OR UPDATE
ON mana_cost_mana_pip
FOR EACH ROW 
EXECUTE FUNCTION trg_update_total_cost();

-- Oracle Text
DROP TABLE IF EXISTS oracle_text;
CREATE TABLE oracle_text (
    oracle_text_id   SERIAL   PRIMARY KEY,
    oracle_text      TEXT
);
-- Insert function
DROP FUNCTION IF EXISTS insert_oracle_text(TEXT);
CREATE FUNCTION insert_oracle_text(
    p_oracle_text   TEXT
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_oracle_text_id INTEGER;
BEGIN
    INSERT INTO oracle_text (oracle_text)
    VALUES (p_oracle_text)
    RETURNING oracle_text_id INTO v_oracle_text_id;
    RETURN v_oracle_text_id;
END;
$$;

-- Original Text
DROP TABLE IF EXISTS original_text;
CREATE TABLE original_text (
    original_text_id   SERIAL   PRIMARY KEY,
    original_text      TEXT
);

-- Power 
DROP TABLE IF EXISTS card_power;
CREATE TABLE card_power (
    card_power_id        SERIAL    PRIMARY KEY,
    card_power_value     INTEGER,  
    is_x_card_power      BOOLEAN,
    is_star_card_power   BOOLEAN,
    CONSTRAINT ak_card_power_value UNIQUE (card_power_value)
);
-- Helper function to get or insert a power value
CREATE OR REPLACE FUNCTION get_or_insert_card_power(
    p_card_power_value   VARCHAR(5)
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_power_id INTEGER;
BEGIN
    -- Check for X power
    IF p_card_power_value = 'X' OR p_card_power_value = 'x' THEN
        INSERT INTO card_power (card_power_value, is_x_card_power, is_star_card_power)
        VALUES (-9999, TRUE, FALSE)
        ON CONFLICT (card_power_value)
        DO UPDATE SET card_power_value = EXCLUDED.card_power_value
        RETURNING card_power_id INTO v_card_power_id;
    -- Check for * power
    ELSIF p_card_power_value = '*' THEN
        INSERT INTO card_power (card_power_value, is_x_card_power, is_star_card_power)
        VALUES (-9998, FALSE, TRUE)
        ON CONFLICT (card_power_value)
        DO UPDATE SET card_power_value = EXCLUDED.card_power_value
        RETURNING card_power_id INTO v_card_power_id;
    -- Not X power
    -- Validate decimal value
    ELSIF p_card_power_value ~ '^-?\d+$' THEN
        INSERT INTO card_power (card_power_value, is_x_card_power, is_star_card_power)
        VALUES (CAST(p_card_power_value AS INTEGER), FALSE, TRUE)
        ON CONFLICT (card_power_value)
        DO UPDATE SET card_power_value =  EXCLUDED.card_power_value
        RETURNING card_power_id INTO v_card_power_id;
    ELSIF p_card_power_value IS NOT NULL THEN
         INSERT INTO card_power (card_power_value, is_x_card_power, is_star_card_power)
        VALUES (-5000, FALSE, FALSE)
        ON CONFLICT (card_power_value)
        DO UPDATE SET card_power_value =  EXCLUDED.card_power_value
        RETURNING card_power_id INTO v_card_power_id;
    END IF;
    RETURN v_card_power_id;
END;
$$;

-- Toughness 
DROP TABLE IF EXISTS card_toughness;
CREATE TABLE card_toughness (
    card_toughness_id        SERIAL    PRIMARY KEY,
    card_toughness_value     INTEGER,  
    is_x_card_toughness      BOOLEAN,
    is_star_card_toughness   BOOLEAN,
    CONSTRAINT ak_card_toughness_value UNIQUE (card_toughness_value)
);
-- Helper function to get or insert a toughness value
CREATE OR REPLACE FUNCTION get_or_insert_card_toughness(
    p_card_toughness_value   VARCHAR(5)
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_toughness_id   INTEGER;
BEGIN
    -- Check for X toughness
    IF p_card_toughness_value = 'X' OR p_card_toughness_value = 'x' THEN
        INSERT INTO card_toughness (card_toughness_value, is_x_card_toughness, is_star_card_toughness)
        VALUES (-9999, TRUE, FALSE)
        ON CONFLICT (card_toughness_value)
        DO UPDATE SET card_toughness_value = EXCLUDED.card_toughness_value
        RETURNING card_toughness_id INTO v_card_toughness_id;
    -- Check for * toughness    
    ELSIF p_card_toughness_value = '*' THEN
        INSERT INTO card_toughness (card_toughness_value, is_x_card_toughness, is_star_card_toughness)
        VALUES (-9998, FALSE, TRUE)
        ON CONFLICT (card_toughness_value)
        DO UPDATE SET card_toughness_value = EXCLUDED.card_toughness_value
        RETURNING card_toughness_id INTO v_card_toughness_id;
    -- Not X toughness
    -- Verify standard decimal toughness
    ELSIF p_card_toughness_value ~ '^-?\d+$' THEN
        INSERT INTO card_toughness (card_toughness_value, is_x_card_toughness, is_star_card_toughness)
        VALUES (CAST(p_card_toughness_value AS INTEGER), FALSE, FALSE)
        ON CONFLICT (card_toughness_value)
        DO UPDATE SET card_toughness_value =  EXCLUDED.card_toughness_value
        RETURNING card_toughness_id INTO v_card_toughness_id;
    -- Mark non-null values that we didn't catch for review
    ELSIF p_card_toughness_value IS NOT NULL THEN
        INSERT INTO card_toughness (card_toughness_value, is_x_card_toughness, is_star_card_toughness)
        VALUES (-5000, FALSE, FALSE)
        ON CONFLICT (card_toughness_value)
        DO UPDATE SET card_toughness_value =  EXCLUDED.card_toughness_value
        RETURNING card_toughness_id INTO v_card_toughness_id;
    END IF;
    RETURN v_card_toughness_id;
END;
$$;

-- Artist
DROP TABLE IF EXISTS artist;
CREATE TABLE artist (
    artist_id      SERIAL   PRIMARY KEY,
    artist_name    TEXT     NOT NULL,
    CONSTRAINT 
        ak_artist_name UNIQUE (artist_name)
);
-- Helper function to get or insert an artist
CREATE OR REPLACE FUNCTION get_or_insert_artist(
    p_artist   TEXT
) RETURNS INTEGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_artist_id     INTEGER;
    v_artist_name   TEXT;
BEGIN
    IF p_artist IS NULL THEN
        v_artist_name := 'UNKNOWN';
    ELSE 
        v_artist_name := p_artist;
    END IF;
    INSERT INTO artist (artist_name)
    VALUES (v_artist_name)
    ON CONFLICT (artist_name)
    DO UPDATE SET artist_name = EXCLUDED.artist_name
    RETURNING artist_id INTO v_artist_id;
    RETURN v_artist_id;
END;
$$;

-- MTG Set
DROP TABLE IF EXISTS mtg_set;
CREATE TABLE mtg_set (
    mtg_set_id     SERIAL   PRIMARY KEY,
    mtg_set_name   TEXT     NOT NULL,
    CONSTRAINT ak_set_name UNIQUE (mtg_set_name)
);
-- Helper function to get or insert a MTG set
DROP FUNCTION IF EXISTS get_or_insert_set;
CREATE OR REPLACE FUNCTION get_or_insert_mtg_set(
    p_mtg_set_name   TEXT
) RETURNS INTEGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_set_id INTEGER;
BEGIN
    INSERT INTO mtg_set (mtg_set_name)
    VALUES (p_mtg_set_name)
    ON CONFLICT (mtg_set_name)
    DO UPDATE SET mtg_set_name = EXCLUDED.mtg_set_name
    RETURNING mtg_set_id INTO v_set_id;
    RETURN v_set_id;
END;
$$;
-- Parse a card's MTG set string into its individual types
DROP FUNCTION IF EXISTS parse_mtg_sets;
CREATE FUNCTION parse_mtg_sets (
    p_mtg_card_id      INTEGER,
    p_mtg_set_string   TEXT    
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_token_text      TEXT;
    v_mtg_set_id      INTEGER;
    v_mtg_card_name   TEXT;
BEGIN
    -- Multiple card formats are separated by commas
    FOR v_token_text IN
        SELECT TRIM(token)
        FROM regexp_split_to_table(p_mtg_set_string, '\s*,\s*') 
        AS token
    LOOP
        v_mtg_set_id := get_or_insert_mtg_set(v_token_text);
        -- Get name of card
        SELECT mtg_card.mtg_card_name 
          INTO v_mtg_card_name
          FROM mtg_card 
          WHERE mtg_card.mtg_card_id = p_mtg_card_id
          LIMIT 1;
        PERFORM insert_card_name_mtg_set(v_mtg_card_name, v_mtg_set_id);
    END LOOP;
END;
$$;

-- Rarity
DROP TABLE IF EXISTS rarity;
CREATE TABLE rarity (
    rarity_id     SERIAL   PRIMARY KEY,
    rarity_name   TEXT     NOT NULL,
    CONSTRAINT ak_rarity_name UNIQUE (rarity_name)
);
-- Helper function to get or insert a rarity
CREATE OR REPLACE FUNCTION get_or_insert_rarity(
    p_rarity_name   TEXT
) RETURNS INTEGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_rarity_id INTEGER;
BEGIN
    INSERT INTO rarity (rarity_name)
    VALUES (LOWER(TRIM(p_rarity_name)))
    ON CONFLICT (rarity_name)
    DO UPDATE SET rarity_name =  EXCLUDED.rarity_name
    RETURNING rarity_id INTO v_rarity_id;
    RETURN v_rarity_id;
END;
$$;

-- Format
DROP TABLE IF EXISTS mtg_format CASCADE;
CREATE TABLE mtg_format (
    mtg_format_id     SERIAL   PRIMARY KEY,
    mtg_format_name   TEXT     NOT NULL,
    CONSTRAINT ak_format_name UNIQUE (mtg_format_name)
);
-- Helper function to get or insert a format
CREATE OR REPLACE FUNCTION get_or_insert_mtg_format(
    p_mtg_format_name   TEXT
) RETURNS INTEGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_mtg_format_id   INTEGER;
BEGIN
    INSERT INTO mtg_format (mtg_format_name)
    VALUES (p_mtg_format_name)
    ON CONFLICT (mtg_format_name)
    DO UPDATE SET mtg_format_name =  EXCLUDED.mtg_format_name
    RETURNING mtg_format_id INTO v_mtg_format_id;
    RETURN v_mtg_format_id;
END;
$$;
-- Parse a card's format string into its individual types
DROP FUNCTION IF EXISTS parse_card_formats;
CREATE FUNCTION parse_card_formats (
    p_mtg_card_id         INTEGER,
    p_mtg_format_string   TEXT    
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_token_text      TEXT;
    v_mtg_format_id   INTEGER;
BEGIN
    -- Multiple card formats are separated by commas
    FOR v_token_text IN
        SELECT TRIM(token)
        FROM regexp_split_to_table(p_mtg_format_string, '\s*,\s*') 
        AS token
    LOOP
        v_mtg_format_id := get_or_insert_mtg_format(v_token_text);
        PERFORM insert_card_format_bridge(p_mtg_card_id, v_mtg_format_id);
    END LOOP;
END;
$$;

-- Card Types
DROP TABLE IF EXISTS card_type;
CREATE TABLE card_type (
    card_type_id     SERIAL   PRIMARY KEY,
    card_type_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_type_name UNIQUE (card_type_name)
);
-- Helper function to get or insert a card type
DROP FUNCTION IF EXISTS get_or_insert_card_type(text);
CREATE OR REPLACE FUNCTION get_or_insert_card_type(
    p_card_type_name   TEXT
) RETURNS INT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_type_id   INTEGER;
BEGIN
    INSERT INTO card_type (card_type_name)
    VALUES (p_card_type_name)
    ON CONFLICT (card_type_name)
    DO UPDATE SET card_type_name = EXCLUDED.card_type_name
    RETURNING card_type_id INTO v_card_type_id;
    RETURN v_card_type_id;
END;
$$;
-- Parse a card's type string into its individual types
DROP FUNCTION IF EXISTS parse_card_types;
CREATE FUNCTION parse_card_types (
    p_mtg_card_id        INTEGER,
    p_card_type_string   TEXT    
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_token_text     TEXT;
    v_card_type_id   INTEGER;
BEGIN
    -- Multiple card types are separated by commas
    FOR v_token_text IN
        SELECT TRIM(token)
        FROM regexp_split_to_table(p_card_type_string, '\s*,\s*') 
        AS token
    LOOP
        v_card_type_id := get_or_insert_card_type(v_token_text);
        PERFORM insert_card_type_bridge(p_mtg_card_id, v_card_type_id);
    END LOOP;
END;
$$;

-- Card Subtypes
DROP TABLE IF EXISTS card_subtype;
CREATE TABLE card_subtype (
    card_subtype_id     SERIAL   PRIMARY KEY,
    card_subtype_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_subtype_name UNIQUE (card_subtype_name)
);
-- Helper function to get or insert a card subtype
DROP FUNCTION IF EXISTS get_or_insert_card_subtype(text);
CREATE OR REPLACE FUNCTION get_or_insert_card_subtype(
    p_card_subtype_name   TEXT
) RETURNS INTEGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_subtype_id   INTEGER;
BEGIN
    INSERT INTO card_subtype (card_subtype_name)
    VALUES (p_card_subtype_name)
    ON CONFLICT (card_subtype_name)
    DO UPDATE SET card_subtype_name = EXCLUDED.card_subtype_name
    RETURNING card_subtype_id INTO v_card_subtype_id;
    RETURN v_card_subtype_id;
END;
$$;
-- Parse a card's subtype string into its individual subtypes
DROP FUNCTION IF EXISTS parse_card_subtypes;
CREATE FUNCTION parse_card_subtypes (
    p_mtg_card_id           INTEGER,
    p_card_subtype_string   TEXT    
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_token_text        TEXT;
    v_card_subtype_id   INTEGER;
BEGIN
    -- Multiple card subtypes are separated by commas
    FOR v_token_text IN
        SELECT TRIM(token)
        FROM regexp_split_to_table(p_card_subtype_string, '\s*,\s*') 
        AS token
    LOOP
        v_card_subtype_id := get_or_insert_card_subtype(v_token_text);
        PERFORM insert_card_subtype_bridge(p_mtg_card_id, v_card_subtype_id);
    END LOOP;
END;
$$;

-- Card Supertypes
DROP TABLE IF EXISTS card_supertype;
CREATE TABLE card_supertype (
    card_supertype_id     SERIAL   PRIMARY KEY,
    card_supertype_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_supertype_name UNIQUE (card_supertype_name)
);
-- Helper function to get or insert a card supertype
DROP FUNCTION IF EXISTS get_or_insert_card_supertype(text);
CREATE OR REPLACE FUNCTION get_or_insert_card_supertype(
    p_card_supertype_name   TEXT
) RETURNS INTEGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_supertype_id   INTEGER;
BEGIN
    INSERT INTO card_supertype (card_supertype_name)
    VALUES (p_card_supertype_name)
    ON CONFLICT (card_supertype_name)
    DO UPDATE SET card_supertype_name = EXCLUDED.card_supertype_name
    RETURNING card_supertype_id INTO v_card_supertype_id;
    RETURN v_card_supertype_id;
END;
$$;
-- Parse a card's supertype string into its individual supertypes
DROP FUNCTION IF EXISTS parse_card_supertypes;
CREATE FUNCTION parse_card_supertypes (
    p_mtg_card_id             INTEGER,
    p_card_supertype_string   TEXT    
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_token_text          TEXT;
    v_card_supertype_id   INTEGER;
BEGIN
    -- Multiple card subtypes are separated by commas
    FOR v_token_text IN
        SELECT TRIM(token)
        FROM regexp_split_to_table(p_card_supertype_string, '\s*,\s*') 
        AS token
    LOOP
        v_card_supertype_id := get_or_insert_card_supertype(v_token_text);
        PERFORM insert_card_supertype_bridge(p_mtg_card_id, v_card_supertype_id);
    END LOOP;
END;
$$;

-- Card Abilities
DROP TABLE IF EXISTS card_ability;
CREATE TABLE card_ability (
    card_ability_id     SERIAL   PRIMARY KEY,
    card_ability_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_ability_name UNIQUE (card_ability_name)
);
-- Helper function to get or insert a card ability
DROP FUNCTION IF EXISTS get_or_insert_card_ability(text);
CREATE OR REPLACE FUNCTION get_or_insert_card_ability(
    p_card_ability_name   TEXT
) RETURNS INTEGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_card_ability_id   INTEGER;
BEGIN
    INSERT INTO card_ability (card_ability_name)
    VALUES (p_card_ability_name)
    ON CONFLICT (card_ability_name)
    DO UPDATE SET card_ability_name = EXCLUDED.card_ability_name
    RETURNING card_ability_id INTO v_card_ability_id;
    RETURN v_card_ability_id;
END;
$$;
-- Parse a card's ability string into its individual abilities
DROP FUNCTION IF EXISTS parse_card_abilities;
CREATE FUNCTION parse_card_abilities (
    p_mtg_card_id           INTEGER,
    p_card_ability_string   TEXT    
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_token_text        TEXT;
    v_card_ability_id   INTEGER;
BEGIN
    -- Multiple card abilities are separated by commas
    FOR v_token_text IN
        SELECT TRIM(token)
        FROM regexp_split_to_table(p_card_ability_string, '\s*,\s*') 
        AS token
    LOOP
        v_card_ability_id := get_or_insert_card_ability(v_token_text);
        PERFORM insert_card_ability_bridge(p_mtg_card_id, v_card_ability_id);
    END LOOP;
END;
$$;

-- Color identity
DROP TABLE IF EXISTS color_identity;
CREATE TABLE color_identity (
    color_identity_id BIGSERIAL PRIMARY KEY,
    color_identity_symbol TEXT NOT NULL,
    CONSTRAINT ak_color_identity_symbol UNIQUE (color_identity_symbol)
);
-- Helper function to get or insert a color identity
DROP FUNCTION IF EXISTS get_or_insert_color_identity;
CREATE FUNCTION get_or_insert_color_identity (
    p_color_identity_symbol TEXT
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_color_identity_id BIGINT;
BEGIN
    INSERT INTO color_identity (color_identity_symbol)
    VALUES (p_color_identity_symbol)
    ON CONFLICT (color_identity_symbol) 
    DO UPDATE SET color_identity_symbol  = EXCLUDED.color_identity_symbol
    RETURNING color_identity_id INTO v_color_identity_id;
    RETURN v_color_identity_id;
END;
$$;
-- Parse a card's color identity into its individual symbols
DROP FUNCTION IF EXISTS parse_card_color_identity;
CREATE FUNCTION parse_card_color_identity (
    p_mtg_card_id           INTEGER,
    p_card_color_identity_string   TEXT    
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_token_text        TEXT;
    v_color_identity_id   INTEGER;
BEGIN
    -- Multiple color identities are separated by commas
    FOR v_token_text IN
        SELECT TRIM(token)
        FROM regexp_split_to_table(p_card_color_identity_string, '\s*,\s*') 
        AS token
    LOOP
        v_color_identity_id := get_or_insert_color_identity(v_token_text);
        PERFORM insert_card_color_identity_bridge(p_mtg_card_id, v_color_identity_id);
    END LOOP;
END;
$$;


-- Cards
-- FKs: cost_id, oracle_text_id, original_text_id, artist_id, set_id, rarity_id
DROP TABLE IF EXISTS mtg_card;
CREATE TABLE mtg_card (
    mtg_card_id         SERIAL    PRIMARY KEY,
    mtg_card_uuid       TEXT      NOT NULL,
    mtg_card_name       TEXT,
    mana_cost_id        INTEGER   NOT NULL   REFERENCES mana_cost(mana_cost_id),
    oracle_text_id      INTEGER   NOT NULL   REFERENCES oracle_text(oracle_text_id),
 -- original_text_id    INTEGER   NOT NULL   REFERENCES original_text(original_text_id),
    card_power_id       INTEGER,
    card_toughness_id   INTEGER,
    artist_id           INTEGER   NOT NULL   REFERENCES artist(artist_id),
    mtg_set_id          INTEGER   NOT NULL   REFERENCES mtg_set(mtg_set_id),
    rarity_id           INTEGER   NOT NULL   REFERENCES rarity(rarity_id),
    loyalty             INTEGER,
    is_reprint          BOOLEAN,
    CONSTRAINT ak_mtg_card_uuid UNIQUE (mtg_card_uuid)
    --CONSTRAINT ak_mtg_card_mtg_set UNIQUE (mtg_card_name, mtg_set_id)
);
-- Helper function to add cards
DROP FUNCTION IF EXISTS insert_mtg_card;
CREATE FUNCTION insert_mtg_card(
    p_mtg_card_uuid           TEXT,
    p_mtg_card_name           TEXT,
    p_mana_cost_text          TEXT,
    p_card_type_csv           TEXT,
    p_card_subtype_csv        TEXT,
    p_card_supertype_csv      TEXT,
    p_card_abilities_csv      TEXT,
    p_oracle_text             TEXT,
    p_artist_name             TEXT,
    p_mtg_set_name            TEXT,
    p_mtg_format_csv          TEXT,
    p_rarity_name             TEXT,
    p_card_power              TEXT,
    p_card_toughness          TEXT,
    p_card_color_identity_csv TEXT
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_mtg_card_id         INTEGER;
    v_mana_cost_id        INTEGER;
    v_artist_id           INTEGER;
    v_mtg_set_id          INTEGER;
    v_rarity_id           INTEGER;
    v_card_power_id       INTEGER;
    v_card_toughness_id   INTEGER;
    v_oracle_text_id      INTEGER;
BEGIN
    -- Set IDs
    v_mana_cost_id   := get_or_insert_mana_cost(p_mana_cost_text);
    v_artist_id      := get_or_insert_artist(p_artist_name);
    v_rarity_id      := get_or_insert_rarity(p_rarity_name);
    v_mtg_set_id     := get_or_insert_mtg_set(p_mtg_set_name);
    v_oracle_text_id := insert_oracle_text(p_oracle_text);
    -- Check for Power
    IF p_card_power IS NOT NULL THEN
        v_card_power_id := get_or_insert_card_power(p_card_power);
    END IF;
    -- Check for Toughness
    if p_card_toughness IS NOT NULL THEN
        v_card_toughness_id := get_or_insert_card_toughness(p_card_toughness);
    END IF;

    INSERT INTO mtg_card (
        mtg_card_uuid,
        mtg_card_name,
        mana_cost_id,
        oracle_text_id,
        artist_id,
        mtg_set_id,
        rarity_id,
        card_power_id,
        card_toughness_id
    )
    VALUES (
        p_mtg_card_uuid,
        p_mtg_card_name,
        v_mana_cost_id,
        v_oracle_text_id,
        v_artist_id,
        v_mtg_set_id,
        v_rarity_id,
        v_card_power_id,
        v_card_toughness_id
    )
    ON CONFLICT (mtg_card_uuid) DO NOTHING
    RETURNING mtg_card_id INTO v_mtg_card_id;
    IF v_mtg_card_id IS NULL THEN
        RETURN -1;
    END IF;

    -- If we have not short circuited on a duplicate card proceed with processing additional card details
    -- Card types
    IF p_card_type_csv IS NOT NULL THEN 
        PERFORM parse_card_types(v_mtg_card_id, p_card_type_csv);
    END IF;
    -- Card subtypes
    IF p_card_subtype_csv IS NOT NULL THEN     
        PERFORM parse_card_subtypes(v_mtg_card_id, p_card_subtype_csv);
    END IF;
    -- Card supertypes
    IF p_card_supertype_csv IS NOT NULL THEN     
        PERFORM parse_card_supertypes(v_mtg_card_id, p_card_supertype_csv);
    END IF;
    -- Card formats
    IF p_mtg_format_csv IS NOT NULL THEN 
        PERFORM parse_card_formats(v_mtg_card_id, p_mtg_format_csv);
    END IF;
    -- Card abilities
    IF p_card_abilities_csv IS NOT NULL THEN 
        PERFORM parse_card_abilities(v_mtg_card_id, p_card_abilities_csv);
    END IF;
    -- Card color identities
    IF p_card_color_identity_csv IS NOT NULL THEN
        PERFORM parse_card_color_identity(v_mtg_card_id, p_card_color_identity_csv);
    END IF;

    RETURN v_mtg_card_id;
END
$$;


-- Bridge tables are used in cases where a card can have multiple of the same relationship - ie, card types (Artifact, Creature) or subtypes (Human, Soldier)
-- Bridge table between cards and card types
DROP TABLE IF EXISTS card_type_bridge;
CREATE TABLE card_type_bridge (
    mtg_card_id    INTEGER   NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_type_id   INTEGER   NOT NULL   REFERENCES card_type(card_type_id),
    PRIMARY KEY (mtg_card_id, card_type_id)
);
-- Insert function
DROP FUNCTION IF EXISTS insert_card_type_bridge;
CREATE FUNCTION insert_card_type_bridge(
    p_mtg_card_id    INTEGER,
    p_card_type_id   INTEGER
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO card_type_bridge (mtg_card_id, card_type_id)
    VALUES (p_mtg_card_id, p_card_type_id)
    ON CONFLICT (mtg_card_id, card_type_id) DO NOTHING;
END;
$$;

-- Bridge table between cards and subtypes
DROP TABLE IF EXISTS card_subtype_bridge;
CREATE TABLE card_subtype_bridge (
    mtg_card_id       INTEGER   NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_subtype_id   INTEGER   NOT NULL   REFERENCES card_subtype(card_subtype_id),
    PRIMARY KEY (mtg_card_id, card_subtype_id) 
);
-- Insert function
DROP FUNCTION IF EXISTS insert_card_subtype_bridge;
CREATE FUNCTION insert_card_subtype_bridge(
    p_mtg_card_id       INTEGER,
    p_card_subtype_id   INTEGER
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO card_subtype_bridge (mtg_card_id, card_subtype_id)
    VALUES (p_mtg_card_id, p_card_subtype_id)
    ON CONFLICT (mtg_card_id, card_subtype_id) DO NOTHING;
END;
$$;

-- Bridge table between cards and supertypes
DROP TABLE IF EXISTS card_supertype_bridge;
CREATE TABLE card_supertype_bridge (
    mtg_card_id         INT       NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_supertype_id   INTEGER   NOT NULL   REFERENCES card_supertype(card_supertype_id),
    PRIMARY KEY (mtg_card_id, card_supertype_id) 
);
-- Insert function
DROP FUNCTION IF EXISTS insert_card_supertype_bridge;
CREATE FUNCTION insert_card_supertype_bridge (
    p_mtg_card_id         INTEGER,
    p_card_supertype_id   INTEGER
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO card_supertype_bridge (mtg_card_id, card_supertype_id)
    VALUES (p_mtg_card_id, p_card_supertype_id)
    ON CONFLICT (mtg_card_id, card_supertype_id) DO NOTHING;
END;
$$;

-- Bridge table between cards and formats
DROP TABLE IF EXISTS card_format_bridge;
CREATE TABLE card_format_bridge (
    mtg_card_id     INT       NOT NULL   REFERENCES mtg_card(mtg_card_id),
    mtg_format_id   INTEGER   NOT NULL   REFERENCES mtg_format(mtg_format_id),
    PRIMARY KEY (mtg_card_id, mtg_format_id)
);
-- Insert function
DROP FUNCTION IF EXISTS insert_card_format_bridge;
CREATE FUNCTION insert_card_format_bridge (
    p_mtg_card_id     INTEGER,
    p_mtg_format_id   INTEGER
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO card_format_bridge (mtg_card_id, mtg_format_id)
    VALUES (p_mtg_card_id, p_mtg_format_id)
    ON CONFLICT (mtg_card_id, mtg_format_id) DO NOTHING;
END;
$$;

-- Bridge table between cards and MTG sets
DROP TABLE IF EXISTS card_name_mtg_set_bridge;
CREATE TABLE card_name_mtg_set_bridge (
    mtg_card_name  TEXT      NOT NULL,
    mtg_set_id     INTEGER   NOT NULL   REFERENCES mtg_set(mtg_set_id),
    PRIMARY KEY (mtg_card_name, mtg_set_id)
);
-- Insert function
DROP FUNCTION IF EXISTS insert_card_name_mtg_set_bridge;
CREATE FUNCTION insert_card_name_mtg_set_bridge (
    p_mtg_card_name  TEXT,
    p_mtg_set_id     INTEGER
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO card_name_mtg_set_bridge (mtg_card_name, mtg_set_id)
    VALUES (p_mtg_card_name, p_mtg_set_id)
    ON CONFLICT (mtg_card_name, mtg_set_id) DO NOTHING;
END;
$$;

-- Bridge table between cards and card abilities
DROP TABLE IF EXISTS card_ability_bridge;
CREATE TABLE card_ability_bridge (
    mtg_card_id       INTEGER   NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_ability_id   INTEGER   NOT NULL   REFERENCES card_ability(card_ability_id),
    PRIMARY KEY (mtg_card_id, card_ability_id)
);
-- Insert function
DROP FUNCTION IF EXISTS insert_card_ability_bridge;
CREATE FUNCTION insert_card_ability_bridge (
    p_mtg_card_id       INTEGER,
    p_card_ability_id   INTEGER
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO card_ability_bridge (mtg_card_id, card_ability_id)
    VALUES (p_mtg_card_id, p_card_ability_id)
    ON CONFLICT (mtg_card_id, card_ability_id) DO NOTHING;
END;
$$;

-- Bridge table between cards and color identities
-- This can be used for filtering cards based on commander color identites
DROP TABLE IF EXISTS card_color_identity_bridge;
CREATE TABLE card_color_identity_bridge (
    mtg_card_id INTEGER NOT NULL REFERENCES mtg_card(mtg_card_id),
    color_identity_id INTEGER NOT NULL REFERENCES color_identity(color_identity_id),
    PRIMARY KEY (mtg_card_id, color_identity_id)
);
-- Insert function
DROP FUNCTION IF EXISTS insert_card_color_identity_bridge;
CREATE FUNCTION insert_card_color_identity_bridge (
    p_mtg_card_id INTEGER,
    p_color_identity_id BIGINT
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO card_color_identity_bridge (mtg_card_id, color_identity_id)
    VALUES (p_mtg_card_id, p_color_identity_id)
    ON CONFLICT DO NOTHING;
END;    
$$;


-- STAGING
--
-- Create the Staging table if it doesn't already exist
CREATE TABLE IF NOT EXISTS staging_cards (
    "artist"                    TEXT,
    "artistIds"                 TEXT,
    "asciiName"                 TEXT,
    "attractionLights"          TEXT,
    "availability"              TEXT,
    "boosterTypes"              TEXT,
    "borderColor"               TEXT,
    "cardParts"                 TEXT,
    "colorIdentity"             TEXT,
    "colorIndicator"            TEXT,
    "colors"                    TEXT,
    "defense"                   TEXT,
    "duelDeck"                  TEXT,
    "edhrecRank"                TEXT,
    "edhrecSaltiness"           TEXT,
    "faceConvertedManaCost"     TEXT,
    "faceFlavorName"            TEXT,
    "faceManaValue"             TEXT,
    "faceName"                  TEXT,
    "finishes"                  TEXT,
    "flavorName"                TEXT,
    "flavorText"                TEXT,
    "frameEffects"              TEXT,
    "frameVersion"              TEXT,
    "hand"                      TEXT,
    "hasAlternativeDeckLimit"   TEXT,
    "hasContentWarning"         TEXT,
    "hasFoil"                   TEXT,
    "hasNonFoil"                TEXT,
    "isAlternative"             TEXT,
    "isFullArt"                 TEXT,
    "isFunny"                   TEXT,
    "isGameChanger"             TEXT,
    "isOnlineOnly"              TEXT,
    "isOversized"               TEXT,
    "isPromo"                   TEXT,
    "isRebalanced"              TEXT,
    "isReprint"                 TEXT,
    "isReserved"                TEXT,
    "isStarter"                 TEXT,
    "isStorySpotlight"          TEXT,
    "isTextless"                TEXT,
    "isTimeshifted"             TEXT,
    "keywords"                  TEXT,
    "language"                  TEXT,
    "layout"                    TEXT,
    "leadershipSkills"          TEXT,
    "life"                      TEXT,
    "loyalty"                   TEXT,
    "manaCost"                  TEXT,
    "manaValue"                 TEXT,
    "name"                      TEXT,
    "number"                    TEXT,
    "originalPrintings"         TEXT,
    "originalReleaseDate"       TEXT,
    "originalText"              TEXT,
    "otherFaceIds"              TEXT,
    "power"                     TEXT,
    "printings"                 TEXT,
    "promoTypes"                TEXT,
    "rarity"                    TEXT,
    "rebalancedPrintings"       TEXT,
    "relatedCards"              TEXT,
    "securityStamp"             TEXT,
    "setCode"                   TEXT,
    "side"                      TEXT,
    "signature"                 TEXT,
    "sourceProducts"            TEXT,
    "subsets"                   TEXT,
    "subtypes"                  TEXT,
    "supertypes"                TEXT,
    "text"                      TEXT,
    "toughness"                 TEXT,
    "type"                      TEXT,
    "types"                     TEXT,
    "uuid"                      TEXT,
    "variations"                TEXT,
    "watermark"                 TEXT
);

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