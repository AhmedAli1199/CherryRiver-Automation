-- Supabase RPC Function to Get Inventory Alerts
-- This function can be called via REST API without needing database password
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION get_inventory_alerts()
RETURNS TABLE (
  id BIGINT,
  saq_code VARCHAR,
  store_number VARCHAR,
  qty_inventory INTEGER,
  avg_weekly_sales NUMERIC,
  days_of_inventory NUMERIC,
  is_warning BOOLEAN,
  is_critical BOOLEAN,
  snapshot_date DATE,
  product_name TEXT,
  format VARCHAR,
  category VARCHAR,
  store_name VARCHAR,
  store_city VARCHAR,
  store_region VARCHAR,
  representative_name VARCHAR,
  representative_email VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    inv.id,
    inv.saq_code,
    inv.store_number,
    inv.qty_inventory,
    inv.avg_weekly_sales,
    inv.days_of_inventory,
    inv.is_warning,
    inv.is_critical,
    inv.snapshot_date,
    p.description AS product_name,
    p.format,
    p.status AS category,
    s.store_name,
    s.city AS store_city,
    s.region AS store_region,
    s.sales_rep_name AS representative_name,
    s.sales_rep_email AS representative_email
  FROM saq_store_inventory inv
  JOIN saq_products p ON inv.saq_code = p.saq_code
  JOIN saq_stores s ON inv.store_number = s.store_number
  WHERE (inv.is_critical = true OR inv.is_warning = true)
    AND s.sales_rep_email IS NOT NULL
    AND s.sales_rep_email != ''
  ORDER BY
    s.sales_rep_email,
    inv.is_critical DESC,
    inv.days_of_inventory ASC NULLS FIRST;
END;
$$;

-- Grant execute permission to anon role (API key access)
GRANT EXECUTE ON FUNCTION get_inventory_alerts() TO anon;
GRANT EXECUTE ON FUNCTION get_inventory_alerts() TO authenticated;

-- Test the function
-- SELECT * FROM get_inventory_alerts();
