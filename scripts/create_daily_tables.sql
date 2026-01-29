-- ============================================
-- SAQ Daily Tables for Cherry River
-- These tables store real-time data from Patrick's automated rapport
-- Updated daily via n8n webhook
-- ============================================

-- 1. Daily Warehouse Inventory (Inventaire_CD)
-- REPLACE entire table daily - this is a snapshot
CREATE TABLE IF NOT EXISTS saq_daily_warehouse (
    id SERIAL PRIMARY KEY,
    code_saq VARCHAR(20) NOT NULL,
    product_name VARCHAR(255),
    type_listing VARCHAR(10),
    uvc INTEGER,                          -- units per case
    is_blocked BOOLEAN DEFAULT FALSE,
    is_online BOOLEAN DEFAULT TRUE,
    risk_sharing BOOLEAN DEFAULT FALSE,
    no_fournisseur INTEGER,
    inventaire_cdm NUMERIC(12,2),         -- Montreal warehouse (cases)
    inv_alloc_cdm NUMERIC(12,2),          -- After allocations (cases)
    inventaire_cdq NUMERIC(12,2),         -- Quebec City warehouse (cases)
    date_inventaire DATE NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code_saq, date_inventaire)
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_daily_warehouse_code ON saq_daily_warehouse(code_saq);
CREATE INDEX IF NOT EXISTS idx_daily_warehouse_date ON saq_daily_warehouse(date_inventaire);

-- 2. Daily Store Inventory (Inv_SUCC_BD)
-- REPLACE entire table daily - snapshot of all stores
CREATE TABLE IF NOT EXISTS saq_daily_stores (
    id SERIAL PRIMARY KEY,
    code_saq VARCHAR(20) NOT NULL,
    product_name VARCHAR(255),
    type_listing VARCHAR(10),
    store_id VARCHAR(20) NOT NULL,
    store_name VARCHAR(255),
    banner VARCHAR(10),                   -- EXP, SEL, CLA
    qty_bottles INTEGER DEFAULT 0,
    date_inventaire DATE NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code_saq, store_id, date_inventaire)
);

-- Indexes for aggregation queries
CREATE INDEX IF NOT EXISTS idx_daily_stores_code ON saq_daily_stores(code_saq);
CREATE INDEX IF NOT EXISTS idx_daily_stores_store ON saq_daily_stores(store_id);
CREATE INDEX IF NOT EXISTS idx_daily_stores_date ON saq_daily_stores(date_inventaire);

-- 3. Order Status (Statut_Commande)
-- UPSERT by order number - orders persist until fulfilled
CREATE TABLE IF NOT EXISTS saq_order_status (
    id SERIAL PRIMARY KEY,
    no_commande VARCHAR(50) NOT NULL UNIQUE,
    type_document VARCHAR(10),            -- OP = Purchase Order
    code_saq VARCHAR(20) NOT NULL,
    product_name VARCHAR(255),
    type_listing VARCHAR(10),
    qty_commandee INTEGER,
    destination VARCHAR(100),
    no_fournisseur INTEGER,
    date_emission DATE,
    date_expedition_demandee DATE,
    date_pret_fournisseur DATE,
    date_depart_reel DATE,
    eta_confirme DATE,
    statut VARCHAR(50),                   -- Attente, Voyage organisé, Confirmé départ, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_status_code ON saq_order_status(code_saq);
CREATE INDEX IF NOT EXISTS idx_order_status_statut ON saq_order_status(statut);

-- ============================================
-- RPC Functions for n8n to call
-- ============================================

-- Function to replace daily warehouse inventory
CREATE OR REPLACE FUNCTION upsert_daily_warehouse(
    p_code_saq VARCHAR,
    p_product_name VARCHAR,
    p_type_listing VARCHAR,
    p_uvc INTEGER,
    p_is_blocked BOOLEAN,
    p_is_online BOOLEAN,
    p_risk_sharing BOOLEAN,
    p_no_fournisseur INTEGER,
    p_inventaire_cdm NUMERIC,
    p_inv_alloc_cdm NUMERIC,
    p_inventaire_cdq NUMERIC,
    p_date_inventaire DATE
)
RETURNS void AS $$
BEGIN
    INSERT INTO saq_daily_warehouse (
        code_saq, product_name, type_listing, uvc,
        is_blocked, is_online, risk_sharing, no_fournisseur,
        inventaire_cdm, inv_alloc_cdm, inventaire_cdq,
        date_inventaire, updated_at
    ) VALUES (
        p_code_saq, p_product_name, p_type_listing, p_uvc,
        p_is_blocked, p_is_online, p_risk_sharing, p_no_fournisseur,
        p_inventaire_cdm, p_inv_alloc_cdm, p_inventaire_cdq,
        p_date_inventaire, NOW()
    )
    ON CONFLICT (code_saq, date_inventaire) DO UPDATE SET
        product_name = EXCLUDED.product_name,
        type_listing = EXCLUDED.type_listing,
        uvc = EXCLUDED.uvc,
        is_blocked = EXCLUDED.is_blocked,
        is_online = EXCLUDED.is_online,
        risk_sharing = EXCLUDED.risk_sharing,
        no_fournisseur = EXCLUDED.no_fournisseur,
        inventaire_cdm = EXCLUDED.inventaire_cdm,
        inv_alloc_cdm = EXCLUDED.inv_alloc_cdm,
        inventaire_cdq = EXCLUDED.inventaire_cdq,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to upsert order status
CREATE OR REPLACE FUNCTION upsert_order_status(
    p_no_commande VARCHAR,
    p_type_document VARCHAR,
    p_code_saq VARCHAR,
    p_product_name VARCHAR,
    p_type_listing VARCHAR,
    p_qty_commandee INTEGER,
    p_destination VARCHAR,
    p_no_fournisseur INTEGER,
    p_date_emission DATE,
    p_date_expedition_demandee DATE,
    p_date_pret_fournisseur DATE,
    p_date_depart_reel DATE,
    p_eta_confirme DATE,
    p_statut VARCHAR
)
RETURNS void AS $$
BEGIN
    INSERT INTO saq_order_status (
        no_commande, type_document, code_saq, product_name, type_listing,
        qty_commandee, destination, no_fournisseur,
        date_emission, date_expedition_demandee, date_pret_fournisseur,
        date_depart_reel, eta_confirme, statut, updated_at
    ) VALUES (
        p_no_commande, p_type_document, p_code_saq, p_product_name, p_type_listing,
        p_qty_commandee, p_destination, p_no_fournisseur,
        p_date_emission, p_date_expedition_demandee, p_date_pret_fournisseur,
        p_date_depart_reel, p_eta_confirme, p_statut, NOW()
    )
    ON CONFLICT (no_commande) DO UPDATE SET
        type_document = EXCLUDED.type_document,
        code_saq = EXCLUDED.code_saq,
        product_name = EXCLUDED.product_name,
        type_listing = EXCLUDED.type_listing,
        qty_commandee = EXCLUDED.qty_commandee,
        destination = EXCLUDED.destination,
        no_fournisseur = EXCLUDED.no_fournisseur,
        date_emission = EXCLUDED.date_emission,
        date_expedition_demandee = EXCLUDED.date_expedition_demandee,
        date_pret_fournisseur = EXCLUDED.date_pret_fournisseur,
        date_depart_reel = EXCLUDED.date_depart_reel,
        eta_confirme = EXCLUDED.eta_confirme,
        statut = EXCLUDED.statut,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to bulk replace daily store inventory
-- Call this BEFORE inserting new data for the day
CREATE OR REPLACE FUNCTION clear_daily_stores_for_date(p_date DATE)
RETURNS void AS $$
BEGIN
    DELETE FROM saq_daily_stores WHERE date_inventaire = p_date;
END;
$$ LANGUAGE plpgsql;
