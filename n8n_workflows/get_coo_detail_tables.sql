-- COO Detail Tables for Drill-Down
-- Provides full traceability and verification

-- TABLE 1: Critical Ruptures Detail
CREATE OR REPLACE FUNCTION get_critical_ruptures_detail()
RETURNS TABLE (
  product_name TEXT,
  saq_code VARCHAR,
  store_number VARCHAR,
  store_name VARCHAR,
  city VARCHAR,
  region VARCHAR,
  sales_rep_name VARCHAR,
  sales_rep_email VARCHAR,
  qty_inventory INTEGER,
  avg_weekly_sales NUMERIC,
  days_of_inventory NUMERIC,
  snapshot_date DATE,
  recommended_order_qty INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.description as product_name,
    inv.saq_code,
    inv.store_number,
    s.store_name,
    s.city,
    s.region,
    s.sales_rep_name,
    s.sales_rep_email,
    inv.qty_inventory,
    inv.avg_weekly_sales,
    inv.days_of_inventory,
    inv.snapshot_date,
    -- Recommend 4 weeks of supply
    CASE
      WHEN inv.avg_weekly_sales > 0 THEN (4 * inv.avg_weekly_sales)::INTEGER
      ELSE 20
    END as recommended_order_qty
  FROM saq_store_inventory inv
  JOIN saq_products p ON inv.saq_code = p.saq_code
  JOIN saq_stores s ON inv.store_number = s.store_number
  WHERE inv.qty_inventory <= 0
    AND inv.avg_weekly_sales > 10
  ORDER BY inv.avg_weekly_sales DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION get_critical_ruptures_detail() TO anon;
GRANT EXECUTE ON FUNCTION get_critical_ruptures_detail() TO authenticated;


-- TABLE 2: Routine Stockouts Detail
CREATE OR REPLACE FUNCTION get_routine_stockouts_detail()
RETURNS TABLE (
  product_name TEXT,
  saq_code VARCHAR,
  store_number VARCHAR,
  store_name VARCHAR,
  city VARCHAR,
  region VARCHAR,
  sales_rep_name VARCHAR,
  sales_rep_email VARCHAR,
  qty_inventory INTEGER,
  avg_weekly_sales NUMERIC,
  days_of_inventory NUMERIC,
  snapshot_date DATE,
  recommended_order_qty INTEGER,
  priority TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.description as product_name,
    inv.saq_code,
    inv.store_number,
    s.store_name,
    s.city,
    s.region,
    s.sales_rep_name,
    s.sales_rep_email,
    inv.qty_inventory,
    inv.avg_weekly_sales,
    inv.days_of_inventory,
    inv.snapshot_date,
    CASE
      WHEN inv.avg_weekly_sales > 0 THEN (4 * inv.avg_weekly_sales)::INTEGER
      ELSE 10
    END as recommended_order_qty,
    CASE
      WHEN inv.avg_weekly_sales >= 5 THEN 'Medium'
      ELSE 'Low'
    END as priority
  FROM saq_store_inventory inv
  JOIN saq_products p ON inv.saq_code = p.saq_code
  JOIN saq_stores s ON inv.store_number = s.store_number
  WHERE inv.qty_inventory <= 0
    AND (inv.avg_weekly_sales <= 10 OR inv.avg_weekly_sales IS NULL)
  ORDER BY
    CASE
      WHEN inv.avg_weekly_sales >= 5 THEN 1
      ELSE 2
    END,
    inv.avg_weekly_sales DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION get_routine_stockouts_detail() TO anon;
GRANT EXECUTE ON FUNCTION get_routine_stockouts_detail() TO authenticated;


-- TABLE 3: Risk Monitoring Detail
CREATE OR REPLACE FUNCTION get_risk_monitoring_detail()
RETURNS TABLE (
  risk_level TEXT,
  product_name TEXT,
  saq_code VARCHAR,
  store_number VARCHAR,
  store_name VARCHAR,
  city VARCHAR,
  region VARCHAR,
  sales_rep_name VARCHAR,
  qty_inventory INTEGER,
  avg_weekly_sales NUMERIC,
  days_of_inventory NUMERIC,
  weeks_of_supply NUMERIC,
  recommended_order_qty INTEGER,
  forecasted_stockout_date DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    CASE
      WHEN inv.days_of_inventory < 2.5 * 7 THEN 'High Risk'
      WHEN inv.days_of_inventory >= 2.5 * 7 AND inv.days_of_inventory < 4 * 7 THEN 'Medium Risk'
    END as risk_level,
    p.description as product_name,
    inv.saq_code,
    inv.store_number,
    s.store_name,
    s.city,
    s.region,
    s.sales_rep_name,
    inv.qty_inventory,
    inv.avg_weekly_sales,
    inv.days_of_inventory,
    ROUND(inv.days_of_inventory / 7.0, 1) as weeks_of_supply,
    CASE
      WHEN inv.avg_weekly_sales > 0 THEN
        GREATEST(0, ((4 * inv.avg_weekly_sales) - inv.qty_inventory)::INTEGER)
      ELSE 0
    END as recommended_order_qty,
    CASE
      WHEN inv.avg_weekly_sales > 0 THEN
        inv.snapshot_date + (inv.days_of_inventory::INTEGER)
      ELSE NULL
    END as forecasted_stockout_date
  FROM saq_store_inventory inv
  JOIN saq_products p ON inv.saq_code = p.saq_code
  JOIN saq_stores s ON inv.store_number = s.store_number
  WHERE inv.days_of_inventory IS NOT NULL
    AND inv.days_of_inventory < 4 * 7
    AND inv.qty_inventory > 0
  ORDER BY
    CASE
      WHEN inv.days_of_inventory < 2.5 * 7 THEN 1
      ELSE 2
    END,
    inv.days_of_inventory ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_risk_monitoring_detail() TO anon;
GRANT EXECUTE ON FUNCTION get_risk_monitoring_detail() TO authenticated;


-- TABLE 4: Sales Performance by Product
CREATE OR REPLACE FUNCTION get_sales_performance_by_product()
RETURNS TABLE (
  product_name TEXT,
  saq_code VARCHAR,
  format VARCHAR,
  total_weekly_sales NUMERIC,
  total_bottles_sold INTEGER,
  stores_carrying INTEGER,
  stores_in_rupture INTEGER,
  rupture_rate_pct NUMERIC,
  avg_weekly_sales_per_store NUMERIC,
  total_inventory INTEGER,
  total_inventory_value NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH latest_week AS (
    SELECT MAX(week_start_date) as latest_week
    FROM saq_weekly_sales
  ),
  product_sales AS (
    SELECT
      ws.saq_code,
      SUM(ws.amount) as weekly_sales,
      SUM(ws.qty_bottles) as bottles_sold,
      COUNT(DISTINCT ws.store_number) as stores_selling
    FROM saq_weekly_sales ws
    CROSS JOIN latest_week lw
    WHERE ws.week_start_date = lw.latest_week
    GROUP BY ws.saq_code
  ),
  product_inventory AS (
    SELECT
      inv.saq_code,
      COUNT(DISTINCT inv.store_number) as stores_carrying,
      COUNT(*) FILTER (WHERE inv.qty_inventory <= 0) as stores_in_rupture,
      AVG(inv.avg_weekly_sales) as avg_weekly_sales,
      SUM(inv.qty_inventory) as total_inventory
    FROM saq_store_inventory inv
    GROUP BY inv.saq_code
  )
  SELECT
    p.description as product_name,
    p.saq_code,
    p.format,
    COALESCE(ps.weekly_sales, 0) as total_weekly_sales,
    COALESCE(ps.bottles_sold, 0)::INTEGER as total_bottles_sold,
    COALESCE(pi.stores_carrying, 0)::INTEGER as stores_carrying,
    COALESCE(pi.stores_in_rupture, 0)::INTEGER as stores_in_rupture,
    ROUND(
      CASE
        WHEN pi.stores_carrying > 0 THEN
          (pi.stores_in_rupture::numeric / pi.stores_carrying::numeric * 100)
        ELSE 0
      END,
      1
    ) as rupture_rate_pct,
    ROUND(COALESCE(pi.avg_weekly_sales, 0), 1) as avg_weekly_sales_per_store,
    COALESCE(pi.total_inventory, 0)::INTEGER as total_inventory,
    ROUND(COALESCE(pi.total_inventory, 0) * COALESCE(p.sales_price, 0), 2) as total_inventory_value
  FROM saq_products p
  LEFT JOIN product_sales ps ON p.saq_code = ps.saq_code
  LEFT JOIN product_inventory pi ON p.saq_code = pi.saq_code
  ORDER BY total_weekly_sales DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION get_sales_performance_by_product() TO anon;
GRANT EXECUTE ON FUNCTION get_sales_performance_by_product() TO authenticated;


-- Test queries
-- SELECT * FROM get_critical_ruptures_detail();
-- SELECT * FROM get_routine_stockouts_detail();
-- SELECT * FROM get_risk_monitoring_detail();
-- SELECT * FROM get_sales_performance_by_product();
