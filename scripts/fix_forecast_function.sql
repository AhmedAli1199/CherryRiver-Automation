-- ============================================================================
-- FIX: Sales Forecast Function
-- ============================================================================
-- The original function was filtering by current year (2026) but data is in 2025
-- This fixes it to look at the last 12 weeks of ACTUAL data regardless of year
-- ============================================================================

DROP FUNCTION IF EXISTS calculate_sales_forecast(VARCHAR, INT);

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
    v_total_bottles NUMERIC;
    v_weeks_count INT;
BEGIN
    -- Get the last 12 weeks of sales data (regardless of year)
    -- Just take the most recent 12 distinct week records
    WITH recent_weeks AS (
        SELECT
            annee,
            periode,
            semaine,
            SUM(bouteille) as week_total
        FROM saq_ventes
        WHERE code_saq = p_code_saq
        GROUP BY annee, periode, semaine
        ORDER BY annee DESC, periode DESC, semaine DESC
        LIMIT 12
    )
    SELECT
        SUM(week_total),
        COUNT(*)
    INTO
        v_total_bottles,
        v_weeks_count
    FROM recent_weeks;

    -- Calculate average daily sales
    IF v_weeks_count > 0 AND v_total_bottles IS NOT NULL THEN
        -- Divide total bottles by (weeks × 7 days)
        v_avg_daily_sales := v_total_bottles / (v_weeks_count * 7.0);
    ELSE
        v_avg_daily_sales := 0;
    END IF;

    -- Forecast = avg daily sales × forecast days
    v_forecast := v_avg_daily_sales * p_forecast_days;

    RETURN COALESCE(v_forecast, 0);
END;
$$;

COMMENT ON FUNCTION calculate_sales_forecast IS 'Calculates demand forecast based on last 12 weeks of actual sales data';

-- ============================================================================
-- VERIFY THE FIX
-- ============================================================================

-- Test the function with a high-volume product
SELECT
    calculate_sales_forecast('15474217', 7) as forecast_7d,
    calculate_sales_forecast('15474217', 14) as forecast_14d,
    calculate_sales_forecast('15474217', 30) as forecast_30d;

-- Should return non-zero values now
-- ============================================================================
