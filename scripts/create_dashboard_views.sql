-- ============================================
-- Dashboard Views for Retool REST API
-- Run this in Supabase SQL Editor
-- These views are queryable via REST API like tables
-- ============================================

-- ============================================
-- VIEW 1: PO Prediction - Weeks of Stock Remaining
-- ============================================
CREATE OR REPLACE VIEW v_po_prediction AS
WITH weekly_totals AS (
    -- STEP 1: Sum ALL store sales per product per week
    SELECT
        code_saq,
        annee,
        periode,
        semaine,
        SUM(bouteille) as week_total_bottles
    FROM saq_ventes
    WHERE annee >= 2024
    GROUP BY code_saq, annee, periode, semaine
),
weekly_velocity AS (
    -- STEP 2: Average the weekly totals = true depletion rate
    SELECT
        code_saq,
        ROUND(AVG(week_total_bottles)::numeric, 1) as avg_weekly_bottles
    FROM weekly_totals
    GROUP BY code_saq
)
SELECT
    w.code_saq,
    w.product_name,
    w.type_listing,
    w.inventaire_cdm as warehouse_mtl_cases,
    w.inventaire_cdq as warehouse_qc_cases,
    ROUND(w.inventaire_cdm + w.inventaire_cdq, 1) as total_warehouse_cases,
    ROUND((w.inventaire_cdm + w.inventaire_cdq) * COALESCE(w.uvc, 12), 0) as total_warehouse_bottles,
    COALESCE(v.avg_weekly_bottles, 0) as avg_weekly_bottles,
    CASE
        WHEN COALESCE(v.avg_weekly_bottles, 0) = 0 THEN 999
        ELSE ROUND(((w.inventaire_cdm + w.inventaire_cdq) * COALESCE(w.uvc, 12)) / v.avg_weekly_bottles, 1)
    END as weeks_of_stock,
    CASE
        WHEN COALESCE(v.avg_weekly_bottles, 0) = 0 THEN 'Pas de ventes'
        WHEN ((w.inventaire_cdm + w.inventaire_cdq) * COALESCE(w.uvc, 12)) / v.avg_weekly_bottles < 4 THEN 'COMMANDER'
        WHEN ((w.inventaire_cdm + w.inventaire_cdq) * COALESCE(w.uvc, 12)) / v.avg_weekly_bottles < 6 THEN 'SURVEILLER'
        ELSE 'OK'
    END as alerte,
    w.date_inventaire
FROM saq_daily_warehouse w
LEFT JOIN weekly_velocity v ON w.code_saq = v.code_saq
ORDER BY
    CASE
        WHEN COALESCE(v.avg_weekly_bottles, 0) = 0 THEN 999
        ELSE ((w.inventaire_cdm + w.inventaire_cdq) * COALESCE(w.uvc, 12)) / v.avg_weekly_bottles
    END ASC;


-- ============================================
-- VIEW 2: YoY Sales Comparison (Period level)
-- ============================================
CREATE OR REPLACE VIEW v_yoy_sales AS
WITH this_year AS (
    SELECT
        code_saq,
        annee,
        periode,
        SUM(bouteille) as total_bottles,
        SUM(montant) as total_revenue
    FROM saq_ventes
    WHERE annee = (SELECT MAX(annee) FROM saq_ventes)
    GROUP BY code_saq, annee, periode
),
last_year AS (
    SELECT
        code_saq,
        annee,
        periode,
        SUM(bouteille) as total_bottles,
        SUM(montant) as total_revenue
    FROM saq_ventes
    WHERE annee = (SELECT MAX(annee) FROM saq_ventes) - 1
    GROUP BY code_saq, annee, periode
)
SELECT
    COALESCE(t.code_saq, l.code_saq) as code_saq,
    p.description as product_name,
    COALESCE(t.periode, l.periode) as periode,
    COALESCE(t.total_bottles, 0) as bottles_this_year,
    COALESCE(l.total_bottles, 0) as bottles_last_year,
    COALESCE(t.total_bottles, 0) - COALESCE(l.total_bottles, 0) as bottles_diff,
    CASE
        WHEN COALESCE(l.total_bottles, 0) = 0 THEN NULL
        ELSE ROUND(((COALESCE(t.total_bottles, 0) - l.total_bottles)::numeric / l.total_bottles) * 100, 1)
    END as yoy_pct,
    COALESCE(t.total_revenue, 0) as revenue_this_year,
    COALESCE(l.total_revenue, 0) as revenue_last_year,
    t.annee as current_year,
    l.annee as previous_year
FROM this_year t
FULL OUTER JOIN last_year l ON t.code_saq = l.code_saq AND t.periode = l.periode
LEFT JOIN saq_product p ON COALESCE(t.code_saq, l.code_saq) = p.code_saq
ORDER BY COALESCE(t.periode, l.periode), COALESCE(t.code_saq, l.code_saq);


-- ============================================
-- VIEW 3: Open Orders Pipeline
-- ============================================
CREATE OR REPLACE VIEW v_open_orders AS
SELECT
    no_commande,
    code_saq,
    product_name,
    qty_commandee,
    destination,
    date_emission,
    date_expedition_demandee,
    date_pret_fournisseur,
    date_depart_reel,
    eta_confirme,
    statut,
    CASE
        WHEN date_expedition_demandee IS NOT NULL
        THEN date_expedition_demandee - CURRENT_DATE
        ELSE NULL
    END as jours_avant_expedition,
    updated_at
FROM saq_order_status
ORDER BY date_expedition_demandee ASC NULLS LAST;


-- ============================================
-- VIEW 4: Store Inventory Summary by Product
-- ============================================
CREATE OR REPLACE VIEW v_store_inventory_summary AS
SELECT
    code_saq,
    product_name,
    COUNT(DISTINCT store_id) as nb_succursales,
    SUM(qty_bottles) as total_bouteilles,
    ROUND(AVG(qty_bottles)::numeric, 1) as moy_par_succursale,
    MAX(qty_bottles) as max_par_succursale,
    MIN(qty_bottles) as min_par_succursale,
    SUM(CASE WHEN qty_bottles = 0 THEN 1 ELSE 0 END) as succursales_rupture,
    date_inventaire
FROM saq_daily_stores
WHERE date_inventaire = (SELECT MAX(date_inventaire) FROM saq_daily_stores)
GROUP BY code_saq, product_name, date_inventaire
ORDER BY total_bouteilles DESC;


-- ============================================
-- VIEW 5: Store Inventory Detail (by banner)
-- ============================================
CREATE OR REPLACE VIEW v_store_inventory_by_banner AS
SELECT
    code_saq,
    product_name,
    banner as banniere,
    COUNT(DISTINCT store_id) as nb_succursales,
    SUM(qty_bottles) as total_bouteilles,
    ROUND(AVG(qty_bottles)::numeric, 1) as moy_par_succursale,
    date_inventaire
FROM saq_daily_stores
WHERE date_inventaire = (SELECT MAX(date_inventaire) FROM saq_daily_stores)
GROUP BY code_saq, product_name, banner, date_inventaire
ORDER BY code_saq, banner;


-- ============================================
-- VIEW 6: Sales Trend (weekly, last 13 periods)
-- ============================================
CREATE OR REPLACE VIEW v_sales_trend AS
SELECT
    code_saq,
    annee,
    periode,
    semaine,
    SUM(bouteille) as total_bottles,
    SUM(montant) as total_revenue,
    COUNT(DISTINCT no_succursale) as stores_sold
FROM saq_ventes
WHERE annee >= (SELECT MAX(annee) - 1 FROM saq_ventes)
GROUP BY code_saq, annee, periode, semaine
ORDER BY annee DESC, periode DESC, semaine DESC;


-- ============================================
-- VIEW 7: KPI Summary (top-level numbers)
-- ============================================
CREATE OR REPLACE VIEW v_dashboard_kpi AS
WITH weekly_totals AS (
    SELECT code_saq, annee, periode, semaine, SUM(bouteille) as week_total
    FROM saq_ventes WHERE annee >= 2024
    GROUP BY code_saq, annee, periode, semaine
),
velocity AS (
    SELECT code_saq, AVG(week_total) as avg_weekly_bottles
    FROM weekly_totals GROUP BY code_saq
),
stock_alert AS (
    SELECT COUNT(*) as cnt
    FROM saq_daily_warehouse w
    LEFT JOIN velocity v ON w.code_saq = v.code_saq
    WHERE COALESCE(v.avg_weekly_bottles, 0) > 0
      AND ((w.inventaire_cdm + w.inventaire_cdq) * COALESCE(w.uvc, 12)) / v.avg_weekly_bottles < 4
)
SELECT
    (SELECT COUNT(*) FROM saq_daily_warehouse) as total_products,
    (SELECT cnt FROM stock_alert) as low_stock_products,
    (SELECT COUNT(*) FROM saq_order_status) as open_orders,
    (SELECT SUM(qty_commandee) FROM saq_order_status) as total_units_on_order,
    (SELECT COUNT(DISTINCT store_id) FROM saq_daily_stores WHERE date_inventaire = (SELECT MAX(date_inventaire) FROM saq_daily_stores)) as active_stores,
    (SELECT SUM(qty_bottles) FROM saq_daily_stores WHERE date_inventaire = (SELECT MAX(date_inventaire) FROM saq_daily_stores)) as total_bottles_in_stores,
    (SELECT ROUND(SUM(inventaire_cdm + inventaire_cdq)::numeric, 0) FROM saq_daily_warehouse) as total_warehouse_cases,
    (SELECT MAX(date_inventaire) FROM saq_daily_warehouse) as last_warehouse_update,
    (SELECT MAX(date_inventaire) FROM saq_daily_stores) as last_store_update;
