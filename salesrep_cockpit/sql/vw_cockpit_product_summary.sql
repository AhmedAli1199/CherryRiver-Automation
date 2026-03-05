-- ============================================================
-- VIEW: vw_cockpit_product_summary
-- Purpose: One row per Cherry River product with all columns
--          needed for the main SAQ Sales Cockpit table in Retool.
--
-- Data sources:
--   saq_ventes              → Cherry River store-level sales (updated weekly by pipeline)
--   saq_daily_warehouse     → live warehouse inventory (updated daily by Patrick's automation)
--   saq_product             → product catalog (Cherry River products only, ~80 rows)
--
-- Units: all sales columns are in CASES (bottles ÷ format_caisse).
--        inventory columns are already in cases from saq_daily_warehouse.
--
-- NOTE: Sales data is Cherry River territory only (not full national SAQ network).
--       saq_ventes covers the ~379 stores assigned to Cherry River reps.
--
-- Current period hardcoded: 2025 / Period 12 / Week 4
-- Previous period: 2025 / Period 11
--
-- To update for a new period: change the periode/semaine numbers in the
-- sales CTE (12 → new period, 11 → previous period).
-- ============================================================

DROP VIEW IF EXISTS vw_cockpit_product_summary;

CREATE VIEW vw_cockpit_product_summary AS

-- ── STEP 0: Cherry River products ────────────────────────────────────────────
-- saq_product has ~80 rows (Cherry River catalog only, no duplicates).
-- format_caisse = bottles per case (e.g. 12 for spirits, 24 for RTD c24, 6 for RTD c6).
WITH cherry_products AS (
  SELECT
    code_saq::text                  AS code_saq,
    description,
    product_type,
    COALESCE(format_caisse, 12)     AS format_caisse   -- default 12 if not set
  FROM saq_product
  WHERE product_type IS NOT NULL
),

-- ── STEP 1: Sales data ────────────────────────────────────────────────────────
-- Source: saq_ventes (Cherry River territory, updated weekly by pipeline).
-- saq_ventes stores BOTTLES in the `bouteille` column.
-- We sum by period/week; the final SELECT divides by format_caisse to get CASES.
-- No year filter in WHERE — CASE expressions handle 2024 vs 2025 separation.
sales AS (
  SELECT
    sv.code_saq::text AS code_saq,

    -- Previous period (P11)
    SUM(CASE WHEN annee = 2024 AND periode = 11 THEN bouteille ELSE 0 END) AS p11ly_btl,
    SUM(CASE WHEN annee = 2025 AND periode = 11 THEN bouteille ELSE 0 END) AS p11ty_btl,

    -- Current period (P12): week by week
    SUM(CASE WHEN annee = 2025 AND periode = 12 AND semaine = 1 THEN bouteille ELSE 0 END) AS s1_btl,
    SUM(CASE WHEN annee = 2025 AND periode = 12 AND semaine = 2 THEN bouteille ELSE 0 END) AS s2_btl,
    SUM(CASE WHEN annee = 2025 AND periode = 12 AND semaine = 3 THEN bouteille ELSE 0 END) AS s3_btl,
    SUM(CASE WHEN annee = 2025 AND periode = 12 AND semaine = 4 THEN bouteille ELSE 0 END) AS s4_btl,

    -- Period-to-date P12
    SUM(CASE WHEN annee = 2024 AND periode = 12 THEN bouteille ELSE 0 END) AS ptdly_btl,
    SUM(CASE WHEN annee = 2025 AND periode = 12 THEN bouteille ELSE 0 END) AS ptdty_btl,

    -- Full-year totals
    SUM(CASE WHEN annee = 2024 THEN bouteille ELSE 0 END) AS totally_btl,
    SUM(CASE WHEN annee = 2025 THEN bouteille ELSE 0 END) AS totalty_btl

  FROM saq_ventes sv
  WHERE sv.code_saq::text IN (SELECT code_saq FROM cherry_products)
  GROUP BY sv.code_saq
),

-- ── STEP 2: Live warehouse inventory ─────────────────────────────────────────
-- saq_daily_warehouse is updated daily by Patrick's n8n automation.
-- inventaire_cdm (MTL) and inventaire_cdq (QC) are already in CASES — no conversion needed.
-- Filter to latest date (same pattern used by v_store_inventory_summary).
inv AS (
  SELECT
    code_saq,
    inventaire_cdm AS cdm_i,
    inventaire_cdq AS cdq_i
  FROM saq_daily_warehouse
  WHERE date_inventaire = (SELECT MAX(date_inventaire) FROM saq_daily_warehouse)
),

-- ── STEP 3: Store counts (Succ + NB Succ) ────────────────────────────────────
-- Count Cherry River stores that sold each product in P12 vs P11.
-- One pass: get P12 and P11 bottles per store, then count and compare.
store_data AS (
  SELECT
    code_saq::text AS code_saq,
    no_succursale,
    SUM(CASE WHEN periode = 12 THEN bouteille ELSE 0 END) AS p12,
    SUM(CASE WHEN periode = 11 THEN bouteille ELSE 0 END) AS p11
  FROM saq_ventes
  WHERE annee = 2025 AND periode IN (11, 12)
  GROUP BY code_saq, no_succursale
),
store_counts AS (
  SELECT
    code_saq,
    COUNT(DISTINCT CASE WHEN p12 > 0 THEN no_succursale END)               AS succ_cur,
    COUNT(DISTINCT CASE WHEN p11 > 0 THEN no_succursale END)               AS succ_prev,
    COUNT(DISTINCT CASE WHEN p12 > p11 AND p12 > 0 THEN no_succursale END) AS nb_up,
    COUNT(DISTINCT CASE WHEN p12 < p11 AND p11 > 0 THEN no_succursale END) AS nb_down
  FROM store_data
  GROUP BY code_saq
)

-- ── FINAL SELECT ─────────────────────────────────────────────────────────────
-- Base: cherry_products (~80 rows).
-- All sales converted from bottles to cases by dividing by format_caisse.
-- Inventory already in cases from saq_daily_warehouse.
SELECT
  p.code_saq                                                                         AS code,
  p.description                                                                      AS name,
  p.product_type,

  -- Previous period P11 (in cases)
  ROUND(COALESCE(s.p11ly_btl, 0)::numeric / p.format_caisse, 2)                    AS p11ly,
  ROUND(COALESCE(s.p11ty_btl, 0)::numeric / p.format_caisse, 2)                    AS p11ty,
  CASE WHEN COALESCE(s.p11ly_btl, 0) = 0 THEN NULL
       ELSE ROUND(((s.p11ty_btl - s.p11ly_btl)::numeric / s.p11ly_btl) * 100, 1)
  END                                                                                AS prev_var_pct,

  -- Current period P12 week by week (in cases)
  ROUND(COALESCE(s.s1_btl, 0)::numeric / p.format_caisse, 2)                       AS s1,
  ROUND(COALESCE(s.s2_btl, 0)::numeric / p.format_caisse, 2)                       AS s2,
  ROUND(COALESCE(s.s3_btl, 0)::numeric / p.format_caisse, 2)                       AS s3,
  ROUND(COALESCE(s.s4_btl, 0)::numeric / p.format_caisse, 2)                       AS s4,

  -- Period-to-date P12 (in cases)
  ROUND(COALESCE(s.ptdly_btl, 0)::numeric / p.format_caisse, 2)                    AS ptdly,
  ROUND(COALESCE(s.ptdty_btl, 0)::numeric / p.format_caisse, 2)                    AS ptdty,
  CASE WHEN COALESCE(s.ptdly_btl, 0) = 0 THEN NULL
       ELSE ROUND(((s.ptdty_btl - s.ptdly_btl)::numeric / s.ptdly_btl) * 100, 1)
  END                                                                                AS ptd_var_pct,

  -- Warehouse inventory (already in cases from saq_daily_warehouse)
  COALESCE(inv.cdm_i, 0)                                                            AS cdm_i,
  COALESCE(inv.cdq_i, 0)                                                            AS cdq_i,

  -- Store counts (Cherry River territory)
  COALESCE(sc.succ_cur, 0)                                                          AS succ,
  (COALESCE(sc.succ_cur, 0) - COALESCE(sc.succ_prev, 0))                           AS nb_succ_net,
  COALESCE(sc.nb_up, 0)                                                             AS nb_succ_up,
  COALESCE(sc.nb_down, 0)                                                           AS nb_succ_down,

  -- Annual totals (in cases)
  ROUND(COALESCE(s.totally_btl, 0)::numeric / p.format_caisse, 2)                  AS totally,
  ROUND(COALESCE(s.totalty_btl, 0)::numeric / p.format_caisse, 2)                  AS totalty

FROM cherry_products p
LEFT JOIN sales        s  ON s.code_saq  = p.code_saq
LEFT JOIN inv             ON inv.code_saq = p.code_saq
LEFT JOIN store_counts sc ON sc.code_saq  = p.code_saq
ORDER BY p.product_type, p.description;
