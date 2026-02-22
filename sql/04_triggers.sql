-- File: 04_triggers.sql
-- Project: MTG Card Database
-- Description: SQL Triggers
-- Author: Dave Sonnie
-- Copyright (c) 2026 Dave Sonnie

-- Add the trigger to update the total cost
DROP TRIGGER IF EXISTS trigger_update_total_cost ON mana_cost_mana_pip;
CREATE TRIGGER trigger_update_total_cost
AFTER INSERT OR UPDATE
ON mana_cost_mana_pip
FOR EACH ROW 
EXECUTE FUNCTION trg_update_total_cost();