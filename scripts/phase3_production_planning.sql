-- ============================================================================
-- COO COCKPIT - PHASE 3: PRODUCTION PLANNING (USES EXISTING ODOO DATA)
-- ============================================================================
-- Prerequisites:
--   - Phase 1 & 2 complete (product mapping + forecasts working)
--   - Odoo data already synced via n8n (products, lead_times tables)
-- ============================================================================

-- ============================================================================
-- STEP 3.1: Current Inventory View (Uses REAL Odoo Data)
-- ============================================================================

CREATE OR REPLACE VIEW v_current_inventory AS
SELECT
    psm.odoo_product_id,
    psm.code_saq,
    psm.odoo_name as product_name,

    -- Cherry River stock from Odoo products table
    COALESCE(p.qty_available, 0)::INT as cherry_river_stock_bottles,

    -- SAQ warehouse inventory (from actual SAQ data)
    COALESCE(
        (
            SELECT SUM(sie.qty * 12)  -- Assume 12 bottles/case for now
            FROM saq_inventaire_entrepot sie
            WHERE sie.code_saq = psm.code_saq
                AND (sie.annee, sie.periode, sie.semaine) = (
                    SELECT annee, periode, semaine
                    FROM saq_inventaire_entrepot
                    WHERE code_saq = psm.code_saq
                    ORDER BY annee DESC, periode DESC, semaine DESC
                    LIMIT 1
                )
        ), 0
    )::INT as saq_warehouse_bottles,

    -- Total available inventory
    COALESCE(p.qty_available, 0)::INT + COALESCE(
        (
            SELECT SUM(sie.qty * 12)
            FROM saq_inventaire_entrepot sie
            WHERE sie.code_saq = psm.code_saq
                AND (sie.annee, sie.periode, sie.semaine) = (
                    SELECT annee, periode, semaine
                    FROM saq_inventaire_entrepot
                    WHERE code_saq = psm.code_saq
                    ORDER BY annee DESC, periode DESC, semaine DESC
                    LIMIT 1
                )
        ), 0
    )::INT as total_available_bottles,

    -- Production parameters from Odoo
    COALESCE(p.x_min_stock, 0)::INT as safety_stock,
    COALESCE(p.x_lead_time_days,
             COALESCE(lt.lead_time_days::INT, 7)) as lead_time_days

FROM product_saq_mapping psm
LEFT JOIN products p ON p.id = psm.odoo_product_id
LEFT JOIN lead_times lt ON lt.product_id = psm.odoo_product_id;

COMMENT ON VIEW v_current_inventory IS 'Real-time inventory - uses Odoo products.qty_available + SAQ warehouse data';


-- ============================================================================
-- STEP 3.2: Production Plans Table
-- ============================================================================

DROP TABLE IF EXISTS production_plans CASCADE;

CREATE TABLE production_plans (
    id SERIAL PRIMARY KEY,
    odoo_product_id INT NOT NULL,
    code_saq VARCHAR(20),
    product_name VARCHAR(255),
    plan_date DATE NOT NULL,
    horizon_days INT NOT NULL,

    -- Current state (from REAL Odoo + SAQ data)
    cherry_river_stock_bottles INT DEFAULT 0,
    saq_warehouse_stock_bottles INT DEFAULT 0,
    total_available_bottles INT DEFAULT 0,

    -- Forecast demand (from Phase 2)
    forecasted_demand_bottles NUMERIC NOT NULL,
    avg_daily_sales NUMERIC,

    -- Production recommendation
    recommended_production_bottles INT NOT NULL,
    production_priority VARCHAR(20) DEFAULT 'MEDIUM',
    stockout_risk BOOLEAN DEFAULT FALSE,
    days_until_stockout INT,

    -- Production schedule
    production_start_date DATE,
    production_completion_date DATE,

    -- Production parameters used (from Odoo)
    safety_stock_used INT,
    lead_time_used INT,

    calculated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(odoo_product_id, plan_date, horizon_days)
);

CREATE INDEX idx_production_plans_product ON production_plans(odoo_product_id);
CREATE INDEX idx_production_plans_date ON production_plans(plan_date);
CREATE INDEX idx_production_plans_priority ON production_plans(production_priority);
CREATE INDEX idx_production_plans_stockout ON production_plans(stockout_risk);

COMMENT ON TABLE production_plans IS 'Production plans using REAL Odoo inventory + SAQ forecasts';


-- ============================================================================
-- STEP 3.3: Production Planning Function
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_production_plan(
    p_odoo_product_id INT,
    p_horizon_days INT DEFAULT 14
)
RETURNS TABLE (
    product_id INT,
    product_name VARCHAR,
    cherry_river_stock INT,
    saq_warehouse_stock INT,
    total_available INT,
    forecasted_demand NUMERIC,
    recommended_production INT,
    priority VARCHAR,
    stockout_risk BOOLEAN,
    days_until_stockout INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_code_saq VARCHAR(20);
    v_product_name VARCHAR(255);
    v_forecast NUMERIC;
    v_avg_daily_sales NUMERIC;
    v_cherry_river_stock INT;
    v_saq_warehouse_stock INT;
    v_total_available INT;
    v_safety_stock INT;
    v_lead_time INT;
    v_needed INT;
    v_recommended INT;
    v_priority VARCHAR(20);
    v_stockout_risk BOOLEAN := FALSE;
    v_days_until_stockout INT;
BEGIN
    -- Get product info
    SELECT code_saq, odoo_name
    INTO v_code_saq, v_product_name
    FROM product_saq_mapping
    WHERE odoo_product_id = p_odoo_product_id;

    IF v_code_saq IS NULL THEN
        RAISE EXCEPTION 'Product % not found in product_saq_mapping', p_odoo_product_id;
    END IF;

    -- Get forecast from Phase 2
    v_forecast := calculate_sales_forecast(v_code_saq, p_horizon_days);
    v_avg_daily_sales := v_forecast / p_horizon_days::NUMERIC;

    -- Get REAL inventory and parameters from Odoo
    SELECT
        cherry_river_stock_bottles,
        saq_warehouse_bottles,
        total_available_bottles,
        safety_stock,
        lead_time_days
    INTO
        v_cherry_river_stock,
        v_saq_warehouse_stock,
        v_total_available,
        v_safety_stock,
        v_lead_time
    FROM v_current_inventory
    WHERE odoo_product_id = p_odoo_product_id;

    IF v_lead_time IS NULL THEN
        RAISE NOTICE 'No lead time data for product %. Using default 7 days.', p_odoo_product_id;
        v_lead_time := 7;
        v_safety_stock := 0;
    END IF;

    -- Calculate days until stockout
    IF v_avg_daily_sales > 0 THEN
        v_days_until_stockout := FLOOR(v_total_available / v_avg_daily_sales);
    ELSE
        v_days_until_stockout := 999;
    END IF;

    -- Determine stockout risk
    v_stockout_risk := v_days_until_stockout < v_lead_time;

    -- Calculate production need
    -- Formula: (Forecast + Safety Stock) - Current Available
    v_needed := (v_forecast::INT + v_safety_stock) - v_total_available;

    -- Determine priority and recommendation
    IF v_needed <= 0 THEN
        v_recommended := 0;
        v_priority := 'NONE';
    ELSIF v_stockout_risk THEN
        v_recommended := v_needed;
        v_priority := 'HIGH';
    ELSIF v_needed > 0 THEN
        v_recommended := v_needed;
        v_priority := 'MEDIUM';
    ELSE
        v_recommended := 0;
        v_priority := 'LOW';
    END IF;

    -- Return results
    RETURN QUERY SELECT
        p_odoo_product_id,
        v_product_name,
        v_cherry_river_stock,
        v_saq_warehouse_stock,
        v_total_available,
        v_forecast,
        v_recommended,
        v_priority,
        v_stockout_risk,
        v_days_until_stockout;
END;
$$;

COMMENT ON FUNCTION generate_production_plan IS 'Uses Odoo inventory + SAQ forecasts for production planning';


-- ============================================================================
-- STEP 3.4: Generate Production Plans for All Products
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_all_production_plans(
    p_horizon_days INT DEFAULT 14
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT := 0;
    v_product RECORD;
    v_plan RECORD;
BEGIN
    -- Loop through all mapped products
    FOR v_product IN
        SELECT DISTINCT
            psm.odoo_product_id,
            psm.odoo_name,
            psm.code_saq
        FROM product_saq_mapping psm
        ORDER BY psm.odoo_product_id
    LOOP
        BEGIN
            -- Generate plan for this product
            FOR v_plan IN
                SELECT * FROM generate_production_plan(v_product.odoo_product_id, p_horizon_days)
            LOOP
                -- Get lead time from view
                DECLARE
                    v_lead_time INT;
                    v_safety_stock INT;
                BEGIN
                    SELECT lead_time_days, safety_stock
                    INTO v_lead_time, v_safety_stock
                    FROM v_current_inventory
                    WHERE odoo_product_id = v_product.odoo_product_id;

                    -- Insert or update production plan
                    INSERT INTO production_plans (
                        odoo_product_id,
                        code_saq,
                        product_name,
                        plan_date,
                        horizon_days,
                        cherry_river_stock_bottles,
                        saq_warehouse_stock_bottles,
                        total_available_bottles,
                        forecasted_demand_bottles,
                        avg_daily_sales,
                        recommended_production_bottles,
                        production_priority,
                        stockout_risk,
                        days_until_stockout,
                        production_start_date,
                        production_completion_date,
                        safety_stock_used,
                        lead_time_used
                    ) VALUES (
                        v_product.odoo_product_id,
                        v_product.code_saq,
                        v_plan.product_name,
                        CURRENT_DATE,
                        p_horizon_days,
                        v_plan.cherry_river_stock,
                        v_plan.saq_warehouse_stock,
                        v_plan.total_available,
                        v_plan.forecasted_demand,
                        v_plan.forecasted_demand / p_horizon_days::NUMERIC,
                        v_plan.recommended_production,
                        v_plan.priority,
                        v_plan.stockout_risk,
                        v_plan.days_until_stockout,
                        CURRENT_DATE,
                        CURRENT_DATE + COALESCE(v_lead_time, 7),
                        v_safety_stock,
                        v_lead_time
                    )
                    ON CONFLICT (odoo_product_id, plan_date, horizon_days)
                    DO UPDATE SET
                        cherry_river_stock_bottles = EXCLUDED.cherry_river_stock_bottles,
                        saq_warehouse_stock_bottles = EXCLUDED.saq_warehouse_stock_bottles,
                        total_available_bottles = EXCLUDED.total_available_bottles,
                        forecasted_demand_bottles = EXCLUDED.forecasted_demand_bottles,
                        avg_daily_sales = EXCLUDED.avg_daily_sales,
                        recommended_production_bottles = EXCLUDED.recommended_production_bottles,
                        production_priority = EXCLUDED.production_priority,
                        stockout_risk = EXCLUDED.stockout_risk,
                        days_until_stockout = EXCLUDED.days_until_stockout,
                        production_completion_date = EXCLUDED.production_completion_date,
                        safety_stock_used = EXCLUDED.safety_stock_used,
                        lead_time_used = EXCLUDED.lead_time_used,
                        calculated_at = NOW();
                END;

                v_count := v_count + 1;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Failed to generate plan for product %: %', v_product.odoo_product_id, SQLERRM;
        END;
    END LOOP;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION generate_all_production_plans IS 'Batch generates plans for all products using live Odoo data';


-- ============================================================================
-- STEP 3.5: Production Planning Views
-- ============================================================================

-- View: High Priority Production (Stockout Risk)
CREATE OR REPLACE VIEW v_production_high_priority AS
SELECT
    pp.odoo_product_id,
    pp.product_name,
    pp.code_saq,
    pp.cherry_river_stock_bottles,
    pp.saq_warehouse_stock_bottles,
    pp.total_available_bottles,
    pp.forecasted_demand_bottles,
    pp.recommended_production_bottles,
    pp.days_until_stockout,
    pp.production_completion_date,
    pp.safety_stock_used,
    pp.lead_time_used,
    psm.sku
FROM production_plans pp
JOIN product_saq_mapping psm ON pp.odoo_product_id = psm.odoo_product_id
WHERE pp.production_priority = 'HIGH'
    AND pp.plan_date = CURRENT_DATE
ORDER BY pp.days_until_stockout ASC, pp.forecasted_demand_bottles DESC;

COMMENT ON VIEW v_production_high_priority IS 'URGENT: Products at risk of stockout - START PRODUCTION TODAY';


-- View: Production Summary (All Products)
CREATE OR REPLACE VIEW v_production_summary AS
SELECT
    pp.odoo_product_id,
    pp.product_name,
    pp.code_saq,
    pp.cherry_river_stock_bottles,
    pp.saq_warehouse_stock_bottles,
    pp.total_available_bottles,
    pp.forecasted_demand_bottles,
    pp.recommended_production_bottles,
    pp.production_priority,
    pp.stockout_risk,
    pp.days_until_stockout,
    pp.production_completion_date,
    pp.safety_stock_used,
    pp.lead_time_used,
    psm.sku
FROM production_plans pp
JOIN product_saq_mapping psm ON pp.odoo_product_id = psm.odoo_product_id
WHERE pp.plan_date = CURRENT_DATE
    AND pp.horizon_days = 14
ORDER BY
    CASE pp.production_priority
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'LOW' THEN 3
        ELSE 4
    END,
    pp.forecasted_demand_bottles DESC;

COMMENT ON VIEW v_production_summary IS 'Production overview using live Odoo inventory + SAQ forecasts';


-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 'Phase 3 schema created - Using existing Odoo data!' as status;

-- ============================================================================
-- READY TO USE - NO ADDITIONAL DATA NEEDED
-- ============================================================================
--
-- This implementation uses:
-- - Odoo products.qty_available (Cherry River inventory)
-- - Odoo products.x_min_stock (safety stock)
-- - Odoo products.x_lead_time_days OR lead_times.lead_time_days (lead times)
-- - SAQ saq_inventaire_entrepot (SAQ warehouse inventory)
-- - Phase 2 forecasts (sales predictions)
--
-- Run: SELECT generate_all_production_plans(14);
-- Review: SELECT * FROM v_production_summary;
--
-- ============================================================================
