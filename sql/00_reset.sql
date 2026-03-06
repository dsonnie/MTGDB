-- File: 00_reset.sql
-- Project: MTG Card Database
-- Description: Full database reset - drops all objects
-- Author: Dave Sonnie
-- Copyright (c) 2026 Dave Sonnie
-- WARNING: Destructive - drops all tables, functions, triggers and views

-- Views
DROP VIEW IF EXISTS vw_card_profile;

-- Bridge tables first (depend on lookup tables and mtg_card)
DROP TABLE IF EXISTS card_type_bridge;
DROP TABLE IF EXISTS card_subtype_bridge;
DROP TABLE IF EXISTS card_supertype_bridge;
DROP TABLE IF EXISTS card_format_bridge;
DROP TABLE IF EXISTS card_name_mtg_set_bridge;
DROP TABLE IF EXISTS card_ability_bridge;
DROP TABLE IF EXISTS card_color_identity_bridge;
DROP TABLE IF EXISTS mana_cost_mana_pip;

-- Main card table (depends on lookup tables)
DROP TABLE IF EXISTS mtg_card;

-- Lookup tables
DROP TABLE IF EXISTS mana_pip;
DROP TABLE IF EXISTS mana_cost;
DROP TABLE IF EXISTS oracle_text;
DROP TABLE IF EXISTS original_text;
DROP TABLE IF EXISTS card_power;
DROP TABLE IF EXISTS card_toughness;
DROP TABLE IF EXISTS artist;
DROP TABLE IF EXISTS mtg_set;
DROP TABLE IF EXISTS rarity;
DROP TABLE IF EXISTS mtg_format CASCADE;
DROP TABLE IF EXISTS card_type;
DROP TABLE IF EXISTS card_subtype;
DROP TABLE IF EXISTS card_supertype;
DROP TABLE IF EXISTS card_ability;
DROP TABLE IF EXISTS color_identity;

-- Staging table
DROP TABLE IF EXISTS staging_cards;

-- Functions
DROP FUNCTION IF EXISTS get_or_insert_mana_pip(text);
DROP FUNCTION IF EXISTS get_or_insert_mana_cost(text);
DROP FUNCTION IF EXISTS trg_update_total_cost();
DROP FUNCTION IF EXISTS insert_oracle_text(text);
DROP FUNCTION IF EXISTS get_or_insert_card_power(varchar);
DROP FUNCTION IF EXISTS get_or_insert_card_toughness(varchar);
DROP FUNCTION IF EXISTS get_or_insert_artist(text);
DROP FUNCTION IF EXISTS get_or_insert_mtg_set(text);
DROP FUNCTION IF EXISTS parse_mtg_sets(integer, text);
DROP FUNCTION IF EXISTS get_or_insert_rarity(text);
DROP FUNCTION IF EXISTS get_or_insert_mtg_format(text);
DROP FUNCTION IF EXISTS parse_card_formats(integer, text);
DROP FUNCTION IF EXISTS get_or_insert_card_type(text);
DROP FUNCTION IF EXISTS parse_card_types(integer, text);
DROP FUNCTION IF EXISTS get_or_insert_card_subtype(text);
DROP FUNCTION IF EXISTS parse_card_subtypes(integer, text);
DROP FUNCTION IF EXISTS get_or_insert_card_supertype(text);
DROP FUNCTION IF EXISTS parse_card_supertypes(integer, text);
DROP FUNCTION IF EXISTS get_or_insert_card_ability(text);
DROP FUNCTION IF EXISTS parse_card_abilities(integer, text);
DROP FUNCTION IF EXISTS get_or_insert_color_identity(text);
DROP FUNCTION IF EXISTS parse_card_color_identity(integer, text);
DROP FUNCTION IF EXISTS insert_mtg_card(text,text,text,text,text,text,text,text,text,text,text,text,text,text,text);
DROP FUNCTION IF EXISTS insert_card_type_bridge(integer, integer);
DROP FUNCTION IF EXISTS insert_card_subtype_bridge(integer, integer);
DROP FUNCTION IF EXISTS insert_card_supertype_bridge(integer, integer);
DROP FUNCTION IF EXISTS insert_card_format_bridge(integer, integer);
DROP FUNCTION IF EXISTS insert_card_name_mtg_set_bridge(text, integer);
DROP FUNCTION IF EXISTS insert_card_ability_bridge(integer, integer);
DROP FUNCTION IF EXISTS insert_card_color_identity_bridge(integer, bigint);
DROP FUNCTION IF EXISTS insert_card_color_identity_bridge(integer, integer);