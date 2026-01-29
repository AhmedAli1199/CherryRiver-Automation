-- COO Summary Stats - FINAL VERSION
-- Provides complete operational picture with proper context
-- Separates critical issues from routine operations

CREATE OR REPLACE FUNCTION get_coo_summary_stats()
RETURNS TABLE (
  -- OVERALL HEALTH METRICS
  overall_rupture_rate NUMERIC,
  inventory_turnover_rate NUMERIC,
  total_skus INTEGER,
  total_inventory_records INTEGER,
  total_stores INTEGER,

  -- CRITICAL ISSUES (Need immediate action)
  critical_ruptures_high_volume INTEGER,
  critical_ruptures_stores_affected INTEGER,
  skus_with_critical_ruptures INTEGER,

  -- ROUTINE OPERATIONS (Normal restocking)
  routine_ruptures_low_volume INTEGER,
  skus_with_routine_stockouts INTEGER,
  total_stockout_locations INTEGER,

  -- RISK ALERTS (Proactive monitoring)
  high_risk_locations INTEGER,
  high_risk_skus INTEGER,
  medium_risk_locations INTEGER,
  medium_risk_skus INTEGER,
  stores_with_any_alerts INTEGER,

  -- SALES PERFORMANCE
  total_weekly_sales NUMERIC,
  total_bottles_sold INTEGER,
  avg_sales_per_store NUMERIC,
  top_selling_sku_sales NUMERIC,

  -- INVENTORY EFFICIENCY
  avg_days_of_inventory NUMERIC,
  healthy_inventory_pct NUMERIC,
  total_inventory_value NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_inventory_records INTEGER;
  v_total_stores INTEGER;
  v_total_weekly_sales NUMERIC;
BEGIN
  -- Get totals first
  SELECT COUNT(*) INTO v_total_inventory_records FROM saq_store_inventory;
  SELECT COUNT(DISTINCT store_number) INTO v_total_stores FROM saq_stores;

  RETURN QUERY
  WITH inventory_stats AS (
    -- Base inventory analysis
    SELECT
      inv.saq_code,
      inv.store_number,
      inv.qty_inventory,
      inv.avg_weekly_sales,
      inv.days_of_inventory,
      inv.is_critical,
      inv.is_warning,
      CASE
        WHEN inv.qty_inventory <= 0 AND inv.avg_weekly_sales > 10 THEN 'critical_rupture'
        WHEN inv.qty_inventory <= 0 AND (inv.avg_weekly_sales <= 10 OR inv.avg_weekly_sales IS NULL) THEN 'routine_rupture'
        WHEN inv.days_of_inventory IS NOT NULL AND inv.days_of_inventory < 2.5 * 7 THEN 'high_risk'
        WHEN inv.days_of_inventory IS NOT NULL AND inv.days_of_inventory >= 2.5 * 7 AND inv.days_of_inventory < 4 * 7 THEN 'medium_risk'
        ELSE 'healthy'
      END as risk_category
    FROM saq_store_inventory inv
  ),
  sku_level_analysis AS (
    -- Determine which SKUs have issues at ANY location
    SELECT
      saq_code,
      MAX(CASE WHEN risk_category = 'critical_rupture' THEN 1 ELSE 0 END) as has_critical_rupture,
      MAX(CASE WHEN risk_category = 'routine_rupture' THEN 1 ELSE 0 END) as has_routine_rupture,
      MAX(CASE WHEN risk_category = 'high_risk' THEN 1 ELSE 0 END) as has_high_risk,
      MAX(CASE WHEN risk_category = 'medium_risk' THEN 1 ELSE 0 END) as has_medium_risk
    FROM inventory_stats
    GROUP BY saq_code
  ),
  weekly_sales_summary AS (
    -- Get most recent week's sales
    SELECT
      MAX(week_start_date) as latest_week
    FROM saq_weekly_sales
  ),
  sales_data AS (
    -- Aggregate sales metrics
    SELECT
      COALESCE(SUM(ws.amount), 0) as total_sales,
      COALESCE(SUM(ws.qty_bottles), 0) as total_bottles,
      COALESCE(MAX(ws.amount), 0) as top_sku_sales
    FROM saq_weekly_sales ws
    CROSS JOIN weekly_sales_summary wss
    WHERE ws.week_start_date = wss.latest_week
  ),
  inventory_health_metrics AS (
    -- Calculate inventory efficiency metrics
    SELECT
      COUNT(*) as total_records,
      COUNT(*) FILTER (WHERE days_of_inventory > 14) as healthy_records,
      AVG(days_of_inventory) FILTER (WHERE days_of_inventory IS NOT NULL) as avg_days,
      SUM(qty_inventory *
        COALESCE((SELECT sales_price FROM saq_products p WHERE p.saq_code = inv.saq_code), 0)
      ) as total_value
    FROM saq_store_inventory inv
    WHERE qty_inventory > 0
  )
  SELECT
    -- OVERALL HEALTH METRICS
    ROUND(
      (SELECT COUNT(*) FROM inventory_stats WHERE qty_inventory <= 0)::numeric /
      v_total_inventory_records::numeric * 100,
      1
    ) as overall_rupture_rate,

    ROUND(
      365.0 / NULLIF((SELECT avg_days FROM inventory_health_metrics), 0),
      1
    ) as inventory_turnover_rate,

    (SELECT COUNT(DISTINCT saq_code)::INTEGER FROM saq_store_inventory) as total_skus,

    v_total_inventory_records as total_inventory_records,

    v_total_stores as total_stores,

    -- CRITICAL ISSUES (High-volume stores in rupture)
    (SELECT COUNT(*)::INTEGER
     FROM inventory_stats
     WHERE risk_category = 'critical_rupture') as critical_ruptures_high_volume,

    (SELECT COUNT(DISTINCT store_number)::INTEGER
     FROM inventory_stats
     WHERE risk_category = 'critical_rupture') as critical_ruptures_stores_affected,

    (SELECT COUNT(*)::INTEGER
     FROM sku_level_analysis
     WHERE has_critical_rupture = 1) as skus_with_critical_ruptures,

    -- ROUTINE OPERATIONS (Low-volume ruptures)
    (SELECT COUNT(*)::INTEGER
     FROM inventory_stats
     WHERE risk_category = 'routine_rupture') as routine_ruptures_low_volume,

    (SELECT COUNT(*)::INTEGER
     FROM sku_level_analysis
     WHERE has_routine_rupture = 1 AND has_critical_rupture = 0) as skus_with_routine_stockouts,

    (SELECT COUNT(*)::INTEGER
     FROM inventory_stats
     WHERE qty_inventory <= 0) as total_stockout_locations,

    -- RISK ALERTS
    (SELECT COUNT(*)::INTEGER
     FROM inventory_stats
     WHERE risk_category = 'high_risk') as high_risk_locations,

    (SELECT COUNT(*)::INTEGER
     FROM sku_level_analysis
     WHERE has_high_risk = 1 AND has_critical_rupture = 0 AND has_routine_rupture = 0) as high_risk_skus,

    (SELECT COUNT(*)::INTEGER
     FROM inventory_stats
     WHERE risk_category = 'medium_risk') as medium_risk_locations,

    (SELECT COUNT(*)::INTEGER
     FROM sku_level_analysis
     WHERE has_medium_risk = 1
       AND has_critical_rupture = 0
       AND has_routine_rupture = 0
       AND has_high_risk = 0) as medium_risk_skus,

    (SELECT COUNT(DISTINCT store_number)::INTEGER
     FROM saq_store_inventory
     WHERE is_critical = true OR is_warning = true) as stores_with_any_alerts,

    -- SALES PERFORMANCE
    (SELECT total_sales FROM sales_data) as total_weekly_sales,

    (SELECT total_bottles::INTEGER FROM sales_data) as total_bottles_sold,

    ROUND(
      (SELECT total_sales FROM sales_data) / v_total_stores::numeric,
      2
    ) as avg_sales_per_store,

    (SELECT top_sku_sales FROM sales_data) as top_selling_sku_sales,

    -- INVENTORY EFFICIENCY
    ROUND(
      (SELECT avg_days FROM inventory_health_metrics),
      1
    ) as avg_days_of_inventory,

    ROUND(
      (SELECT healthy_records::numeric / NULLIF(total_records::numeric, 0) * 100
       FROM inventory_health_metrics),
      1
    ) as healthy_inventory_pct,

    ROUND(
      COALESCE((SELECT total_value FROM inventory_health_metrics), 0),
      2
    ) as total_inventory_value;
END;
$$;

GRANT EXECUTE ON FUNCTION get_coo_summary_stats() TO anon;
GRANT EXECUTE ON FUNCTION get_coo_summary_stats() TO authenticated;

-- Test the function
-- SELECT * FROM get_coo_summary_stats();
