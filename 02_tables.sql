-- File: 02_tables.sql
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

-- Bridge table between mana_cost and mana_pip
-- Each pip on a card is added separately here
DROP TABLE IF EXISTS mana_cost_mana_pip;
CREATE TABLE mana_cost_mana_pip (
    mana_cost_mana_pip_id   SERIAL    PRIMARY KEY,
    mana_cost_id            INTEGER   NOT NULL      REFERENCES mana_cost(mana_cost_id),
    mana_pip_id             INTEGER   NOT NULL      REFERENCES mana_pip(mana_pip_id)
);

-- Oracle Text
DROP TABLE IF EXISTS oracle_text;
CREATE TABLE oracle_text (
    oracle_text_id   SERIAL   PRIMARY KEY,
    oracle_text      TEXT
);

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

-- Toughness 
DROP TABLE IF EXISTS card_toughness;
CREATE TABLE card_toughness (
    card_toughness_id        SERIAL    PRIMARY KEY,
    card_toughness_value     INTEGER,  
    is_x_card_toughness      BOOLEAN,
    is_star_card_toughness   BOOLEAN,
    CONSTRAINT ak_card_toughness_value UNIQUE (card_toughness_value)
);

-- Artist
DROP TABLE IF EXISTS artist;
CREATE TABLE artist (
    artist_id      SERIAL   PRIMARY KEY,
    artist_name    TEXT     NOT NULL,
    CONSTRAINT 
        ak_artist_name UNIQUE (artist_name)
);

-- MTG Set
DROP TABLE IF EXISTS mtg_set;
CREATE TABLE mtg_set (
    mtg_set_id     SERIAL   PRIMARY KEY,
    mtg_set_name   TEXT     NOT NULL,
    CONSTRAINT ak_set_name UNIQUE (mtg_set_name)
);

-- Rarity
DROP TABLE IF EXISTS rarity;
CREATE TABLE rarity (
    rarity_id     SERIAL   PRIMARY KEY,
    rarity_name   TEXT     NOT NULL,
    CONSTRAINT ak_rarity_name UNIQUE (rarity_name)
);

-- Format
DROP TABLE IF EXISTS mtg_format CASCADE;
CREATE TABLE mtg_format (
    mtg_format_id     SERIAL   PRIMARY KEY,
    mtg_format_name   TEXT     NOT NULL,
    CONSTRAINT ak_format_name UNIQUE (mtg_format_name)
);

-- Card Types
DROP TABLE IF EXISTS card_type;
CREATE TABLE card_type (
    card_type_id     SERIAL   PRIMARY KEY,
    card_type_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_type_name UNIQUE (card_type_name)
);


-- Card Subtypes
DROP TABLE IF EXISTS card_subtype;
CREATE TABLE card_subtype (
    card_subtype_id     SERIAL   PRIMARY KEY,
    card_subtype_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_subtype_name UNIQUE (card_subtype_name)
);

-- Card Supertypes
DROP TABLE IF EXISTS card_supertype;
CREATE TABLE card_supertype (
    card_supertype_id     SERIAL   PRIMARY KEY,
    card_supertype_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_supertype_name UNIQUE (card_supertype_name)
);

-- Card Abilities
DROP TABLE IF EXISTS card_ability;
CREATE TABLE card_ability (
    card_ability_id     SERIAL   PRIMARY KEY,
    card_ability_name   TEXT     NOT NULL,
    CONSTRAINT ak_card_ability_name UNIQUE (card_ability_name)
);

-- Color identity
DROP TABLE IF EXISTS color_identity;
CREATE TABLE color_identity (
    color_identity_id BIGSERIAL PRIMARY KEY,
    color_identity_symbol TEXT NOT NULL,
    CONSTRAINT ak_color_identity_symbol UNIQUE (color_identity_symbol)
);

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

-- Bridge tables are used in cases where a card can have multiple of the same relationship - ie, card types (Artifact, Creature) or subtypes (Human, Soldier)
-- Bridge table between cards and card types
DROP TABLE IF EXISTS card_type_bridge;
CREATE TABLE card_type_bridge (
    mtg_card_id    INTEGER   NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_type_id   INTEGER   NOT NULL   REFERENCES card_type(card_type_id),
    PRIMARY KEY (mtg_card_id, card_type_id)
);


-- Bridge table between cards and subtypes
DROP TABLE IF EXISTS card_subtype_bridge;
CREATE TABLE card_subtype_bridge (
    mtg_card_id       INTEGER   NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_subtype_id   INTEGER   NOT NULL   REFERENCES card_subtype(card_subtype_id),
    PRIMARY KEY (mtg_card_id, card_subtype_id) 
);

-- Bridge table between cards and supertypes
DROP TABLE IF EXISTS card_supertype_bridge;
CREATE TABLE card_supertype_bridge (
    mtg_card_id         INT       NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_supertype_id   INTEGER   NOT NULL   REFERENCES card_supertype(card_supertype_id),
    PRIMARY KEY (mtg_card_id, card_supertype_id) 
);

-- Bridge table between cards and formats
DROP TABLE IF EXISTS card_format_bridge;
CREATE TABLE card_format_bridge (
    mtg_card_id     INT       NOT NULL   REFERENCES mtg_card(mtg_card_id),
    mtg_format_id   INTEGER   NOT NULL   REFERENCES mtg_format(mtg_format_id),
    PRIMARY KEY (mtg_card_id, mtg_format_id)
);

-- Bridge table between cards and MTG sets
DROP TABLE IF EXISTS card_name_mtg_set_bridge;
CREATE TABLE card_name_mtg_set_bridge (
    mtg_card_name  TEXT      NOT NULL,
    mtg_set_id     INTEGER   NOT NULL   REFERENCES mtg_set(mtg_set_id),
    PRIMARY KEY (mtg_card_name, mtg_set_id)
);


-- Bridge table between cards and card abilities
DROP TABLE IF EXISTS card_ability_bridge;
CREATE TABLE card_ability_bridge (
    mtg_card_id       INTEGER   NOT NULL   REFERENCES mtg_card(mtg_card_id),
    card_ability_id   INTEGER   NOT NULL   REFERENCES card_ability(card_ability_id),
    PRIMARY KEY (mtg_card_id, card_ability_id)
);

-- Bridge table between cards and color identities
-- This can be used for filtering cards based on commander color identites
DROP TABLE IF EXISTS card_color_identity_bridge;
CREATE TABLE card_color_identity_bridge (
    mtg_card_id INTEGER NOT NULL REFERENCES mtg_card(mtg_card_id),
    color_identity_id INTEGER NOT NULL REFERENCES color_identity(color_identity_id),
    PRIMARY KEY (mtg_card_id, color_identity_id)
);
