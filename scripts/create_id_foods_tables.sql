-- ============================================
-- ID Foods Forecast Tables
-- ============================================

-- 1. Product reference table (ID Foods products mapped to Cherry River)
CREATE TABLE IF NOT EXISTS id_foods_products (
    id SERIAL PRIMARY KEY,
    id_foods_code VARCHAR(20) NOT NULL UNIQUE,
    product_name VARCHAR(255) NOT NULL,
    odoo_product_id INTEGER,              -- link to Odoo once mapped
    saq_code VARCHAR(20),                 -- if same product also sold via SAQ
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Forecast data (unpivoted: one row per product per month)
CREATE TABLE IF NOT EXISTS id_foods_forecasts (
    id SERIAL PRIMARY KEY,
    id_foods_code VARCHAR(20) NOT NULL REFERENCES id_foods_products(id_foods_code),
    forecast_year INTEGER NOT NULL,
    forecast_month INTEGER NOT NULL,       -- 1-12
    qty_forecast INTEGER DEFAULT 0,        -- units from ID Foods forecast
    forecast_version TIMESTAMPTZ NOT NULL,  -- when this forecast was received (groups a batch)
    uploaded_by VARCHAR(100),              -- e.g. "Alyssa"
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(id_foods_code, forecast_year, forecast_month, forecast_version)
);

CREATE INDEX IF NOT EXISTS idx_idf_code ON id_foods_forecasts(id_foods_code);
CREATE INDEX IF NOT EXISTS idx_idf_period ON id_foods_forecasts(forecast_year, forecast_month);
CREATE INDEX IF NOT EXISTS idx_idf_version ON id_foods_forecasts(forecast_version);

-- 3. Actual orders received from ID Foods (to compare forecast vs actual)
CREATE TABLE IF NOT EXISTS id_foods_actuals (
    id SERIAL PRIMARY KEY,
    id_foods_code VARCHAR(20) NOT NULL REFERENCES id_foods_products(id_foods_code),
    order_number VARCHAR(50),
    order_date DATE,
    qty_ordered INTEGER DEFAULT 0,
    order_year INTEGER NOT NULL,
    order_month INTEGER NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ida_code ON id_foods_actuals(id_foods_code);
CREATE INDEX IF NOT EXISTS idx_ida_period ON id_foods_actuals(order_year, order_month);


-- ============================================
-- Dashboard View: ID Foods Forecast vs Actual
-- ============================================
CREATE OR REPLACE VIEW v_id_foods_forecast AS
WITH latest_forecast AS (
    SELECT
        id_foods_code,
        forecast_year,
        forecast_month,
        qty_forecast,
        forecast_version
    FROM id_foods_forecasts
    WHERE forecast_version = (
        SELECT MAX(forecast_version) FROM id_foods_forecasts
    )
),
actuals AS (
    SELECT
        id_foods_code,
        order_year,
        order_month,
        SUM(qty_ordered) as qty_actual
    FROM id_foods_actuals
    GROUP BY id_foods_code, order_year, order_month
)
SELECT
    f.id_foods_code,
    p.product_name,
    f.forecast_year,
    f.forecast_month,
    TO_CHAR(TO_DATE(f.forecast_month::text, 'MM'), 'TMMonth') as mois,
    f.qty_forecast,
    COALESCE(a.qty_actual, 0) as qty_actual,
    COALESCE(a.qty_actual, 0) - f.qty_forecast as ecart,
    CASE
        WHEN f.forecast_month < EXTRACT(MONTH FROM CURRENT_DATE)
             AND f.forecast_year <= EXTRACT(YEAR FROM CURRENT_DATE)
        THEN 'Passé'
        WHEN f.forecast_month = EXTRACT(MONTH FROM CURRENT_DATE)
             AND f.forecast_year = EXTRACT(YEAR FROM CURRENT_DATE)
        THEN 'En cours'
        ELSE 'À venir'
    END as statut_mois,
    f.forecast_version
FROM latest_forecast f
JOIN id_foods_products p ON f.id_foods_code = p.id_foods_code
LEFT JOIN actuals a ON f.id_foods_code = a.id_foods_code
    AND f.forecast_year = a.order_year
    AND f.forecast_month = a.order_month
ORDER BY f.id_foods_code, f.forecast_year, f.forecast_month;


-- ============================================
-- Dashboard View: ID Foods YTD Summary
-- ============================================
CREATE OR REPLACE VIEW v_id_foods_ytd AS
WITH latest_forecast AS (
    SELECT id_foods_code, forecast_year, forecast_month, qty_forecast
    FROM id_foods_forecasts
    WHERE forecast_version = (SELECT MAX(forecast_version) FROM id_foods_forecasts)
),
ytd_forecast AS (
    SELECT
        id_foods_code,
        forecast_year,
        SUM(qty_forecast) as ytd_forecast
    FROM latest_forecast
    WHERE forecast_month <= EXTRACT(MONTH FROM CURRENT_DATE)
    GROUP BY id_foods_code, forecast_year
),
full_year_forecast AS (
    SELECT
        id_foods_code,
        forecast_year,
        SUM(qty_forecast) as total_year_forecast
    FROM latest_forecast
    GROUP BY id_foods_code, forecast_year
),
ytd_actual AS (
    SELECT
        id_foods_code,
        order_year,
        SUM(qty_ordered) as ytd_actual
    FROM id_foods_actuals
    WHERE order_month <= EXTRACT(MONTH FROM CURRENT_DATE)
    GROUP BY id_foods_code, order_year
)
SELECT
    p.id_foods_code,
    p.product_name,
    yf.forecast_year as annee,
    COALESCE(yf.ytd_forecast, 0) as ytd_prevision,
    COALESCE(ya.ytd_actual, 0) as ytd_reel,
    COALESCE(ya.ytd_actual, 0) - COALESCE(yf.ytd_forecast, 0) as ytd_ecart,
    CASE
        WHEN COALESCE(yf.ytd_forecast, 0) = 0 THEN NULL
        ELSE ROUND(((COALESCE(ya.ytd_actual, 0) - yf.ytd_forecast)::numeric / yf.ytd_forecast) * 100, 1)
    END as ytd_ecart_pct,
    COALESCE(ff.total_year_forecast, 0) as prevision_annuelle
FROM id_foods_products p
LEFT JOIN ytd_forecast yf ON p.id_foods_code = yf.id_foods_code
LEFT JOIN full_year_forecast ff ON p.id_foods_code = ff.id_foods_code AND yf.forecast_year = ff.forecast_year
LEFT JOIN ytd_actual ya ON p.id_foods_code = ya.id_foods_code AND yf.forecast_year = ya.order_year
ORDER BY p.product_name;
