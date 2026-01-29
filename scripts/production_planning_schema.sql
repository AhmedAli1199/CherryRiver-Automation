-- ============================================================
-- CHERRY RIVER COO COCKPIT - PRODUCTION PLANNING SCHEMA
-- ============================================================
-- This script creates all tables and views needed for:
-- 1. Production Planning Module
-- 2. Purchase Planning Module
-- 3. Production Calendar Module
--
-- Run this in Supabase SQL Editor after SAQ-Odoo mapping is complete
-- ============================================================

-- ============================================================
-- SECTION 1: PRODUCTION PLANNING TABLES
-- ============================================================

-- Table 1: Production Plan (Master planning table)
CREATE TABLE IF NOT EXISTS production_plan (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    saq_code VARCHAR(20) REFERENCES saq_product(code_saq),
    product_name TEXT NOT NULL,
    recommended_quantity NUMERIC NOT NULL,
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('URGENT', 'SHORT-TERM', 'MID-TERM')),
    priority_score NUMERIC, -- Higher = more urgent
    reason TEXT,
    horizon_days INT NOT NULL CHECK (horizon_days IN (7, 14, 30)),
    current_stock NUMERIC DEFAULT 0,
    forecasted_demand NUMERIC DEFAULT 0,
    production_deadline DATE,
    is_feasible BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_production_plan_priority ON production_plan(priority_score DESC);
CREATE INDEX idx_production_plan_horizon ON production_plan(horizon_days);
CREATE INDEX idx_production_plan_deadline ON production_plan(production_deadline);

COMMENT ON TABLE production_plan IS 'Recommended production quantities by SKU with priorities';
COMMENT ON COLUMN production_plan.priority_score IS 'Calculated urgency score: higher = more urgent';
COMMENT ON COLUMN production_plan.horizon_days IS 'Planning horizon: 7, 14, or 30 days';

-- ============================================================
-- Table 2: Packaging Requirements
CREATE TABLE IF NOT EXISTS packaging_requirements (
    id SERIAL PRIMARY KEY,
    production_plan_id INT REFERENCES production_plan(id) ON DELETE CASCADE,
    packaging_item_id INT REFERENCES products(id),
    packaging_item_name TEXT NOT NULL,
    packaging_type VARCHAR(50) CHECK (packaging_type IN ('bottle', 'can', 'closure', 'lid', 'carton')),
    required_quantity NUMERIC NOT NULL,
    on_hand_quantity NUMERIC NOT NULL DEFAULT 0,
    gap NUMERIC GENERATED ALWAYS AS (required_quantity - on_hand_quantity) STORED,
    lead_time_days INT,
    supplier_name TEXT,
    supplier_contact TEXT,
    action_required VARCHAR(20) GENERATED ALWAYS AS (
        CASE
            WHEN required_quantity - on_hand_quantity > 0 THEN 'TO ORDER'
            ELSE 'OK'
        END
    ) STORED,
    order_by_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_packaging_action ON packaging_requirements(action_required);
CREATE INDEX idx_packaging_type ON packaging_requirements(packaging_type);
CREATE INDEX idx_packaging_gap ON packaging_requirements(gap) WHERE gap > 0;

COMMENT ON TABLE packaging_requirements IS 'Packaging components needed for production plan';
COMMENT ON COLUMN packaging_requirements.gap IS 'Auto-calculated: required - on_hand';
COMMENT ON COLUMN packaging_requirements.action_required IS 'Auto-calculated: TO ORDER if gap > 0';

-- ============================================================
-- Table 3: Raw Material Requirements
CREATE TABLE IF NOT EXISTS raw_material_requirements (
    id SERIAL PRIMARY KEY,
    production_plan_id INT REFERENCES production_plan(id) ON DELETE CASCADE,
    material_id INT REFERENCES products(id),
    material_name TEXT NOT NULL,
    material_type VARCHAR(50) CHECK (material_type IN ('alcohol', 'ingredient', 'flavor', 'juice', 'other')),
    required_quantity NUMERIC NOT NULL,
    unit_of_measure VARCHAR(20) NOT NULL, -- 'L', 'kg', 'units'
    on_hand_quantity NUMERIC NOT NULL DEFAULT 0,
    gap NUMERIC GENERATED ALWAYS AS (required_quantity - on_hand_quantity) STORED,
    lead_time_days INT,
    supplier_name TEXT,
    supplier_contact TEXT,
    action_required VARCHAR(20) GENERATED ALWAYS AS (
        CASE
            WHEN required_quantity - on_hand_quantity > 0 THEN 'TO ORDER'
            ELSE 'OK'
        END
    ) STORED,
    order_by_date DATE,
    minimum_order_qty NUMERIC,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_material_action ON raw_material_requirements(action_required);
CREATE INDEX idx_material_type ON raw_material_requirements(material_type);
CREATE INDEX idx_material_gap ON raw_material_requirements(gap) WHERE gap > 0;

COMMENT ON TABLE raw_material_requirements IS 'Raw materials and ingredients needed for production';
COMMENT ON COLUMN raw_material_requirements.unit_of_measure IS 'L (liters), kg (kilograms), or units';

-- ============================================================
-- Table 4: Production Schedule (Calendar)
CREATE TABLE IF NOT EXISTS production_schedule (
    id SERIAL PRIMARY KEY,
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,
    product_id INT REFERENCES products(id),
    saq_code VARCHAR(20),
    product_name TEXT NOT NULL,
    planned_quantity NUMERIC NOT NULL,
    production_time_hours NUMERIC,
    assigned_to TEXT, -- Production team member or shift
    status VARCHAR(20) DEFAULT 'PLANNED' CHECK (status IN ('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_schedule_week ON production_schedule(week_start_date);
CREATE INDEX idx_schedule_status ON production_schedule(status);
CREATE INDEX idx_schedule_product ON production_schedule(product_id);

COMMENT ON TABLE production_schedule IS 'Weekly production schedule with assignments';

-- ============================================================
-- Table 5: Production Capacity
CREATE TABLE IF NOT EXISTS production_capacity (
    id SERIAL PRIMARY KEY,
    week_start_date DATE NOT NULL UNIQUE,
    max_bottles_per_week INT NOT NULL DEFAULT 12000,
    max_liters_per_week NUMERIC,
    available_production_hours NUMERIC,
    current_utilization_pct NUMERIC,
    is_holiday BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_capacity_week ON production_capacity(week_start_date);

COMMENT ON TABLE production_capacity IS 'Weekly production capacity limits and utilization';
COMMENT ON COLUMN production_capacity.max_bottles_per_week IS 'Maximum bottles that can be produced in this week';

-- ============================================================
-- SECTION 2: DASHBOARD VIEWS
-- ============================================================

-- ============================================================
-- View 1: Production Plan Summary
-- Shows all recommended productions with priorities
-- ============================================================
CREATE OR REPLACE VIEW v_production_plan_summary AS
SELECT
    pp.id,
    pp.saq_code,
    pp.product_name,
    pp.recommended_quantity,
    pp.priority,
    pp.priority_score,
    pp.horizon_days,
    pp.current_stock,
    pp.forecasted_demand,
    pp.production_deadline,
    pp.reason,
    -- Days until deadline
    pp.production_deadline - CURRENT_DATE as days_until_deadline,
    -- Odoo product info (if mapped)
    p.id as odoo_product_id,
    p.qty_available as odoo_qty_available,
    p.virtual_available as odoo_virtual_available,
    p.incoming_qty as odoo_incoming_qty,
    p.outgoing_qty as odoo_outgoing_qty,
    -- SAQ warehouse inventory
    w.inventaire_cdm as warehouse_mtl_cases,
    w.inventaire_cdq as warehouse_qc_cases,
    (w.inventaire_cdm + w.inventaire_cdq) * COALESCE(w.uvc, 12) as total_warehouse_bottles,
    -- Is this production still needed?
    CASE
        WHEN pp.current_stock >= pp.forecasted_demand THEN FALSE
        ELSE TRUE
    END as still_needed,
    -- Status indicator
    CASE
        WHEN pp.priority = 'URGENT' AND pp.production_deadline - CURRENT_DATE <= 7 THEN '🔴 CRITICAL'
        WHEN pp.priority = 'SHORT-TERM' AND pp.production_deadline - CURRENT_DATE <= 14 THEN '🟡 WARNING'
        ELSE '🟢 OK'
    END as status_indicator,
    pp.created_at,
    pp.updated_at
FROM production_plan pp
LEFT JOIN saq_product sp ON pp.saq_code = sp.code_saq
LEFT JOIN products p ON sp.odoo_product_id = p.id
LEFT JOIN saq_daily_warehouse w ON pp.saq_code = w.code_saq
WHERE pp.is_feasible = TRUE
ORDER BY pp.priority_score DESC, pp.production_deadline ASC;

COMMENT ON VIEW v_production_plan_summary IS 'Production priorities with Odoo and SAQ inventory context';

-- ============================================================
-- View 2: Packaging Requirements Summary
-- Aggregates all packaging needs across all productions
-- ============================================================
CREATE OR REPLACE VIEW v_packaging_requirements_summary AS
SELECT
    pr.packaging_type,
    pr.packaging_item_name,
    SUM(pr.required_quantity) as total_required,
    MAX(pr.on_hand_quantity) as current_stock,
    SUM(pr.gap) as total_gap,
    MAX(pr.lead_time_days) as lead_time_days,
    pr.supplier_name,
    pr.supplier_contact,
    CASE
        WHEN SUM(pr.gap) > 0 THEN 'TO ORDER'
        ELSE 'OK'
    END as status,
    -- Calculate order deadline (earliest needed date - lead time)
    MIN(pr.order_by_date) as order_by_date,
    -- Days until order deadline
    MIN(pr.order_by_date) - CURRENT_DATE as days_until_order,
    -- How many productions need this item
    COUNT(DISTINCT pr.production_plan_id) as num_productions_affected,
    -- Priority indicator
    CASE
        WHEN MIN(pr.order_by_date) - CURRENT_DATE <= 3 THEN '🔴 ORDER NOW'
        WHEN MIN(pr.order_by_date) - CURRENT_DATE <= 7 THEN '🟡 ORDER SOON'
        ELSE '🟢 OK'
    END as urgency
FROM packaging_requirements pr
WHERE pr.gap > 0 -- Only show items that need ordering
GROUP BY pr.packaging_type, pr.packaging_item_name, pr.supplier_name, pr.supplier_contact
ORDER BY MIN(pr.order_by_date) ASC, SUM(pr.gap) DESC;

COMMENT ON VIEW v_packaging_requirements_summary IS 'Consolidated packaging needs with order urgency';

-- ============================================================
-- View 3: Raw Material Requirements Summary
-- Aggregates all raw material needs across all productions
-- ============================================================
CREATE OR REPLACE VIEW v_raw_material_requirements_summary AS
SELECT
    rmr.material_type,
    rmr.material_name,
    SUM(rmr.required_quantity) as total_required,
    rmr.unit_of_measure,
    MAX(rmr.on_hand_quantity) as current_stock,
    SUM(rmr.gap) as total_gap,
    MAX(rmr.lead_time_days) as lead_time_days,
    rmr.supplier_name,
    rmr.supplier_contact,
    MAX(rmr.minimum_order_qty) as moq,
    CASE
        WHEN SUM(rmr.gap) > 0 THEN 'TO ORDER'
        ELSE 'OK'
    END as status,
    MIN(rmr.order_by_date) as order_by_date,
    MIN(rmr.order_by_date) - CURRENT_DATE as days_until_order,
    COUNT(DISTINCT rmr.production_plan_id) as num_productions_affected,
    CASE
        WHEN MIN(rmr.order_by_date) - CURRENT_DATE <= 3 THEN '🔴 ORDER NOW'
        WHEN MIN(rmr.order_by_date) - CURRENT_DATE <= 7 THEN '🟡 ORDER SOON'
        ELSE '🟢 OK'
    END as urgency
FROM raw_material_requirements rmr
WHERE rmr.gap > 0
GROUP BY rmr.material_type, rmr.material_name, rmr.unit_of_measure, rmr.supplier_name, rmr.supplier_contact
ORDER BY MIN(rmr.order_by_date) ASC, SUM(rmr.gap) DESC;

COMMENT ON VIEW v_raw_material_requirements_summary IS 'Consolidated raw material needs with order urgency';

-- ============================================================
-- View 4: Production Calendar Weekly
-- Shows weekly production schedule with capacity utilization
-- ============================================================
CREATE OR REPLACE VIEW v_production_calendar AS
WITH weekly_totals AS (
    SELECT
        week_start_date,
        SUM(planned_quantity) as total_planned_bottles,
        SUM(production_time_hours) as total_planned_hours,
        COUNT(*) as num_productions
    FROM production_schedule
    WHERE status IN ('PLANNED', 'IN_PROGRESS')
    GROUP BY week_start_date
)
SELECT
    ps.id,
    ps.week_start_date,
    ps.week_end_date,
    ps.saq_code,
    ps.product_name,
    ps.planned_quantity,
    ps.production_time_hours,
    ps.assigned_to,
    ps.status,
    ps.notes,
    -- Capacity info
    pc.max_bottles_per_week,
    pc.max_liters_per_week,
    pc.available_production_hours,
    pc.is_holiday,
    -- Weekly totals
    wt.total_planned_bottles,
    wt.total_planned_hours,
    wt.num_productions,
    -- Utilization percentage
    ROUND((wt.total_planned_bottles::NUMERIC / NULLIF(pc.max_bottles_per_week, 0)) * 100, 1) as utilization_pct,
    -- Capacity status
    CASE
        WHEN wt.total_planned_bottles > pc.max_bottles_per_week THEN '🔴 OVERLOAD'
        WHEN wt.total_planned_bottles > (pc.max_bottles_per_week * 0.85) THEN '🟡 WARNING'
        WHEN pc.is_holiday = TRUE THEN '🏖️ HOLIDAY'
        ELSE '🟢 OK'
    END as capacity_status,
    -- Bottles over/under capacity
    wt.total_planned_bottles - pc.max_bottles_per_week as capacity_variance
FROM production_schedule ps
LEFT JOIN production_capacity pc ON ps.week_start_date = pc.week_start_date
LEFT JOIN weekly_totals wt ON ps.week_start_date = wt.week_start_date
WHERE ps.status IN ('PLANNED', 'IN_PROGRESS')
ORDER BY ps.week_start_date, ps.product_name;

COMMENT ON VIEW v_production_calendar IS 'Weekly production schedule with capacity planning';

-- ============================================================
-- View 5: Purchase Orders to Generate
-- Combines packaging + raw materials for easy PO creation
-- ============================================================
CREATE OR REPLACE VIEW v_purchase_orders_needed AS
WITH packaging_needs AS (
    SELECT
        'PACKAGING' as item_category,
        packaging_item_name as item_name,
        packaging_type as item_type,
        total_required as quantity_needed,
        'units' as uom,
        supplier_name,
        supplier_contact,
        order_by_date,
        days_until_order,
        urgency
    FROM v_packaging_requirements_summary
    WHERE status = 'TO ORDER'
),
material_needs AS (
    SELECT
        'RAW MATERIAL' as item_category,
        material_name as item_name,
        material_type as item_type,
        total_required as quantity_needed,
        unit_of_measure as uom,
        supplier_name,
        supplier_contact,
        order_by_date,
        days_until_order,
        urgency
    FROM v_raw_material_requirements_summary
    WHERE status = 'TO ORDER'
)
SELECT * FROM packaging_needs
UNION ALL
SELECT * FROM material_needs
ORDER BY order_by_date ASC, urgency DESC, supplier_name;

COMMENT ON VIEW v_purchase_orders_needed IS 'All items to order (packaging + raw materials) sorted by urgency';

-- ============================================================
-- View 6: Production Feasibility Check
-- Shows if production is feasible based on current inventory
-- ============================================================
CREATE OR REPLACE VIEW v_production_feasibility AS
SELECT
    pp.id as production_plan_id,
    pp.saq_code,
    pp.product_name,
    pp.recommended_quantity,
    -- Count missing packaging
    COUNT(DISTINCT CASE WHEN pr.gap > 0 THEN pr.id END) as missing_packaging_items,
    -- Count missing raw materials
    COUNT(DISTINCT CASE WHEN rmr.gap > 0 THEN rmr.id END) as missing_material_items,
    -- Total items needed
    COUNT(DISTINCT pr.id) + COUNT(DISTINCT rmr.id) as total_components,
    -- Feasibility
    CASE
        WHEN COUNT(DISTINCT CASE WHEN pr.gap > 0 THEN pr.id END) > 0
          OR COUNT(DISTINCT CASE WHEN rmr.gap > 0 THEN rmr.id END) > 0 THEN FALSE
        ELSE TRUE
    END as is_feasible,
    -- Status
    CASE
        WHEN COUNT(DISTINCT CASE WHEN pr.gap > 0 THEN pr.id END) > 0
          OR COUNT(DISTINCT CASE WHEN rmr.gap > 0 THEN rmr.id END) > 0
        THEN '❌ BLOCKED - Missing materials'
        ELSE '✅ READY TO PRODUCE'
    END as feasibility_status,
    -- List missing items
    ARRAY_AGG(DISTINCT pr.packaging_item_name) FILTER (WHERE pr.gap > 0) as missing_packaging,
    ARRAY_AGG(DISTINCT rmr.material_name) FILTER (WHERE rmr.gap > 0) as missing_materials
FROM production_plan pp
LEFT JOIN packaging_requirements pr ON pp.id = pr.production_plan_id
LEFT JOIN raw_material_requirements rmr ON pp.id = rmr.production_plan_id
GROUP BY pp.id, pp.saq_code, pp.product_name, pp.recommended_quantity
ORDER BY is_feasible DESC, pp.priority_score DESC;

COMMENT ON VIEW v_production_feasibility IS 'Check if production is feasible based on material availability';

-- ============================================================
-- SECTION 3: HELPER FUNCTIONS
-- ============================================================

-- Function 1: Calculate Production Priority Score
CREATE OR REPLACE FUNCTION calculate_priority_score(
    p_days_of_stock NUMERIC,
    p_open_orders NUMERIC,
    p_profit_margin NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
    rupture_weight NUMERIC := 0.5;
    demand_weight NUMERIC := 0.3;
    profitability_weight NUMERIC := 0.2;
    rupture_score NUMERIC;
    demand_score NUMERIC;
    margin_score NUMERIC;
BEGIN
    -- Rupture Score: Higher score for lower stock
    rupture_score := GREATEST(0, 30 - p_days_of_stock);

    -- Demand Score: Confirmed orders
    demand_score := p_open_orders;

    -- Margin Score: Profitability
    margin_score := COALESCE(p_profit_margin, 0) * 100;

    -- Weighted total
    RETURN (rupture_weight * rupture_score) +
           (demand_weight * demand_score) +
           (profitability_weight * margin_score);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_priority_score IS 'Calculate production priority score based on stock, demand, and profitability';

-- ============================================================
-- Function 2: Generate Production Capacity Calendar (next 12 weeks)
CREATE OR REPLACE FUNCTION generate_production_capacity_calendar() RETURNS VOID AS $$
DECLARE
    week_date DATE;
    max_bottles INT := 12000; -- Default capacity
BEGIN
    -- Generate capacity records for next 12 weeks
    FOR i IN 0..11 LOOP
        week_date := DATE_TRUNC('week', CURRENT_DATE) + (i || ' weeks')::INTERVAL;

        INSERT INTO production_capacity (
            week_start_date,
            max_bottles_per_week,
            max_liters_per_week,
            available_production_hours
        ) VALUES (
            week_date,
            max_bottles,
            max_bottles * 0.355, -- Assuming average 355ml bottles
            40 -- 40 hours per week
        )
        ON CONFLICT (week_start_date) DO NOTHING;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_production_capacity_calendar IS 'Pre-populate production capacity for next 12 weeks';

-- Run this to initialize capacity calendar
-- SELECT generate_production_capacity_calendar();

-- ============================================================
-- SECTION 4: SAMPLE DATA INSERTION
-- ============================================================

-- Example: Insert a sample production plan
-- (Uncomment to test after SAQ-Odoo mapping is complete)

/*
INSERT INTO production_plan (
    saq_code,
    product_name,
    recommended_quantity,
    priority,
    priority_score,
    reason,
    horizon_days,
    current_stock,
    forecasted_demand,
    production_deadline
) VALUES (
    '14545132',
    'RTD Margarita 355ml',
    3000,
    'URGENT',
    75.5,
    'SAQ warehouse has 2.1 days of stock remaining. Order expected next week.',
    7,
    240,
    3000,
    CURRENT_DATE + 7
);

-- Example: Insert packaging requirements for this production
INSERT INTO packaging_requirements (
    production_plan_id,
    packaging_item_name,
    packaging_type,
    required_quantity,
    on_hand_quantity,
    lead_time_days,
    supplier_name,
    order_by_date
) VALUES
(1, '355ml Aluminum Can', 'can', 3000, 1500, 14, 'Ball Corporation', CURRENT_DATE + 7 - 14),
(1, 'Can Lid (End)', 'lid', 3000, 1500, 14, 'Ball Corporation', CURRENT_DATE + 7 - 14),
(1, '12-Pack Carton', 'carton', 250, 100, 7, 'Local Packaging Co', CURRENT_DATE + 7 - 7);

-- Example: Insert raw material requirements
INSERT INTO raw_material_requirements (
    production_plan_id,
    material_name,
    material_type,
    required_quantity,
    unit_of_measure,
    on_hand_quantity,
    lead_time_days,
    supplier_name,
    order_by_date
) VALUES
(1, 'Tequila Blanco', 'alcohol', 426, 'L', 200, 21, 'Casa Tequilera', CURRENT_DATE + 7 - 21),
(1, 'Lime Juice Concentrate', 'juice', 319.5, 'L', 100, 14, 'Juice Imports Inc', CURRENT_DATE + 7 - 14),
(1, 'Agave Syrup', 'ingredient', 106.5, 'L', 50, 10, 'Organic Agave Co', CURRENT_DATE + 7 - 10);
*/

-- ============================================================
-- SECTION 5: PERMISSIONS (For Retool Access)
-- ============================================================

-- Grant SELECT on all views to authenticated users (Retool)
-- (Adjust role name based on your Supabase setup)

-- GRANT SELECT ON v_production_plan_summary TO authenticated;
-- GRANT SELECT ON v_packaging_requirements_summary TO authenticated;
-- GRANT SELECT ON v_raw_material_requirements_summary TO authenticated;
-- GRANT SELECT ON v_production_calendar TO authenticated;
-- GRANT SELECT ON v_purchase_orders_needed TO authenticated;
-- GRANT SELECT ON v_production_feasibility TO authenticated;

-- ============================================================
-- END OF SCHEMA
-- ============================================================

-- ============================================================
-- USAGE INSTRUCTIONS:
-- ============================================================
-- 1. Run this entire script in Supabase SQL Editor
-- 2. Generate capacity calendar: SELECT generate_production_capacity_calendar();
-- 3. Wait for SAQ-Odoo product mapping to be complete
-- 4. Build production plan algorithm (Python or SQL)
-- 5. Query dashboard views in Retool via REST API
-- ============================================================
