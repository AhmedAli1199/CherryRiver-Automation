# Cherry River COO Cockpit - Implementation Analysis
**Analysis Date:** January 29, 2026
**Analyst:** Ahmed (Lead Developer)
**Client:** Francis Delage, Cherry River

---

## EXECUTIVE SUMMARY

The Cherry River COO Cockpit is approximately **35% complete**. Core SAQ sales analytics and inventory monitoring are operational, but the critical production and purchase planning modules are **not yet built**. This analysis identifies what exists, what's missing, and the specific steps needed to complete Francis's vision.

**Key Findings:**
- ✅ SAQ sales tracking and YoY comparison: **COMPLETE**
- ✅ Weekly data import pipeline: **COMPLETE & AUTOMATED**
- ✅ Warehouse inventory monitoring: **COMPLETE**
- ❌ Production planning module: **NOT STARTED**
- ❌ Purchase planning (raw materials & packaging): **NOT STARTED**
- ❌ Production calendar: **NOT STARTED**
- ⚠️ Odoo integration: **PARTIAL** (tables exist, but logic not built)

---

## 1. WHAT'S COMPLETE ✅

### 1.1 SAQ Sales Analytics (OPERATIONAL)

**Current Capabilities:**
- Year-over-year sales comparison by product and SAQ period
- Week-over-week, month-over-month, and period-over-period trending
- Sales velocity calculation (average weekly depletion rate)
- Sales by store, by product, by region

**Data Sources:**
- `saq_ventes` table: Historical sales data (2021-present)
- `saq_weekly_sales` table: Current week sales data
- `saq_stores` table: Territory assignments

**Dashboard Views Built:**
- `v_yoy_sales`: Period-level YoY comparison with % change
- `v_sales_trend`: Weekly sales trend over last 13 periods

**Technical Implementation:**
- Automated weekly CSV import via `saq_weekly_update.py`
- Data stored in Supabase PostgreSQL
- Retool dashboard: "SKU Summary Dashboard.json"

**Francis Can Currently:**
- See which products are trending up or down vs last year
- Identify sales velocity by SKU
- Compare current SAQ period to same period last year

---

### 1.2 SAQ Inventory Monitoring (OPERATIONAL)

**Current Capabilities:**
- Real-time warehouse inventory (Montreal CDM + Quebec CDQ)
- Store-level inventory across 381+ SAQ locations
- Automated reorder alerts based on weeks of stock remaining
- Rupture detection (0 inventory)

**Data Sources:**
- `saq_daily_warehouse` table: Warehouse inventory (CDM/CDQ)
- `saq_daily_stores` table: Store inventory by location
- `saq_store_inventory` table: Processed with velocity calculations

**Dashboard Views Built:**
- `v_po_prediction`: Weeks of stock calculation with alerts (COMMANDER/SURVEILLER/OK)
- `v_store_inventory_summary`: Total bottles by product across all stores
- `v_store_inventory_by_banner`: Breakdown by SAQ banner (Classique/Dépôt/Signature/Express)

**Alert System:**
- 🔴 CRITICAL: < 7 days of inventory
- 🟡 WARNING: < 14 days of inventory
- ✅ OK: > 14 days of inventory

**Technical Implementation:**
- Daily automated updates from Patrick's rapport
- Sales rep email alerts via N8N workflow
- Rupture tracking with escalation logic (24h → 48h → 72h)

**Francis Can Currently:**
- See which products need reordering from SAQ
- Track weeks of stock remaining for each SKU
- Monitor store ruptures by territory and sales rep

---

### 1.3 Weekly Data Import Pipeline (OPERATIONAL)

**Current Capabilities:**
- Automated SAQ B2B portal scraping
- Daily CSV download and processing
- Supabase database updates
- Email notifications on completion

**Files Processed:**
1. `Ventes_*.csv` → `saq_ventes` table
2. `Inventaires succursales.csv` → `saq_daily_stores` table
3. `Inventaires entrepôts.csv` → `saq_daily_warehouse` table
4. `Commandes en cours.csv` → `saq_order_status` table
5. `Produits.csv` → `saq_product` table

**Technical Implementation:**
- `saq_data_scraper.py`: Selenium-based web scraper
- `saq_weekly_update.py`: CSV processor with Cherry River filtering
- `run_weekly_update.bat`: Windows scheduled task
- N8N workflow: Email alert system

**Automation Status:**
- Scraping: **MANUAL** (run on demand)
- Processing: **AUTOMATED** (batch file)
- Alerts: **AUTOMATED** (daily N8N workflow at 9 AM)

---

### 1.4 Dashboard Infrastructure (READY)

**What Exists:**
- Supabase PostgreSQL database with 20+ tables
- 7 SQL views optimized for Retool REST API queries
- Retool dashboard with SKU summary, YoY comparison, PO prediction
- N8N workflow for daily email alerts to sales reps

**Access:**
- Retool: Live dashboard (URL in client handoff docs)
- Supabase: Database with full schema
- N8N: Email automation ($20/month cloud service)

---

## 2. WHAT'S MISSING ❌

### 2.1 Production Planning Module (NOT STARTED)

**Francis's Requirements (Lines 204-240):**

#### A. Production Quantities by SKU
**What Francis Wants:**
- See which SKUs to produce next
- Prioritize by urgency (short-term vs mid-term)
- Planning horizons: 7 days, 14 days, 30 days

**What's Missing:**
- Algorithm to calculate production quantities based on:
  - Current SAQ warehouse inventory
  - Incoming SAQ orders (from `saq_order_status`)
  - Sales velocity (average weekly depletion)
  - Lead time from SAQ order to delivery
  - Safety stock buffer (min stock thresholds)
- Priority ranking system:
  - **URGENT**: Products with < 7 days stock + incoming orders
  - **SHORT-TERM**: Products with < 14 days stock
  - **MID-TERM**: Products with < 30 days stock

**Data Required:**
- SAQ forecasted demand (when SAQ will place next order)
- Production lead time per SKU
- Minimum batch sizes for production

**Tables Needed:**
```sql
CREATE TABLE production_plan (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    saq_code VARCHAR(20) REFERENCES saq_product(code_saq),
    recommended_quantity NUMERIC NOT NULL,
    priority VARCHAR(20) NOT NULL, -- 'URGENT', 'SHORT-TERM', 'MID-TERM'
    reason TEXT, -- 'SAQ rupture imminent', 'Low warehouse stock', etc.
    horizon_days INT NOT NULL, -- 7, 14, 30
    current_stock NUMERIC,
    forecasted_demand NUMERIC,
    production_deadline DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

#### B. Production Priorities
**What Francis Wants:**
- Clear ranking of which products to produce first
- Context on why each product is prioritized
- Actionable "produce now" recommendations

**What's Missing:**
- Prioritization logic based on:
  1. Rupture risk (current stock ÷ daily sales rate)
  2. Open SAQ orders (confirmed demand)
  3. Historical sales seasonality
  4. Profit margin (high-margin products first)
- Dashboard view showing:
  - Rank #1-20 products to produce
  - Quantity needed
  - Deadline date
  - Risk level

**Algorithm Example:**
```python
# Priority Score Calculation
priority_score = (
    (rupture_risk_weight * rupture_score) +
    (demand_weight * confirmed_demand_score) +
    (profitability_weight * margin_score)
)

# Rupture Score: Days until stockout
rupture_score = max(0, 30 - days_of_stock_remaining)

# Demand Score: Open SAQ orders waiting
confirmed_demand_score = sum(open_saq_orders.qty)

# Margin Score: Profit per unit
margin_score = (list_price - standard_price) / list_price
```

---

#### C. Planning Horizons (7/14/30 Days)
**What Francis Wants:**
- View production needs in 3 time windows:
  - **7-day view**: "What must be produced THIS WEEK"
  - **14-day view**: "What's needed in the next 2 weeks"
  - **30-day view**: "Full month production roadmap"

**What's Missing:**
- Time-based filtering on production plan
- Dashboard tabs for each horizon
- Forecasting logic to project inventory levels forward

**Example Dashboard Layout:**
```
┌─────────────────────────────────────────────────┐
│ PRODUCTION PLANNING - 7 DAY HORIZON             │
├─────────────────────────────────────────────────┤
│ URGENT PRODUCTIONS (Week of Feb 3-9, 2026)     │
│                                                 │
│ 🔴 RTD Margarita 355ml (14545132)              │
│    Current Stock: 240 bottles (2.1 days)       │
│    Recommended Production: 3,000 bottles        │
│    Reason: SAQ order expected next week         │
│                                                 │
│ 🔴 Mocktail Amaretto Sour (14682882)           │
│    Current Stock: 0 bottles (RUPTURE)          │
│    Recommended Production: 2,400 bottles        │
│    Reason: 3 SAQ stores in rupture              │
└─────────────────────────────────────────────────┘
```

---

### 2.2 Purchase Planning Module (NOT STARTED)

**Francis's Requirements (Lines 211-233):**

#### A. Packaging Requirements
**What Francis Wants to Track:**
1. Bottles (glass, sizes: 355ml, 750ml, etc.)
2. Cans (355ml aluminum)
3. Closures (caps, corks)
4. Lids (for cans)
5. Carton boxes (cases for shipping)

**For Each Item:**
- Required quantity (based on production plan)
- Inventory on hand (from Odoo `stock_quants`)
- Gap (required - on_hand)
- Required action: **OK** | **TO ORDER**

**What's Missing:**
- BOM (Bill of Materials) explosion logic
- Link from finished goods → packaging components
- Current Odoo inventory for packaging items
- Reorder thresholds for packaging

**Data Structure Needed:**
```sql
CREATE TABLE packaging_requirements (
    id SERIAL PRIMARY KEY,
    production_plan_id INT REFERENCES production_plan(id),
    packaging_item_id INT REFERENCES products(id),
    packaging_item_name TEXT NOT NULL,
    packaging_type VARCHAR(50), -- 'bottle', 'can', 'closure', 'lid', 'box'
    required_quantity NUMERIC NOT NULL,
    on_hand_quantity NUMERIC NOT NULL,
    gap NUMERIC GENERATED ALWAYS AS (required_quantity - on_hand_quantity) STORED,
    lead_time_days INT,
    supplier_name TEXT,
    action_required VARCHAR(20) GENERATED ALWAYS AS (
        CASE WHEN gap > 0 THEN 'TO ORDER' ELSE 'OK' END
    ) STORED,
    order_by_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

#### B. Raw Materials & Ingredients
**What Francis Wants to Track:**
1. Ingredients (flavoring compounds)
2. Flavors (natural/artificial extracts)
3. Neutral alcohol (base spirit)
4. Rum (for RTD cocktails)
5. Tequila (for margaritas)
6. Juice (mixers, concentrates)

**For Each Item:**
- Required quantity (in liters or kg)
- Current inventory (from Odoo)
- Gap (shortfall)
- Action: **OK** | **TO ORDER**

**What's Missing:**
- BOM mapping from finished goods → raw materials
- Conversion factors (e.g., 1 case of RTD Margarita = 8.52L tequila + 1.2L lime juice + ...)
- Current raw material inventory from Odoo
- Lead times for each supplier
- Minimum order quantities (MOQ)

**Example BOM Explosion:**
```
Production Plan: 3,000 bottles of RTD Margarita 355ml
├─ Packaging Requirements:
│  ├─ 3,000 x 355ml cans
│  ├─ 3,000 x can lids
│  ├─ 250 x 12-pack cartons
├─ Raw Material Requirements:
│  ├─ 1,065 L Tequila (3000 * 0.355 * 0.40 ABV / 0.40)
│  ├─ 319.5 L Lime juice (3000 * 0.355 * 0.30)
│  ├─ 106.5 L Agave syrup (3000 * 0.355 * 0.10)
│  ├─ 15 kg Citric acid
│  ├─ 2 kg Natural lime flavor
```

**Tables Exist but Not Used:**
- `bom_lines`: BOM components from Odoo
- `products`: All products including raw materials
- `stock_quants`: Current inventory levels
- `lead_times`: Supplier lead times (already imported!)

**What's Missing:**
- SQL query to explode BOM for production plan
- Dashboard view showing packaging + ingredients side-by-side
- Alerts when lead time + current stock < production deadline

---

### 2.3 Production Calendar (NOT STARTED)

**Francis's Requirements (Lines 234-239):**

**What Francis Wants:**
- Calendar view showing weekly/monthly production schedule
- Which SKUs to produce each week
- Quantities per SKU
- Plant capacity limits
- Visual indicators of conflicts or overloads

**What's Missing:**
- Production capacity data (max liters/week, max bottles/day)
- Production time estimates per SKU
- Calendar UI component in Retool
- Capacity planning algorithm

**Example Calendar View:**
```
┌────────────────────────────────────────────────────────────┐
│ FEBRUARY 2026 - PRODUCTION CALENDAR                        │
├────────┬────────┬────────┬────────┬────────┬────────┬──────┤
│ Week 1 │ Week 2 │ Week 3 │ Week 4 │                        │
├────────┼────────┼────────┼────────┤                        │
│ Feb 3  │ Feb 10 │ Feb 17 │ Feb 24 │                        │
│        │        │        │        │                        │
│ 🔴     │ 🟡     │ ✅     │ ✅     │                        │
│ OVER   │ 90%    │ 60%    │ 40%    │                        │
│        │        │        │        │                        │
│ Marg.  │ Amar.  │ Vodka  │ Rum    │                        │
│ 3000   │ 2400   │ 5000   │ 1200   │                        │
│        │        │        │        │                        │
│ Vodka  │ Lime   │        │        │                        │
│ 5000   │ 1800   │        │        │                        │
└────────┴────────┴────────┴────────┘

Capacity: 12,000 bottles/week
Week 1: 8,000 bottles planned (133% - OVERLOAD!)
Week 2: 4,200 bottles planned (90% - Near capacity)
```

**Data Structure Needed:**
```sql
CREATE TABLE production_schedule (
    id SERIAL PRIMARY KEY,
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,
    product_id INT REFERENCES products(id),
    saq_code VARCHAR(20),
    planned_quantity NUMERIC NOT NULL,
    production_time_hours NUMERIC,
    assigned_to TEXT, -- Production team member
    status VARCHAR(20) DEFAULT 'PLANNED', -- PLANNED, IN_PROGRESS, COMPLETED
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE production_capacity (
    id SERIAL PRIMARY KEY,
    week_start_date DATE NOT NULL,
    max_bottles_per_week INT NOT NULL,
    max_liters_per_week NUMERIC,
    available_production_hours NUMERIC,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 3. DATA GAPS - What Tables/Views Need Creation

### 3.1 Missing Core Tables

#### A. Production Planning Tables
```sql
-- Table 1: Production Plan (Master)
CREATE TABLE production_plan (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    saq_code VARCHAR(20) REFERENCES saq_product(code_saq),
    recommended_quantity NUMERIC NOT NULL,
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('URGENT', 'SHORT-TERM', 'MID-TERM')),
    priority_score NUMERIC, -- Calculated ranking
    reason TEXT,
    horizon_days INT NOT NULL CHECK (horizon_days IN (7, 14, 30)),
    current_stock NUMERIC,
    forecasted_demand NUMERIC,
    production_deadline DATE,
    is_feasible BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 2: Packaging Requirements
CREATE TABLE packaging_requirements (
    id SERIAL PRIMARY KEY,
    production_plan_id INT REFERENCES production_plan(id),
    packaging_item_id INT REFERENCES products(id),
    packaging_item_name TEXT NOT NULL,
    packaging_type VARCHAR(50),
    required_quantity NUMERIC NOT NULL,
    on_hand_quantity NUMERIC NOT NULL,
    gap NUMERIC GENERATED ALWAYS AS (required_quantity - on_hand_quantity) STORED,
    lead_time_days INT,
    supplier_name TEXT,
    action_required VARCHAR(20) GENERATED ALWAYS AS (
        CASE WHEN gap > 0 THEN 'TO ORDER' ELSE 'OK' END
    ) STORED,
    order_by_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 3: Raw Material Requirements
CREATE TABLE raw_material_requirements (
    id SERIAL PRIMARY KEY,
    production_plan_id INT REFERENCES production_plan(id),
    material_id INT REFERENCES products(id),
    material_name TEXT NOT NULL,
    material_type VARCHAR(50), -- 'alcohol', 'ingredient', 'flavor', 'juice'
    required_quantity NUMERIC NOT NULL,
    unit_of_measure VARCHAR(20), -- 'L', 'kg', 'units'
    on_hand_quantity NUMERIC NOT NULL,
    gap NUMERIC GENERATED ALWAYS AS (required_quantity - on_hand_quantity) STORED,
    lead_time_days INT,
    supplier_name TEXT,
    action_required VARCHAR(20) GENERATED ALWAYS AS (
        CASE WHEN gap > 0 THEN 'TO ORDER' ELSE 'OK' END
    ) STORED,
    order_by_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 4: Production Schedule (Calendar)
CREATE TABLE production_schedule (
    id SERIAL PRIMARY KEY,
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,
    product_id INT REFERENCES products(id),
    saq_code VARCHAR(20),
    planned_quantity NUMERIC NOT NULL,
    production_time_hours NUMERIC,
    assigned_to TEXT,
    status VARCHAR(20) DEFAULT 'PLANNED',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 5: Production Capacity
CREATE TABLE production_capacity (
    id SERIAL PRIMARY KEY,
    week_start_date DATE NOT NULL UNIQUE,
    max_bottles_per_week INT NOT NULL,
    max_liters_per_week NUMERIC,
    available_production_hours NUMERIC,
    current_utilization_pct NUMERIC,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### 3.2 Missing SQL Views for Dashboard

#### View 1: Production Plan Summary
```sql
CREATE OR REPLACE VIEW v_production_plan_summary AS
SELECT
    pp.id,
    pp.saq_code,
    sp.description as product_name,
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
    -- Odoo product info
    p.qty_available as odoo_qty_available,
    p.virtual_available as odoo_virtual_available,
    -- Is this production still needed?
    CASE
        WHEN pp.current_stock >= pp.forecasted_demand THEN FALSE
        ELSE TRUE
    END as still_needed
FROM production_plan pp
LEFT JOIN saq_product sp ON pp.saq_code = sp.code_saq
LEFT JOIN products p ON sp.odoo_product_id = p.id
WHERE pp.is_feasible = TRUE
ORDER BY pp.priority_score DESC, pp.production_deadline ASC;
```

#### View 2: Packaging Requirements Summary
```sql
CREATE OR REPLACE VIEW v_packaging_requirements_summary AS
SELECT
    pr.packaging_type,
    pr.packaging_item_name,
    SUM(pr.required_quantity) as total_required,
    MAX(pr.on_hand_quantity) as current_stock,
    SUM(pr.gap) as total_gap,
    MAX(pr.lead_time_days) as lead_time_days,
    pr.supplier_name,
    CASE
        WHEN SUM(pr.gap) > 0 THEN 'TO ORDER'
        ELSE 'OK'
    END as status,
    -- Calculate order deadline
    MIN(pr.order_by_date) as order_by_date,
    COUNT(DISTINCT pr.production_plan_id) as num_productions_affected
FROM packaging_requirements pr
GROUP BY pr.packaging_type, pr.packaging_item_name, pr.supplier_name
ORDER BY total_gap DESC;
```

#### View 3: Raw Material Requirements Summary
```sql
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
    CASE
        WHEN SUM(rmr.gap) > 0 THEN 'TO ORDER'
        ELSE 'OK'
    END as status,
    MIN(rmr.order_by_date) as order_by_date,
    COUNT(DISTINCT rmr.production_plan_id) as num_productions_affected
FROM raw_material_requirements rmr
GROUP BY rmr.material_type, rmr.material_name, rmr.unit_of_measure, rmr.supplier_name
ORDER BY total_gap DESC;
```

#### View 4: Production Calendar Weekly
```sql
CREATE OR REPLACE VIEW v_production_calendar AS
SELECT
    ps.week_start_date,
    ps.week_end_date,
    ps.saq_code,
    sp.description as product_name,
    ps.planned_quantity,
    ps.production_time_hours,
    ps.status,
    -- Capacity info
    pc.max_bottles_per_week,
    pc.current_utilization_pct,
    -- Is week overloaded?
    CASE
        WHEN SUM(ps.planned_quantity) OVER (PARTITION BY ps.week_start_date) > pc.max_bottles_per_week THEN 'OVERLOAD'
        WHEN SUM(ps.planned_quantity) OVER (PARTITION BY ps.week_start_date) > (pc.max_bottles_per_week * 0.85) THEN 'WARNING'
        ELSE 'OK'
    END as capacity_status
FROM production_schedule ps
LEFT JOIN saq_product sp ON ps.saq_code = sp.code_saq
LEFT JOIN production_capacity pc ON ps.week_start_date = pc.week_start_date
ORDER BY ps.week_start_date, ps.saq_code;
```

---

## 4. ODOO INTEGRATION POINTS

### 4.1 Existing Odoo Tables (Available in Supabase)

**✅ Currently Synced:**
1. `products` - All Odoo products (finished goods, raw materials, packaging)
2. `stock_quants` - Current inventory levels by location
3. `stock_movements` - Inventory movement history
4. `bom_lines` - Bill of Materials (components for each finished good)
5. `purchase_orders` - Open/draft POs from suppliers
6. `purchase_order_lines` - Line items on POs
7. `lead_times` - Supplier lead times (manually imported, 465 records)

**🔄 Sync Status:**
- Tables exist but **NO AUTOMATED SYNC** from Odoo
- Data is **STALE** (last updated: unknown)
- Need Odoo API connection to keep fresh

---

### 4.2 Odoo Data Needed for Production Planning

#### A. Real-Time Inventory (From Odoo)
**Required Fields:**
- Product ID
- Product name
- Quantity on hand
- Quantity available (minus reserved)
- Location (warehouse, production area, etc.)

**Current Status:**
- `stock_quants` table exists
- **BLOCKER:** No automated sync; data may be outdated

**Action Required:**
- Set up Odoo API integration
- Sync inventory every hour or on-demand
- Store in `stock_quants` table

---

#### B. Bill of Materials (From Odoo)
**Required Fields:**
- Finished good product ID
- Component product IDs
- Quantity per unit
- UOM (unit of measure)

**Current Status:**
- `bom_lines` table exists
- Schema appears incomplete (10 BOM line IDs?)
- **BLOCKER:** BOM data structure unclear

**Example BOM Structure Needed:**
```
Finished Good: RTD Margarita 355ml (Odoo ID: 45)
├─ Component 1: Tequila (Odoo ID: 120) → 0.142 L per bottle
├─ Component 2: Lime Juice (Odoo ID: 135) → 0.107 L per bottle
├─ Component 3: Agave Syrup (Odoo ID: 142) → 0.036 L per bottle
├─ Component 4: 355ml Can (Odoo ID: 89) → 1 unit per bottle
├─ Component 5: Can Lid (Odoo ID: 90) → 1 unit per bottle
└─ Component 6: 12-pack Carton (Odoo ID: 95) → 0.083 units per bottle
```

**Action Required:**
- Verify BOM structure in Odoo
- Export complete BOM for all finished goods
- Import to Supabase with clear parent-child relationships

---

#### C. Purchase Orders (From Odoo)
**Required Fields:**
- PO number
- Supplier name
- Product ID
- Quantity ordered
- Expected delivery date
- PO status (draft, sent, confirmed, received)

**Current Status:**
- `purchase_orders` and `purchase_order_lines` tables exist
- **BLOCKER:** No automated sync from Odoo

**Use Case:**
- When production plan identifies "TO ORDER" items, check if PO already exists
- Show "PO #12345 for 5000 cans arriving Feb 15" instead of "TO ORDER"

**Action Required:**
- Sync Odoo POs to Supabase daily
- Filter to "draft" and "confirmed" status only

---

#### D. SAQ to Odoo Product Mapping (CRITICAL)
**Required Fields:**
- SAQ code (e.g., 14545132)
- Odoo product ID (e.g., 45)
- Product name

**Current Status:**
- `saq_odoo_product_mapping.csv` has only **2 products** mapped
- **CRITICAL BLOCKER:** Cannot calculate production needs without this mapping

**Mapping File Contents (Currently):**
```
saq_code,odoo_product_id,odoo_product_name,odoo_default_code
14545132,45,RTD Margarita 355ml,CR-MARG-355
14682882,46,Mocktail Amaretto Sour 355ml,CR-AMAR-355
```

**Action Required:**
- Patrick (Odoo admin) must provide full mapping for all Cherry River SAQ codes
- Expected: ~76 SAQ codes → Odoo product IDs
- This is the **#1 blocker** for production planning

---

### 4.3 Odoo API Integration Architecture

**Recommended Approach:**

#### Option 1: N8N Workflow (Easiest)
```
┌─────────────────────────────────────────┐
│ N8N Workflow (Runs Hourly)              │
├─────────────────────────────────────────┤
│ 1. Trigger: Schedule (hourly)           │
│ 2. Odoo: Get Product Inventory          │
│ 3. Odoo: Get Open Purchase Orders       │
│ 4. Supabase: Upsert stock_quants        │
│ 5. Supabase: Upsert purchase_orders     │
└─────────────────────────────────────────┘
```

**Pros:**
- No custom code required
- Visual workflow editor
- Built-in Odoo connector
- Already using N8N for email alerts

**Cons:**
- N8N Cloud: $20/month
- Limited to 5,000 workflow executions/month on Starter plan

---

#### Option 2: Python Script (More Control)
```python
# odoo_sync.py
import xmlrpc.client
from supabase import create_client

# Connect to Odoo
odoo_url = "https://cherryriver.odoo.com"
odoo_db = "cherryriver"
odoo_username = "patrick@cherryriver.ca"
odoo_password = "***"

common = xmlrpc.client.ServerProxy(f"{odoo_url}/xmlrpc/2/common")
uid = common.authenticate(odoo_db, odoo_username, odoo_password, {})

models = xmlrpc.client.ServerProxy(f"{odoo_url}/xmlrpc/2/object")

# Get inventory
inventory = models.execute_kw(
    odoo_db, uid, odoo_password,
    'stock.quant', 'search_read',
    [[['product_id.type', '=', 'product']]],
    {'fields': ['product_id', 'quantity', 'available_quantity', 'location_id']}
)

# Sync to Supabase
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
for item in inventory:
    supabase.table('stock_quants').upsert({
        'product_id': item['product_id'][0],
        'quantity': item['quantity'],
        'available_quantity': item['available_quantity'],
        'location_id': item['location_id'][0],
        'updated_at': 'NOW()'
    }).execute()
```

**Pros:**
- Full control over sync logic
- Can run on Windows Task Scheduler (free)
- Error handling and logging

**Cons:**
- Requires Python maintenance
- Odoo XML-RPC can be finicky

---

#### Option 3: Odoo Direct SQL (Advanced)
**NOT RECOMMENDED:**
- Odoo database schema is complex and undocumented
- Direct SQL queries may break with Odoo updates
- Violates Odoo's terms of service

---

## 5. RECOMMENDED IMPLEMENTATION ROADMAP

### Phase 1: Data Foundation (1 week)
**Priority: CRITICAL**

#### Task 1.1: Complete SAQ-Odoo Product Mapping
- **Owner:** Patrick (Odoo admin)
- **Deliverable:** CSV with all 76 SAQ codes → Odoo product IDs
- **Blocker:** Cannot proceed without this

#### Task 1.2: Verify BOM Data in Odoo
- **Owner:** Patrick + Francis
- **Deliverable:** Export complete BOM for top 10 SKUs
- **Validation:** Each finished good has all components listed

#### Task 1.3: Set Up Odoo Inventory Sync
- **Owner:** Ahmed (developer)
- **Deliverable:** N8N workflow or Python script syncing inventory hourly
- **Tables:** `stock_quants`, `purchase_orders`, `purchase_order_lines`

---

### Phase 2: Production Planning Module (2 weeks)
**Priority: HIGH**

#### Task 2.1: Build Production Plan Algorithm
- **Owner:** Ahmed
- **Deliverable:** SQL stored procedure or Python script
- **Logic:**
  1. Query SAQ inventory and sales velocity
  2. Calculate weeks of stock remaining
  3. Identify products needing production within 7/14/30 days
  4. Calculate recommended production quantities
  5. Insert into `production_plan` table

#### Task 2.2: Build BOM Explosion Logic
- **Owner:** Ahmed
- **Deliverable:** SQL function to explode BOM
- **Logic:**
  1. Given production quantity for finished good
  2. Multiply BOM components by quantity
  3. Compare to current Odoo inventory
  4. Insert gaps into `packaging_requirements` and `raw_material_requirements`

#### Task 2.3: Create Dashboard Views
- **Owner:** Ahmed
- **Deliverable:** 4 SQL views (listed in Section 3.2)
- **Integration:** Expose via Supabase REST API for Retool

#### Task 2.4: Build Retool Dashboard
- **Owner:** Ahmed
- **Deliverable:** Production Planning dashboard with:
  - Production priorities table (top 20 SKUs)
  - Horizon filters (7/14/30 days)
  - Packaging requirements list
  - Raw material requirements list

---

### Phase 3: Purchase Planning Module (1 week)
**Priority: MEDIUM**

#### Task 3.1: Build Purchase Recommendations View
- **Owner:** Ahmed
- **Deliverable:** Consolidated view of all items to order
- **Logic:**
  - Merge packaging + raw material requirements
  - Check existing Odoo POs for each item
  - Calculate "order by" date (production deadline - lead time)
  - Sort by urgency

#### Task 3.2: Integrate Supplier Lead Times
- **Owner:** Ahmed
- **Deliverable:** Join lead_times table with requirements
- **Enhancement:** Highlight items where lead time > days until needed

#### Task 3.3: Build Retool Purchase Dashboard
- **Owner:** Ahmed
- **Deliverable:** Purchase Planning dashboard with:
  - "TO ORDER" items list
  - Order deadline countdown
  - Supplier contact info
  - One-click "Generate PO" button (future enhancement)

---

### Phase 4: Production Calendar (1 week)
**Priority: MEDIUM**

#### Task 4.1: Define Production Capacity
- **Owner:** Francis + Production Manager
- **Deliverable:** Weekly capacity limits
  - Max bottles per week
  - Max liters per week
  - Available production hours

#### Task 4.2: Build Production Scheduler
- **Owner:** Ahmed
- **Deliverable:** Algorithm to assign productions to weeks
- **Logic:**
  1. Sort production plan by priority
  2. Assign to earliest available week
  3. Check capacity constraints
  4. Flag conflicts

#### Task 4.3: Build Calendar View in Retool
- **Owner:** Ahmed
- **Deliverable:** Interactive calendar showing:
  - Weekly productions
  - Capacity utilization (%)
  - Drag-and-drop to reschedule (future enhancement)

---

### Phase 5: Automation & Alerts (1 week)
**Priority: LOW (Nice to Have)

#### Task 5.1: Auto-Generate Production Plan
- **Owner:** Ahmed
- **Deliverable:** Scheduled job (daily or weekly)
- **Logic:** Run production plan algorithm automatically

#### Task 5.2: Email Alerts for Production Manager
- **Owner:** Ahmed
- **Deliverable:** N8N workflow
- **Trigger:** When new URGENT productions appear
- **Recipient:** Francis or designated production manager

#### Task 5.3: Slack Integration (Optional)
- **Owner:** Ahmed
- **Deliverable:** Slack bot posting daily production summary
- **Example:** "Today's Production: RTD Margarita (3000 units), Status: 🟢 All materials available"

---

## 6. CRITICAL DEPENDENCIES & BLOCKERS

### Blocker #1: SAQ-Odoo Product Mapping (CRITICAL)
**Status:** ❌ BLOCKED
**Owner:** Patrick
**Impact:** Cannot calculate production needs without this
**Required:** CSV with 76 SAQ codes → Odoo product IDs
**Deadline:** ASAP (blocks all of Phase 2)

**Current Mapping Coverage:**
- Mapped: 2 products (2.6%)
- Missing: 74 products (97.4%)

**Example of Required Mapping:**
```csv
saq_code,odoo_product_id,odoo_product_name,odoo_default_code
14545132,45,RTD Margarita 355ml,CR-MARG-355
14682882,46,Mocktail Amaretto Sour 355ml,CR-AMAR-355
14001338,78,Cherry River Vodka Premium,CR-VODKA-750
14064873,82,Cherry River Érable Vodka,CR-ERABLE-750
... (72 more rows)
```

---

### Blocker #2: BOM Data Verification (HIGH)
**Status:** ⚠️ UNCLEAR
**Owner:** Patrick + Francis
**Impact:** Cannot calculate raw material needs without accurate BOM
**Required:** Complete BOM for all finished goods
**Deadline:** Week 1 of Phase 1

**Questions to Answer:**
1. Are all finished goods in Odoo with complete BOMs?
2. Do BOMs include both packaging AND raw materials?
3. Are quantities in correct units (liters, kg, units)?
4. Are BOMs kept up-to-date when recipes change?

**Action:** Export sample BOM for 1 product and verify structure

---

### Blocker #3: Odoo Inventory Sync (MEDIUM)
**Status:** ⚠️ NOT AUTOMATED
**Owner:** Ahmed (after Phase 1 approval)
**Impact:** Stale inventory data leads to incorrect recommendations
**Required:** Hourly sync of inventory from Odoo to Supabase
**Deadline:** End of Phase 1

**Options:**
- N8N workflow ($20/month, easy)
- Python script (free, more work)

---

### Blocker #4: Production Capacity Data (LOW)
**Status:** ❓ NEEDS INPUT
**Owner:** Francis + Production Manager
**Impact:** Cannot build production calendar without capacity limits
**Required:** Weekly capacity numbers
**Deadline:** Start of Phase 4

**Required Data:**
```
Max bottles per week: _____ (e.g., 12,000)
Max liters per week: _____ (e.g., 4,260L)
Average production time per 1000 bottles: _____ hours
```

---

## 7. FRANCIS'S VISION vs CURRENT STATE

### What Francis Asked For (His Vision)
**From Lines 204-240 in Clients_Messages_Important.txt:**

#### Module 1: Sales Projections ✅ COMPLETE
- Week vs last year → **✅ BUILT**
- Month vs last year → **✅ BUILT**
- Period vs last year → **✅ BUILT**
- SAQ 13-period calendar → **✅ BUILT**

#### Module 2: Production Planning ❌ NOT BUILT
- Quantities to produce by SKU → **❌ NOT STARTED**
- Production priorities (short/mid-term) → **❌ NOT STARTED**
- Planning horizons (7/14/30 days) → **❌ NOT STARTED**

#### Module 3: Purchase Planning ❌ NOT BUILT
- Packaging requirements (bottles, cans, closures, lids, boxes) → **❌ NOT STARTED**
- Raw material requirements (ingredients, alcohol, juice) → **❌ NOT STARTED**
- Inventory on hand → **⚠️ ODOO DATA STALE**
- Gap analysis → **❌ NOT STARTED**
- Action required (OK / TO ORDER) → **❌ NOT STARTED**

#### Module 4: Production Calendar ❌ NOT BUILT
- Calendar view (weekly/monthly) → **❌ NOT STARTED**
- SKUs to produce → **❌ NOT STARTED**
- Quantities → **❌ NOT STARTED**
- Plant capacity → **❌ NOT STARTED**
- Conflict visibility → **❌ NOT STARTED**

---

### Progress Summary
```
Overall Completion: 35%

✅ Sales Analytics: 100% COMPLETE
✅ Inventory Monitoring: 100% COMPLETE
✅ Data Import Pipeline: 100% COMPLETE
❌ Production Planning: 0% COMPLETE
❌ Purchase Planning: 0% COMPLETE
❌ Production Calendar: 0% COMPLETE
⚠️ Odoo Integration: 25% COMPLETE (tables exist, sync missing)
```

---

## 8. RECOMMENDED NEXT STEPS (Action Plan)

### Immediate Actions (This Week)

#### Action 1: Secure SAQ-Odoo Product Mapping
**Owner:** Francis → Patrick
**Deadline:** February 3, 2026
**Deliverable:** Complete CSV file with all 76 mappings
**Instructions for Patrick:**
1. Export Odoo products with SKU field "default_code" (e.g., CR-MARG-355)
2. Match to SAQ codes from `saq_product` table
3. Provide CSV in format:
   ```
   saq_code,odoo_product_id,odoo_product_name,odoo_default_code
   ```

---

#### Action 2: Export Sample BOM from Odoo
**Owner:** Patrick
**Deadline:** February 3, 2026
**Deliverable:** Excel/CSV export of BOM for 1 finished good (e.g., RTD Margarita)
**Required Fields:**
- Finished good product name and ID
- Component product names and IDs
- Quantity per unit
- UOM (liters, kg, units)

---

#### Action 3: Approve Phase 1 Roadmap
**Owner:** Francis
**Deadline:** February 3, 2026
**Deliverable:** Go/no-go decision on 5-phase implementation plan
**Questions for Francis:**
1. Does the roadmap match your priorities?
2. Is 5-week timeline acceptable?
3. Who will provide production capacity data for Phase 4?
4. Budget approval for N8N Cloud ($20/month)?

---

### Week 1 Tasks (If Approved)

#### Task 1: Build Production Plan Algorithm
**Owner:** Ahmed
**Dependencies:** SAQ-Odoo mapping (Action 1)
**Deliverable:** Python script to calculate production needs
**Estimated Time:** 2-3 days

---

#### Task 2: Set Up Odoo Inventory Sync
**Owner:** Ahmed
**Dependencies:** Odoo API credentials
**Deliverable:** N8N workflow or Python script
**Estimated Time:** 1 day

---

#### Task 3: Create Database Tables
**Owner:** Ahmed
**Dependencies:** None
**Deliverable:** Execute SQL to create 5 new tables (Section 3.1)
**Estimated Time:** 1 hour

---

## 9. QUESTIONS FOR FRANCIS

### Strategic Questions
1. **Production Priorities:** How do you currently decide which SKU to produce first? Profitability, SAQ demand, shelf life, other factors?

2. **Safety Stock:** What's your minimum stock buffer? (e.g., "Never go below 2 weeks of inventory")

3. **Production Capacity:** Can you share weekly/monthly production capacity? (bottles per week, or liters per week?)

4. **Batch Sizes:** Are there minimum or maximum production batch sizes per SKU?

5. **Lead Times:** Are the 465 supplier lead times in the `lead_times` table accurate and current?

### Operational Questions
6. **Odoo Access:** Can Patrick provide Odoo API credentials for automated data sync?

7. **BOM Accuracy:** Are all finished goods in Odoo with complete, up-to-date BOMs?

8. **ID Foods Tracking:** How should we track actual ID Foods orders vs forecasts? (Currently only forecast upload exists)

9. **Bars & Restaurants:** Where is this sales data? Odoo sales orders? Separate system?

10. **PO Generation:** In Phase 5, should the system auto-generate draft POs in Odoo, or just provide a "TO ORDER" list?

---

## 10. COST & TIMELINE ESTIMATES

### Development Cost Breakdown

#### Phase 1: Data Foundation (1 week)
- Developer time: 20 hours @ $75/hr = **$1,500**
- N8N Cloud: $20/month = **$20**
- **Phase 1 Total: $1,520**

#### Phase 2: Production Planning (2 weeks)
- Developer time: 60 hours @ $75/hr = **$4,500**
- **Phase 2 Total: $4,500**

#### Phase 3: Purchase Planning (1 week)
- Developer time: 30 hours @ $75/hr = **$2,250**
- **Phase 3 Total: $2,250**

#### Phase 4: Production Calendar (1 week)
- Developer time: 30 hours @ $75/hr = **$2,250**
- **Phase 4 Total: $2,250**

#### Phase 5: Automation (1 week)
- Developer time: 20 hours @ $75/hr = **$1,500**
- **Phase 5 Total: $1,500**

---

### Total Project Cost
**Development:** $12,000
**Monthly Recurring:** $20 (N8N Cloud)
**Timeline:** 6 weeks (assuming no delays from blockers)

---

### Cost Savings Analysis
**Manual Effort Saved:**
- 10 hours/week spent manually checking SAQ inventory
- 5 hours/week calculating production needs
- 3 hours/week checking raw material stock
- **Total:** 18 hours/week @ $50/hr = **$900/week saved**

**ROI Timeline:** 13 weeks (3 months) to break even

---

## 11. APPENDIX: Technical Architecture

### Current Stack
- **Database:** Supabase (PostgreSQL)
- **Dashboard:** Retool (cloud-hosted)
- **Automation:** N8N (cloud-hosted)
- **Data Pipeline:** Python scripts (Windows scheduled tasks)
- **Scraping:** Selenium + ChromeDriver

### Proposed Additions
- **Odoo Sync:** N8N workflow or Python script (hourly)
- **Production Planning:** SQL stored procedures + Python logic
- **BOM Explosion:** SQL recursive queries

---

### Database Schema Summary (Current)
**SAQ Tables (Complete):**
- `saq_ventes` (historical sales)
- `saq_daily_warehouse` (warehouse inventory)
- `saq_daily_stores` (store inventory)
- `saq_order_status` (open orders)
- `saq_product` (product catalog)
- `saq_stores` (store territories)

**Odoo Tables (Stale):**
- `products` (all products)
- `stock_quants` (inventory levels)
- `stock_movements` (inventory movements)
- `bom_lines` (bill of materials)
- `purchase_orders` (POs)
- `purchase_order_lines` (PO line items)

**Needed Tables (Not Exist):**
- `production_plan`
- `packaging_requirements`
- `raw_material_requirements`
- `production_schedule`
- `production_capacity`

---

### Dashboard Views (Current)
**Existing:**
1. `v_po_prediction` - Weeks of stock calculation
2. `v_yoy_sales` - Year-over-year sales comparison
3. `v_open_orders` - Open SAQ orders
4. `v_store_inventory_summary` - Store inventory by product
5. `v_store_inventory_by_banner` - Store inventory by banner
6. `v_sales_trend` - Weekly sales trend
7. `v_dashboard_kpi` - Top-level KPIs

**Needed:**
1. `v_production_plan_summary`
2. `v_packaging_requirements_summary`
3. `v_raw_material_requirements_summary`
4. `v_production_calendar`

---

## 12. CONCLUSION

The Cherry River COO Cockpit has a **solid foundation** for SAQ sales analytics and inventory monitoring. The weekly data import pipeline is operational and automated. However, **the core production and purchase planning modules do not exist yet**.

To complete Francis's vision, we need:

1. **Immediate:** SAQ-Odoo product mapping from Patrick
2. **Week 1:** Odoo inventory sync + production plan algorithm
3. **Weeks 2-3:** Build production planning dashboard
4. **Weeks 4-5:** Build purchase planning + production calendar
5. **Week 6:** Automation and alerts

**Total Time:** 6 weeks
**Total Cost:** $12,000 + $20/month
**ROI:** 3 months

The biggest blocker is the **SAQ-Odoo product mapping**. Without this, we cannot proceed with production planning. Once Patrick provides this mapping, development can begin immediately.

**Recommendation:** Approve Phase 1 and secure the product mapping this week to start Phase 2 next week.

---

**Document Prepared By:** Ahmed (Lead Developer)
**Date:** January 29, 2026
**Status:** Ready for Client Review
**Next Review Date:** February 5, 2026 (after Phase 1 completion)
