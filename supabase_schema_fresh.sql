-- ============================================================
-- CHERRY RIVER SAQ DATA PIPELINE - FRESH SCHEMA
-- ============================================================
-- Drop existing tables (in reverse dependency order)
-- ============================================================

DROP TABLE IF EXISTS rupture_alerts CASCADE;
DROP TABLE IF EXISTS saq_store_inventory CASCADE;
DROP TABLE IF EXISTS saq_weekly_sales CASCADE;
DROP TABLE IF EXISTS saq_stores CASCADE;
DROP TABLE IF EXISTS saq_products CASCADE;

-- ============================================================
-- TABLE: saq_products
-- Master list of Cherry River products in SAQ system
-- ============================================================

CREATE TABLE saq_products (
    saq_code VARCHAR(20) PRIMARY KEY,
    description TEXT,
    format VARCHAR(50),
    sales_price NUMERIC(10, 2),
    supplier_no VARCHAR(20),
    status VARCHAR(20),
    odoo_product_id INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_saq_products_status ON saq_products(status);
CREATE INDEX idx_saq_products_odoo ON saq_products(odoo_product_id);

COMMENT ON TABLE saq_products IS 'Cherry River product catalog from SAQ';
COMMENT ON COLUMN saq_products.saq_code IS 'SAQ product code (CIP) - Primary key';
COMMENT ON COLUMN saq_products.status IS 'Product status: Actif, Discontinué, etc.';

-- ============================================================
-- TABLE: saq_stores
-- All SAQ stores that carry Cherry River products
-- ============================================================

CREATE TABLE saq_stores (
    store_number VARCHAR(20) PRIMARY KEY,
    store_name VARCHAR(255),
    city VARCHAR(100),
    region VARCHAR(100),
    sales_rep_name VARCHAR(100),
    sales_rep_email VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_saq_stores_city ON saq_stores(city);
CREATE INDEX idx_saq_stores_region ON saq_stores(region);
CREATE INDEX idx_saq_stores_sales_rep ON saq_stores(sales_rep_email);

COMMENT ON TABLE saq_stores IS 'SAQ store locations with territory assignments';
COMMENT ON COLUMN saq_stores.sales_rep_email IS 'Territory sales rep for rupture alerts';

-- ============================================================
-- TABLE: saq_weekly_sales
-- Weekly sales data by product by store
-- ============================================================

CREATE TABLE saq_weekly_sales (
    id BIGSERIAL PRIMARY KEY,
    saq_code VARCHAR(20) NOT NULL REFERENCES saq_products(saq_code) ON DELETE CASCADE,
    store_number VARCHAR(20) NOT NULL REFERENCES saq_stores(store_number) ON DELETE CASCADE,
    qty_bottles INTEGER DEFAULT 0,
    amount NUMERIC(10, 2) DEFAULT 0,
    year INTEGER NOT NULL,
    period INTEGER NOT NULL,
    week INTEGER NOT NULL,
    week_start_date DATE NOT NULL,
    is_rupture BOOLEAN GENERATED ALWAYS AS (qty_bottles = 0) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Composite unique constraint for upsert
    CONSTRAINT uq_weekly_sales_key UNIQUE (saq_code, store_number, year, period, week)
);

CREATE INDEX idx_weekly_sales_product ON saq_weekly_sales(saq_code);
CREATE INDEX idx_weekly_sales_store ON saq_weekly_sales(store_number);
CREATE INDEX idx_weekly_sales_date ON saq_weekly_sales(week_start_date);
CREATE INDEX idx_weekly_sales_rupture ON saq_weekly_sales(is_rupture) WHERE is_rupture = true;
CREATE INDEX idx_weekly_sales_week ON saq_weekly_sales(year, period, week);

COMMENT ON TABLE saq_weekly_sales IS 'Weekly sales data from SAQ Ventes file';
COMMENT ON COLUMN saq_weekly_sales.is_rupture IS 'Auto-computed: true if qty_bottles = 0';
COMMENT ON CONSTRAINT uq_weekly_sales_key ON saq_weekly_sales IS 'Ensures one sales record per product per store per week';

-- ============================================================
-- TABLE: saq_store_inventory
-- Current inventory snapshot by product by store
-- ============================================================

CREATE TABLE saq_store_inventory (
    id BIGSERIAL PRIMARY KEY,
    saq_code VARCHAR(20) NOT NULL REFERENCES saq_products(saq_code) ON DELETE CASCADE,
    store_number VARCHAR(20) NOT NULL REFERENCES saq_stores(store_number) ON DELETE CASCADE,
    qty_inventory INTEGER DEFAULT 0,
    snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
    avg_weekly_sales NUMERIC(10, 2),
    days_of_inventory NUMERIC(10, 2),
    is_warning BOOLEAN DEFAULT false,
    is_critical BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Composite unique constraint for upsert
    CONSTRAINT uq_inventory_snapshot UNIQUE (saq_code, store_number, snapshot_date)
);

CREATE INDEX idx_inventory_product ON saq_store_inventory(saq_code);
CREATE INDEX idx_inventory_store ON saq_store_inventory(store_number);
CREATE INDEX idx_inventory_date ON saq_store_inventory(snapshot_date);
CREATE INDEX idx_inventory_rupture ON saq_store_inventory(qty_inventory) WHERE qty_inventory = 0;
CREATE INDEX idx_inventory_warning ON saq_store_inventory(is_warning) WHERE is_warning = true;
CREATE INDEX idx_inventory_critical ON saq_store_inventory(is_critical) WHERE is_critical = true;

COMMENT ON TABLE saq_store_inventory IS 'Store inventory snapshots from SAQ Inventaires file';
COMMENT ON COLUMN saq_store_inventory.avg_weekly_sales IS 'Calculated from sales data';
COMMENT ON COLUMN saq_store_inventory.days_of_inventory IS 'Calculated: qty / (avg_weekly_sales / 7)';
COMMENT ON COLUMN saq_store_inventory.is_warning IS 'True if days_of_inventory < 14';
COMMENT ON COLUMN saq_store_inventory.is_critical IS 'True if days_of_inventory < 7';
COMMENT ON CONSTRAINT uq_inventory_snapshot ON saq_store_inventory IS 'One inventory snapshot per product per store per date';

-- ============================================================
-- TABLE: rupture_alerts
-- Rupture and low stock alerts for sales reps
-- ============================================================

CREATE TABLE rupture_alerts (
    id BIGSERIAL PRIMARY KEY,
    saq_code VARCHAR(20) NOT NULL REFERENCES saq_products(saq_code) ON DELETE CASCADE,
    store_number VARCHAR(20) NOT NULL REFERENCES saq_stores(store_number) ON DELETE CASCADE,
    alert_type VARCHAR(20) NOT NULL CHECK (alert_type IN ('rupture', 'critical', 'warning')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'escalated')),
    alert_date DATE NOT NULL DEFAULT CURRENT_DATE,
    days_in_rupture INTEGER DEFAULT 0,
    sales_rep_email VARCHAR(255),
    escalated_to VARCHAR(255),
    escalated_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_alerts_product ON rupture_alerts(saq_code);
CREATE INDEX idx_alerts_store ON rupture_alerts(store_number);
CREATE INDEX idx_alerts_type ON rupture_alerts(alert_type);
CREATE INDEX idx_alerts_status ON rupture_alerts(status);
CREATE INDEX idx_alerts_date ON rupture_alerts(alert_date);
CREATE INDEX idx_alerts_sales_rep ON rupture_alerts(sales_rep_email);

COMMENT ON TABLE rupture_alerts IS 'Rupture and low stock alerts sent to sales reps';
COMMENT ON COLUMN rupture_alerts.alert_type IS 'rupture = qty 0, critical = <7 days, warning = <14 days';
COMMENT ON COLUMN rupture_alerts.days_in_rupture IS 'Auto-incremented daily for unresolved ruptures';

-- ============================================================
-- FUNCTION: Auto-update updated_at timestamp
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all tables
CREATE TRIGGER update_saq_products_updated_at
    BEFORE UPDATE ON saq_products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_saq_stores_updated_at
    BEFORE UPDATE ON saq_stores
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_saq_weekly_sales_updated_at
    BEFORE UPDATE ON saq_weekly_sales
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_saq_store_inventory_updated_at
    BEFORE UPDATE ON saq_store_inventory
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rupture_alerts_updated_at
    BEFORE UPDATE ON rupture_alerts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ENABLE ROW LEVEL SECURITY (Optional - for Supabase)
-- ============================================================

-- ALTER TABLE saq_products ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE saq_stores ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE saq_weekly_sales ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE saq_store_inventory ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE rupture_alerts ENABLE ROW LEVEL SECURITY;

-- Grant service_role full access (uncomment if using RLS)
-- CREATE POLICY "Service role can do everything" ON saq_products FOR ALL USING (true);
-- CREATE POLICY "Service role can do everything" ON saq_stores FOR ALL USING (true);
-- CREATE POLICY "Service role can do everything" ON saq_weekly_sales FOR ALL USING (true);
-- CREATE POLICY "Service role can do everything" ON saq_store_inventory FOR ALL USING (true);
-- CREATE POLICY "Service role can do everything" ON rupture_alerts FOR ALL USING (true);

-- ============================================================
-- SUMMARY
-- ============================================================
-- Tables created: 5
-- Indexes created: 24
-- Triggers created: 5
--
-- Key constraints:
-- 1. saq_weekly_sales: UNIQUE (saq_code, store_number, year, period, week)
-- 2. saq_store_inventory: UNIQUE (saq_code, store_number, snapshot_date)
-- 3. All foreign keys with CASCADE delete
-- 4. Generated column: is_rupture in saq_weekly_sales
--
-- For Python upsert to work, we'll use the unique constraint names:
-- - uq_weekly_sales_key
-- - uq_inventory_snapshot
-- ============================================================
