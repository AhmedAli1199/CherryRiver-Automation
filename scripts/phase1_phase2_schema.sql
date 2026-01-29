-- ============================================================================
-- COO COCKPIT - PHASE 1 & 2: DATA FOUNDATION + SALES FORECASTING
-- ============================================================================
-- Run this in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- PHASE 1: DATA FOUNDATION
-- ============================================================================

-- Step 1.1: Create Product Mapping Table (matches CSV structure exactly)
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS product_saq_mapping CASCADE;

CREATE TABLE product_saq_mapping (
    id SERIAL PRIMARY KEY,
    odoo_product_id INT NOT NULL,
    odoo_name VARCHAR(255),
    sku VARCHAR(50),
    code_saq VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for fast lookups
CREATE INDEX idx_product_mapping_odoo_id ON product_saq_mapping(odoo_product_id);
CREATE INDEX idx_product_mapping_saq_code ON product_saq_mapping(code_saq);

-- Make sure code_saq is unique (one SAQ code per product)
CREATE UNIQUE INDEX idx_product_mapping_saq_code_unique ON product_saq_mapping(code_saq);

COMMENT ON TABLE product_saq_mapping IS 'Links Odoo products to SAQ product codes - imported from Match Odoo X SAQ CSV';
COMMENT ON COLUMN product_saq_mapping.odoo_product_id IS 'Odoo product ID (from products table)';
COMMENT ON COLUMN product_saq_mapping.odoo_name IS 'Product name in Odoo';
COMMENT ON COLUMN product_saq_mapping.sku IS 'Product barcode/SKU';
COMMENT ON COLUMN product_saq_mapping.code_saq IS 'SAQ product code (from saq_ventes table)';


-- ============================================================================
-- PHASE 2: SALES FORECASTING
-- ============================================================================

-- Step 2.1: Create Sales Forecast Storage Table
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS sales_forecasts CASCADE;

CREATE TABLE sales_forecasts (
    id SERIAL PRIMARY KEY,
    code_saq VARCHAR(20) NOT NULL,
    odoo_product_id INT,
    forecast_date DATE NOT NULL,
    forecast_horizon INT NOT NULL,  -- 7, 14, or 30 days
    projected_bottles NUMERIC NOT NULL,
    avg_daily_sales NUMERIC,
    confidence_level NUMERIC DEFAULT 0.8,
    calculation_method VARCHAR(50) DEFAULT 'HISTORICAL_AVG',
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code_saq, forecast_date, forecast_horizon)
);

CREATE INDEX idx_sales_forecasts_code_saq ON sales_forecasts(code_saq);
CREATE INDEX idx_sales_forecasts_date ON sales_forecasts(forecast_date);
CREATE INDEX idx_sales_forecasts_horizon ON sales_forecasts(forecast_horizon);

COMMENT ON TABLE sales_forecasts IS 'Stores demand forecasts for 7/14/30 day horizons';


-- Step 2.2: Create Sales Forecast Calculation Function
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_sales_forecast(
    p_code_saq VARCHAR,
    p_forecast_days INT DEFAULT 7
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_avg_daily_sales NUMERIC;
    v_forecast NUMERIC;
    v_weeks_count INT;
BEGIN
    -- Calculate average daily sales from last 12 weeks
    -- Each week has 7 days, so we divide total bottles by (weeks * 7)
    SELECT
        SUM(bouteille),
        COUNT(DISTINCT (annee, periode, semaine))
    INTO
        v_forecast,
        v_weeks_count
    FROM saq_ventes
    WHERE code_saq = p_code_saq
        AND annee >= EXTRACT(YEAR FROM CURRENT_DATE)
        AND periode >= GREATEST(1, EXTRACT(WEEK FROM CURRENT_DATE)::INT - 12)
    GROUP BY code_saq;

    -- Calculate avg daily sales
    IF v_weeks_count > 0 AND v_forecast IS NOT NULL THEN
        v_avg_daily_sales := v_forecast / (v_weeks_count * 7.0);
    ELSE
        v_avg_daily_sales := 0;
    END IF;

    -- Forecast = avg daily sales × forecast days
    v_forecast := v_avg_daily_sales * p_forecast_days;

    RETURN COALESCE(v_forecast, 0);
END;
$$;

COMMENT ON FUNCTION calculate_sales_forecast IS 'Calculates demand forecast based on last 12 weeks of sales data';


-- Step 2.3: Create Forecast Views (7/14/30 days)
-- -------------------------------------------------------------------------

-- View: 7-day forecast for all mapped products
CREATE OR REPLACE VIEW v_sales_forecast_7d AS
SELECT
    psm.code_saq,
    psm.odoo_product_id,
    psm.odoo_name as product_name,
    psm.sku,
    calculate_sales_forecast(psm.code_saq, 7) as forecast_bottles_7d,
    calculate_sales_forecast(psm.code_saq, 7) / 7.0 as avg_daily_sales,
    CURRENT_DATE as forecast_date,
    7 as horizon_days
FROM product_saq_mapping psm
ORDER BY forecast_bottles_7d DESC;

COMMENT ON VIEW v_sales_forecast_7d IS '7-day demand forecast for all products';


-- View: 14-day forecast
CREATE OR REPLACE VIEW v_sales_forecast_14d AS
SELECT
    psm.code_saq,
    psm.odoo_product_id,
    psm.odoo_name as product_name,
    psm.sku,
    calculate_sales_forecast(psm.code_saq, 14) as forecast_bottles_14d,
    calculate_sales_forecast(psm.code_saq, 14) / 14.0 as avg_daily_sales,
    CURRENT_DATE as forecast_date,
    14 as horizon_days
FROM product_saq_mapping psm
ORDER BY forecast_bottles_14d DESC;

COMMENT ON VIEW v_sales_forecast_14d IS '14-day demand forecast for all products';


-- View: 30-day forecast
CREATE OR REPLACE VIEW v_sales_forecast_30d AS
SELECT
    psm.code_saq,
    psm.odoo_product_id,
    psm.odoo_name as product_name,
    psm.sku,
    calculate_sales_forecast(psm.code_saq, 30) as forecast_bottles_30d,
    calculate_sales_forecast(psm.code_saq, 30) / 30.0 as avg_daily_sales,
    CURRENT_DATE as forecast_date,
    30 as horizon_days
FROM product_saq_mapping psm
ORDER BY forecast_bottles_30d DESC;

COMMENT ON VIEW v_sales_forecast_30d IS '30-day demand forecast for all products';


-- Step 2.4: Create Combined Forecast Summary View
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_sales_forecast_summary AS
SELECT
    psm.code_saq,
    psm.odoo_product_id,
    psm.odoo_name as product_name,
    psm.sku,
    calculate_sales_forecast(psm.code_saq, 7) as forecast_7d,
    calculate_sales_forecast(psm.code_saq, 14) as forecast_14d,
    calculate_sales_forecast(psm.code_saq, 30) as forecast_30d,
    calculate_sales_forecast(psm.code_saq, 7) / 7.0 as avg_daily_sales,
    CURRENT_DATE as forecast_date
FROM product_saq_mapping psm
ORDER BY forecast_30d DESC;

COMMENT ON VIEW v_sales_forecast_summary IS 'All forecast horizons in one view for easy comparison';


-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check if mapping table is ready for CSV import
SELECT 'product_saq_mapping table ready for import' as status;

-- After import, run these queries to verify:
-- SELECT COUNT(*) FROM product_saq_mapping;
-- SELECT * FROM product_saq_mapping LIMIT 10;
-- SELECT * FROM v_sales_forecast_summary LIMIT 10;

-- ============================================================================
-- PHASE 1 & 2 COMPLETE
-- ============================================================================
