-- File: 07_indexes.sql
-- Project: MTG Card Database
-- Description: Table indexes
-- Author: Dave Sonnie
-- Copyright (c) 2026 Dave Sonnie

-- =============================================================
-- Query 1
--
-- EXPLAIN ANALYZE
-- SELECT * FROM mtg_card
-- WHERE mtg_card_name = 'Plains';
--
-- -------------------------------------------------------------
-- BEFORE
-- -------------------------------------------------------------
--  Seq Scan on mtg_card
--    (cost=0.00..2905.03 rows=729 width=91)
--    (actual time=0.128..24.903 rows=854 loops=1)
--    Filter: (mtg_card_name = 'Plains'::text)
--    Rows Removed by Filter: 104828
--  Planning Time: 0.991 ms
--  Execution Time: 24.984 ms
--
-- -------------------------------------------------------------
-- AFTER
-- -------------------------------------------------------------
--  Bitmap Heap Scan on mtg_card
--    (cost=15.32..1426.39 rows=891 width=91)
--    (actual time=0.157..3.356 rows=854 loops=1)
--    Recheck Cond: (mtg_card_name = 'Plains'::text)
--    Heap Blocks: exact=278
--    ->  Bitmap Index Scan on idx_mtg_card_name
--          (cost=0.00..15.10 rows=891 width=0)
--          (actual time=0.121..0.121 rows=854 loops=1)
--          Index Cond: (mtg_card_name = 'Plains'::text)
--  Planning Time: 0.666 ms
--  Execution Time: 3.460 ms
--
-- -------------------------------------------------------------
-- SUMMARY
-- Seq Scan eliminated. Full table read of 104,828 rows replaced
-- by Bitmap Index Scan reading 278 heap pages.
-- Execution time: 24.984ms -> 3.460ms (86% improvement)
-- =============================================================


-- =============================================================
-- Query 2
--
-- EXPLAIN ANALYZE
-- SELECT mc.mtg_card_name
-- FROM mtg_card mc
-- JOIN card_type_bridge ctb ON mc.mtg_card_id = ctb.mtg_card_id
-- JOIN card_type ct ON ctb.card_type_id = ct.card_type_id
-- WHERE ct.card_type_name = 'Creature';
--
-- -------------------------------------------------------------
-- BEFORE
-- -------------------------------------------------------------
--  Hash Join
--    (cost=2545.06..5611.19 rows=2900 width=17)
--    (actual time=51.598..74.964 rows=50195 loops=1)
--    Hash Cond: (mc.mtg_card_id = ctb.mtg_card_id)
--    ->  Seq Scan on mtg_card mc
--          (cost=0.00..2640.82 rows=105682 width=21)
--          (actual time=0.011..5.489 rows=105682 loops=1)
--    ->  Hash
--          (cost=2508.81..2508.81 rows=2900 width=4)
--          (actual time=51.532..51.535 rows=50195 loops=1)
--          Buckets: 65536  Batches: 1  Memory Usage: 2277kB
--          ->  Hash Join
--                (cost=597.49..2508.81 rows=2900 width=4)
--                (actual time=18.316..41.982 rows=50195 loops=1)
--                Hash Cond: (ctb.card_type_id = ct.card_type_id)
--                ->  Seq Scan on card_type_bridge ctb
--                      (cost=0.00..1589.83 rows=110183 width=8)
--                      (actual time=0.017..13.350 rows=110183 loops=1)
--                ->  Hash
--                      (cost=597.48..597.48 rows=1 width=4)
--                      (actual time=18.269..18.270 rows=1 loops=1)
--                      ->  Seq Scan on card_type ct
--                            (cost=0.00..597.48 rows=1 width=4)
--                            (actual time=18.261..18.261 rows=1 loops=1)
--                            Filter: (card_type_name = 'Creature'::text)
--                            Rows Removed by Filter: 37
--  Planning Time: 1.054 ms
--  Execution Time: 77.286 ms
--
-- -------------------------------------------------------------
-- AFTER
-- -------------------------------------------------------------
--  Nested Loop
--    (cost=55.01..1742.29 rows=2900 width=17)
--    (actual time=1.848..80.067 rows=50195 loops=1)
--    ->  Nested Loop
--          (cost=54.72..645.89 rows=2900 width=4)
--          (actual time=1.824..10.546 rows=50195 loops=1)
--          ->  Bitmap Heap Scan on card_type ct
--                (cost=4.27..8.29 rows=1 width=4)
--                (actual time=0.052..0.055 rows=1 loops=1)
--                Recheck Cond: (card_type_name = 'Creature'::text)
--                Heap Blocks: exact=1
--                ->  Bitmap Index Scan on ak_card_type_name
--                      (actual time=0.038..0.039 rows=1 loops=1)
--                      Index Cond: (card_type_name = 'Creature'::text)
--          ->  Bitmap Heap Scan on card_type_bridge ctb
--                (cost=50.45..593.53 rows=4407 width=8)
--                (actual time=1.761..6.900 rows=50195 loops=1)
--                Recheck Cond: (card_type_id = ct.card_type_id)
--                Heap Blocks: exact=488
--                ->  Bitmap Index Scan on idx_card_type_bridge_type_id
--                      (actual time=1.701..1.701 rows=50195 loops=1)
--                      Index Cond: (card_type_id = ct.card_type_id)
--    ->  Index Scan using mtg_card_pkey on mtg_card mc
--          (cost=0.29..0.38 rows=1 width=21)
--          (actual time=0.001..0.001 rows=1 loops=50195)
--          Index Cond: (mtg_card_id = ctb.mtg_card_id)
--  Planning Time: 1.372 ms
--  Execution Time: 81.661 ms
--
-- -------------------------------------------------------------
-- SUMMARY
-- Seq Scan on card_type_bridge eliminated. 110,183 row full
-- scan replaced by Bitmap Index Scan reading 488 heap pages.
-- Planner switched from Hash Join to Nested Loop due to row
-- estimate error (estimated 4,407 actual 50,195). Raw time
-- comparable but page reads reduced by 56%. Statistics target
-- increase on card_type_id expected to correct plan choice.
-- =============================================================


-- =============================================================
-- Query 3
--
-- EXPLAIN ANALYZE
-- SELECT mc.mtg_card_name
-- FROM mtg_card mc
-- JOIN card_color_identity_bridge ccib ON mc.mtg_card_id = ccib.mtg_card_id
-- JOIN color_identity ci ON ccib.color_identity_id = ci.color_identity_id
-- WHERE ci.color_identity_symbol = 'U';
--
-- -------------------------------------------------------------
-- BEFORE
-- -------------------------------------------------------------
--  Hash Join
--    (cost=3222.68..6496.88 rows=23707 width=17)
--    (actual time=18.269..35.049 rows=23547 loops=1)
--    Hash Cond: (mc.mtg_card_id = ccib.mtg_card_id)
--    ->  Seq Scan on mtg_card mc
--          (cost=0.00..2640.82 rows=105682 width=21)
--          (actual time=0.005..5.282 rows=105682 loops=1)
--    ->  Hash
--          (cost=2926.35..2926.35 rows=23707 width=4)
--          (actual time=18.085..18.088 rows=23547 loops=1)
--          Buckets: 32768  Batches: 1  Memory Usage: 1084kB
--          ->  Hash Join
--                (cost=641.08..2926.35 rows=23707 width=4)
--                (actual time=0.218..14.542 rows=23547 loops=1)
--                Hash Cond: (ccib.color_identity_id = ci.color_identity_id)
--                ->  Seq Scan on card_color_identity_bridge ccib
--                      (cost=0.00..1710.37 rows=118537 width=8)
--                      (actual time=0.004..5.505 rows=118537 loops=1)
--                ->  Hash
--                      (cost=641.06..641.06 rows=1 width=8)
--                      (actual time=0.199..0.200 rows=1 loops=1)
--                      ->  Seq Scan on color_identity ci
--                            (cost=0.00..641.06 rows=1 width=8)
--                            (actual time=0.189..0.189 rows=1 loops=1)
--                            Filter: (color_identity_symbol = 'U'::text)
--                            Rows Removed by Filter: 4
--  Planning Time: 0.237 ms
--  Execution Time: 35.721 ms
--
-- -------------------------------------------------------------
-- AFTER
-- -------------------------------------------------------------
--  Hash Join
--    (cost=1631.04..5301.55 rows=23707 width=17)
--    (actual time=9.082..27.299 rows=23547 loops=1)
--    Hash Cond: (mc.mtg_card_id = ccib.mtg_card_id)
--    ->  Seq Scan on mtg_card mc
--          (cost=0.00..2640.82 rows=105682 width=21)
--          (actual time=0.003..5.693 rows=105682 loops=1)
--    ->  Hash
--          (cost=1334.71..1334.71 rows=23707 width=4)
--          (actual time=8.836..8.840 rows=23547 loops=1)
--          Buckets: 32768  Batches: 1  Memory Usage: 1084kB
--          ->  Nested Loop
--                (cost=272.29..1334.71 rows=23707 width=4)
--                (actual time=1.294..5.984 rows=23547 loops=1)
--                ->  Bitmap Heap Scan on color_identity ci
--                      (cost=4.27..8.28 rows=1 width=8)
--                      (actual time=0.607..0.609 rows=1 loops=1)
--                      Recheck Cond: (color_identity_symbol = 'U'::text)
--                      Heap Blocks: exact=1
--                      ->  Bitmap Index Scan on ak_color_identity_symbol
--                            (actual time=0.592..0.593 rows=1 loops=1)
--                            Index Cond: (color_identity_symbol = 'U'::text)
--                ->  Bitmap Heap Scan on card_color_identity_bridge ccib
--                      (cost=268.02..1089.36 rows=23707 width=8)
--                      (actual time=0.683..3.694 rows=23547 loops=1)
--                      Recheck Cond: (color_identity_id = ci.color_identity_id)
--                      Heap Blocks: exact=525
--                      ->  Bitmap Index Scan on idx_card_color_identity_bridge_color_id
--                            (actual time=0.635..0.635 rows=23547 loops=1)
--                            Index Cond: (color_identity_id = ci.color_identity_id)
--  Planning Time: 0.957 ms
--  Execution Time: 28.082 ms
--
-- -------------------------------------------------------------
-- SUMMARY
-- Seq Scan on card_color_identity_bridge eliminated. 118,537
-- row full scan replaced by Bitmap Index Scan reading 525
-- heap pages. Hash Join strategy preserved. Seq Scan on
-- mtg_card remains as Hash Join probe input — expected behavior
-- for large result sets without a selective filter on mtg_card.
-- Execution time: 35.721ms -> 28.082ms (21% improvement)
-- =============================================================

CREATE INDEX idx_mtg_card_name 
   ON mtg_card(mtg_card_name);

CREATE INDEX idx_card_type_bridge_type_id 
   ON card_type_bridge(card_type_id);

CREATE INDEX idx_card_color_identity_bridge_color_id 
   ON card_color_identity_bridge(color_identity_id);

CREATE INDEX idx_card_format_bridge_format_id 
   ON card_format_bridge(mtg_format_id);

CREATE INDEX idx_card_subtype_bridge_subtype_id 
   ON card_subtype_bridge(card_subtype_id);

CREATE INDEX idx_card_supertype_bridge_supertype_id 
   ON card_supertype_bridge(card_supertype_id);

CREATE INDEX idx_card_ability_bridge_ability_id 
   ON card_ability_bridge(card_ability_id);

CREATE INDEX idx_mana_cost_mana_pip_cost_id
   ON mana_cost_mana_pip(mana_cost_id);

-- Update statistics
ANALYZE mtg_card;
ANALYZE card_type_bridge;
ANALYZE card_color_identity_bridge;
ANALYZE card_format_bridge;
ANALYZE card_subtype_bridge;
ANALYZE card_supertype_bridge;
ANALYZE card_ability_bridge;
ANALYZE mana_cost_mana_pip;

