# Relevance AI Knowledge Base Implementation Plan
## SAQ Data Integration Strategy

---

## Overview

This document provides the **exact** knowledge base schemas, mapping tables, and agent integration strategy for SAQ data in Relevance AI.

---

## Knowledge Base Architecture

### Summary Table

| KB Name | Records Est. | Update Freq | Purpose | Priority |
|---------|-------------|-------------|---------|----------|
| `saq_products` | ~50-200 | Weekly | Product master reference | 🔴 Critical |
| `saq_weekly_sales` | ~50K/year | Weekly | Sales transactions by store | 🔴 Critical |
| `saq_store_inventory` | ~5K-10K | Weekly | Current stock levels | 🔴 Critical |
| `saq_store_master` | ~400 | Monthly | Store metadata & rep assignments | 🔴 Critical |
| `saq_rep_assignments` | ~5 | Quarterly | Representative territories | 🟡 Important |

---

## KB #1: `saq_products` (Product Master)

### Purpose
Master reference for all Cherry River products sold through SAQ.

### Data Source
- **File**: `My_Products.csv` (from SAQ portal)
- **Matching to Odoo**: Manual mapping CSV (to be created)

### Schema

```json
{
  "knowledge_table": "saq_products",
  "id_column_name": "saq_code",
  "fields": {
    "saq_code": "string",              // Primary key: SAQ product code (e.g., "14545132")
    "product_name": "string",          // Product description from SAQ
    "supplier_no": "string",           // Your supplier number (17972428)
    "sales_price": "float",            // Retail price at SAQ
    "format": "string",                // Bottle size (e.g., "355ml", "750ml")
    "category": "string",              // Product category
    "alcohol_percent": "float",        // Alcohol %
    "product_type": "string",          // Type of product
    "odoo_product_id": "int",          // MAPPED: Odoo product.product ID
    "odoo_product_name": "string",     // MAPPED: Odoo product name
    "odoo_default_code": "string",     // MAPPED: Odoo SKU (e.g., "CR-MARG-355")
    "is_cherry_river": "boolean",      // Always true (filter for your products only)
    "is_active": "boolean",            // Active in SAQ catalog
    "last_updated": "datetime"         // Last sync timestamp
  }
}
```

### Example Record

```json
{
  "saq_code": "14545132",
  "product_name": "Cherry River RTD Margarita 355ml",
  "supplier_no": "17972428",
  "sales_price": 5.75,
  "format": "355ml",
  "category": "Ready-to-Drink Cocktails",
  "alcohol_percent": 5.0,
  "product_type": "RTD",
  "odoo_product_id": 45,
  "odoo_product_name": "RTD Margarita 355ml",
  "odoo_default_code": "CR-MARG-355",
  "is_cherry_river": true,
  "is_active": true,
  "last_updated": "2025-12-29T10:00:00Z"
}
```

---

## KB #2: `saq_weekly_sales` (Transaction Data - MOST CRITICAL)

### Purpose
Weekly sales transactions by store - enables rupture detection, forecasting, and representative performance tracking.

### Data Source
- **File**: `Weekly_Sales_Selected_Products.csv` (from SAQ portal)
- **Update**: Weekly (every Monday after SAQ data refresh)

### Schema

```json
{
  "knowledge_table": "saq_weekly_sales",
  "id_column_name": "id",
  "fields": {
    "id": "string",                    // Generated: {saq_code}_{store_no}_{year}_{period}_{week}
    "saq_code": "string",              // Product code (links to saq_products)
    "product_name": "string",          // Denormalized from saq_products
    "store_no": "string",              // SAQ store number (e.g., "23001")
    "store_name": "string",            // MAPPED: Store name
    "store_region": "string",          // MAPPED: Territory (e.g., "Montreal", "Quebec")
    "representative_name": "string",   // MAPPED: Sales rep name
    "representative_email": "string",  // MAPPED: Sales rep email
    "client_type": "string",           // Client type code from SAQ
    "year": "int",                     // 2025
    "period": "int",                   // Period number (1-13)
    "week": "int",                     // Week number (1-4)
    "date_range": "string",            // Calculated: "2025-P10-W1" (for display)
    "qty_bottles": "int",              // Quantity sold (units)
    "amount": "float",                 // Revenue ($)
    "odoo_product_id": "int",          // Matched from saq_products
    "is_rupture": "boolean",           // Calculated: qty = 0 AND prev weeks had sales
    "week_over_week_change": "float",  // Calculated: % change vs previous week
    "last_updated": "datetime"         // Sync timestamp
  }
}
```

### Example Records

```json
// Normal sale
{
  "id": "14545132_23016_2025_10_2",
  "saq_code": "14545132",
  "product_name": "Cherry River RTD Margarita 355ml",
  "store_no": "23016",
  "store_name": "SAQ Sélection Montreal Centre",
  "store_region": "Montreal",
  "representative_name": "Sophie Sabourin",
  "representative_email": "sophie@cherryriver.ca",
  "client_type": "02",
  "year": 2025,
  "period": 10,
  "week": 2,
  "date_range": "2025-P10-W2",
  "qty_bottles": 12,
  "amount": 678.00,
  "odoo_product_id": 45,
  "is_rupture": false,
  "week_over_week_change": 15.5,
  "last_updated": "2025-12-29T10:00:00Z"
}

// Rupture detected
{
  "id": "14545132_23054_2025_10_2",
  "saq_code": "14545132",
  "product_name": "Cherry River RTD Margarita 355ml",
  "store_no": "23054",
  "store_name": "SAQ Dépôt Laval",
  "store_region": "Laval",
  "representative_name": "Sophie Sabourin",
  "representative_email": "sophie@cherryriver.ca",
  "client_type": "02",
  "year": 2025,
  "period": 10,
  "week": 2,
  "date_range": "2025-P10-W2",
  "qty_bottles": 0,
  "amount": 0.00,
  "odoo_product_id": 45,
  "is_rupture": true,
  "week_over_week_change": -100.0,
  "last_updated": "2025-12-29T10:00:00Z"
}
```

---

## KB #3: `saq_store_inventory` (Current Stock Levels)

### Purpose
Real-time inventory snapshot at each SAQ store - critical for "minimum stock" alerts.

### Data Source
- **File**: `Inventories_By_Branch.csv` (from SAQ portal)
- **Update**: Weekly

### Schema

```json
{
  "knowledge_table": "saq_store_inventory",
  "id_column_name": "id",
  "fields": {
    "id": "string",                    // Generated: {store_no}_{saq_code}_{snapshot_date}
    "store_no": "string",              // SAQ store number
    "store_name": "string",            // MAPPED: Store name
    "store_region": "string",          // MAPPED: Territory
    "representative_name": "string",   // MAPPED: Sales rep
    "representative_email": "string",  // MAPPED: Rep email
    "saq_code": "string",              // Product code
    "product_name": "string",          // Denormalized
    "qty_inventory": "int",            // Current stock level (units)
    "year": "int",                     // 2025
    "period": "int",                   // Period
    "week": "int",                     // Week
    "snapshot_date": "date",           // The "DATE DU JOUR" from CSV
    "odoo_product_id": "int",          // Matched
    "avg_weekly_sales": "float",       // Calculated from saq_weekly_sales (last 4 weeks)
    "days_of_inventory": "float",      // Calculated: (qty / avg_daily_sales)
    "is_below_minimum": "boolean",     // Calculated: days_of_inventory < 14
    "is_critical": "boolean",          // Calculated: days_of_inventory < 7
    "last_updated": "datetime"
  }
}
```

### Example Record

```json
{
  "id": "23016_14545132_2025-12-20",
  "store_no": "23016",
  "store_name": "SAQ Sélection Montreal Centre",
  "store_region": "Montreal",
  "representative_name": "Sophie Sabourin",
  "representative_email": "sophie@cherryriver.ca",
  "saq_code": "14545132",
  "product_name": "Cherry River RTD Margarita 355ml",
  "qty_inventory": 6,
  "year": 2025,
  "period": 10,
  "week": 2,
  "snapshot_date": "2025-12-20",
  "odoo_product_id": 45,
  "avg_weekly_sales": 10.5,
  "days_of_inventory": 4.0,
  "is_below_minimum": true,
  "is_critical": true,
  "last_updated": "2025-12-29T10:00:00Z"
}
```

---

## KB #4: `saq_store_master` (Store Reference Data)

### Purpose
Store-level metadata including representative assignments and territory mapping.

### Data Source
- **Manual creation** based on SAQ store list + representative assignments from client

### Schema

```json
{
  "knowledge_table": "saq_store_master",
  "id_column_name": "store_no",
  "fields": {
    "store_no": "string",              // Primary key: SAQ store number
    "store_name": "string",            // Store name (if available)
    "store_address": "string",         // Full address (if available)
    "store_city": "string",            // City
    "store_region": "string",          // Territory for rep assignment
    "representative_name": "string",   // Assigned sales rep
    "representative_email": "string",  // Rep email
    "store_type": "string",            // "Sélection", "Dépôt", "Express", etc.
    "is_active": "boolean",            // Store is active
    "priority_level": "string",        // "High", "Medium", "Low" (based on sales volume)
    "notes": "string",                 // Any special notes
    "last_updated": "datetime"
  }
}
```

### Representative Territory Mapping (Based on Client Info)

| Representative Name | Email | Territory | Store Region Codes |
|---------------------|-------|-----------|-------------------|
| Priscila Auger | priscilla@cherryriver.ca | Québec | Quebec City, Levis, surrounding |
| Junior Rivas Torres | junior@cherryriver.ca | North Shore of Montréal & Gatineau | Laval, North Shore, Gatineau |
| Jacob Guyon | jacob@cherryriver.ca | Estrie & South Shore | Sherbrooke, Longueuil, South Shore |
| Alycia Gagné | alycia@cherryriver.ca | Québec & Northern Québec | Quebec City, Saguenay, Rimouski |
| Sophie Sabourin | sophie@cherryriver.ca | Montréal & Laurentides | Montreal Island, Laurentides |

### Example Record

```json
{
  "store_no": "23016",
  "store_name": "SAQ Sélection Montreal Centre",
  "store_address": "677 Rue Sainte-Catherine Ouest, Montreal, QC H3B 5K4",
  "store_city": "Montreal",
  "store_region": "Montreal",
  "representative_name": "Sophie Sabourin",
  "representative_email": "sophie@cherryriver.ca",
  "store_type": "Sélection",
  "is_active": true,
  "priority_level": "High",
  "notes": "High-volume downtown location",
  "last_updated": "2025-12-29T10:00:00Z"
}
```

---

## KB #5: `saq_rep_assignments` (Representative Master)

### Purpose
Master table for sales representatives - used for escalation logic and reporting.

### Schema

```json
{
  "knowledge_table": "saq_rep_assignments",
  "id_column_name": "email",
  "fields": {
    "email": "string",                 // Primary key
    "name": "string",                  // Full name
    "territory": "string",             // Territory description
    "alert_level": "string",           // "24h", "48h", "72h"
    "role": "string",                  // "Sales Rep", "Manager", "Admin"
    "is_active": "boolean",
    "phone": "string",
    "last_updated": "datetime"
  }
}
```

### Example Records

```json
[
  {
    "email": "sophie@cherryriver.ca",
    "name": "Sophie Sabourin",
    "territory": "Montréal & Laurentides",
    "alert_level": "24h",
    "role": "Sales Rep",
    "is_active": true,
    "phone": "",
    "last_updated": "2025-12-29T10:00:00Z"
  },
  {
    "email": "alyssa@cherryriver.ca",
    "name": "Alyssa Delage",
    "territory": "All Territories",
    "alert_level": "48h",
    "role": "Sales Manager",
    "is_active": true,
    "phone": "",
    "last_updated": "2025-12-29T10:00:00Z"
  },
  {
    "email": "francis@cherryriver.ca",
    "name": "Francis Delage",
    "territory": "All Territories",
    "alert_level": "72h",
    "role": "Admin",
    "is_active": true,
    "phone": "",
    "last_updated": "2025-12-29T10:00:00Z"
  }
]
```

---

## Required Mapping Tables (Manual Creation)

### 1. SAQ-to-Odoo Product Mapping

**File**: `saq_odoo_product_mapping.csv`

```csv
saq_code,odoo_product_id,odoo_product_name,odoo_default_code
14545132,45,"RTD Margarita 355ml","CR-MARG-355"
14682882,46,"Mocktail Amaretto Sour 355ml","CR-AMAR-355"
14954892,47,"RTD Moscow Mule 355ml","CR-MOSC-355"
```

**How to create**:
1. Export unique products from `My_Products.csv`
2. Match each SAQ code to corresponding Odoo `product.product` record
3. Verify with client which products are actively sold

---

### 2. SAQ Store-to-Territory Mapping

**File**: `saq_store_territory_mapping.csv`

```csv
store_no,store_name,store_city,store_region,representative_name,representative_email
23001,"SAQ Sélection Montreal Downtown","Montreal","Montreal","Sophie Sabourin","sophie@cherryriver.ca"
23002,"SAQ Dépôt Quebec","Quebec","Quebec","Priscila Auger","priscilla@cherryriver.ca"
23016,"SAQ Sélection Montreal Centre","Montreal","Montreal","Sophie Sabourin","sophie@cherryriver.ca"
23054,"SAQ Dépôt Laval","Laval","North Shore","Junior Rivas Torres","junior@cherryriver.ca"
```

**How to create**:
1. Extract unique store numbers from `Inventories_By_Branch.csv` or `Weekly_Sales_Selected_Products.csv`
2. Research SAQ store locations (publicly available on SAQ.com)
3. Map each store to representative based on territory assignments
4. Validate with client

---

## Agent Query Examples

### Query 1: "Were there any stock ruptures by sales territory last week?"

**Agent Logic**:
1. Get current week number
2. Query `saq_weekly_sales` WHERE:
   - `week = current_week - 1`
   - `is_rupture = true`
3. Group by `store_region`, `representative_name`, `saq_code`
4. Join with `saq_products` for product names
5. Return formatted report

**Example Output**:
```
Stock Ruptures - Week 1, Period 10, 2025:

Territory: Montreal (Rep: Sophie Sabourin)
  - RTD Margarita 355ml: 3 stores (23016, 23054, 23081)
  - Mocktail Amaretto Sour 355ml: 1 store (23102)

Territory: Quebec (Rep: Priscila Auger)
  - RTD Moscow Mule 355ml: 2 stores (23002, 23008)
```

---

### Query 2: "Which stores are currently under minimum stock?"

**Agent Logic**:
1. Query `saq_store_inventory` WHERE `is_below_minimum = true`
2. Join with `saq_store_master` for rep info
3. Sort by `days_of_inventory` ASC (most urgent first)
4. Return detailed breakdown

**Example Output**:
```
⚠️ LOW STOCK ALERTS (< 14 days inventory):

CRITICAL (< 7 days):
  Store: 23016 - SAQ Sélection Montreal Centre
  Product: RTD Margarita 355ml
  Current Stock: 6 units
  Days Until Rupture: 4 days
  Rep: Sophie Sabourin (sophie@cherryriver.ca)

WARNING (7-14 days):
  Store: 23054 - SAQ Dépôt Laval
  Product: RTD Margarita 355ml
  Current Stock: 20 units
  Days Until Rupture: 13 days
  Rep: Sophie Sabourin (sophie@cherryriver.ca)
```

---

### Query 3: "What replenishment orders must be generated?"

**Agent Logic**:
1. Query `saq_store_inventory` WHERE `is_below_minimum = true`
2. Calculate recommended order quantity:
   - `target_stock = avg_weekly_sales * 4` (4 weeks buffer)
   - `order_qty = target_stock - qty_inventory`
3. Check Odoo `stock_quant_odoo` for Cherry River warehouse stock
4. Flag if insufficient inventory to fulfill
5. Return replenishment recommendations

**Example Output**:
```
📦 RECOMMENDED REPLENISHMENT ORDERS:

Store: 23016 - SAQ Sélection Montreal Centre
  Product: RTD Margarita 355ml
  Current Stock: 6 units
  Recommended Order: 36 units (4 weeks @ 10.5 units/week)
  Cherry River Inventory: 1,200 units ✓ Available
  Rep: Sophie Sabourin (sophie@cherryriver.ca)

Store: 23054 - SAQ Dépôt Laval
  Product: RTD Margarita 355ml
  Current Stock: 20 units
  Recommended Order: 22 units (4 weeks @ 10.5 units/week)
  Cherry River Inventory: 1,200 units ✓ Available
  Rep: Sophie Sabourin (sophie@cherryriver.ca)

TOTAL ORDER NEEDED: 58 units of RTD Margarita 355ml
```

---

## Implementation Checklist

### Phase 1: Data Preparation (Week 1)
- [ ] Run `saq_data_scraper.py` to download all SAQ data
- [ ] Create `saq_odoo_product_mapping.csv` (manual)
- [ ] Create `saq_store_territory_mapping.csv` (manual)
- [ ] Validate all Cherry River products are in mapping
- [ ] Validate representative assignments with client

### Phase 2: N8N Workflow Development (Week 1-2)
- [ ] Build N8N workflow: Process `My_Products.csv` → `saq_products` KB
- [ ] Build N8N workflow: Process `Weekly_Sales_Selected_Products.csv` → `saq_weekly_sales` KB
- [ ] Build N8N workflow: Process `Inventories_By_Branch.csv` → `saq_store_inventory` KB
- [ ] Build N8N workflow: Upload `saq_store_master` KB (from manual CSV)
- [ ] Build N8N workflow: Upload `saq_rep_assignments` KB (from manual CSV)
- [ ] Add calculated fields logic (is_rupture, days_of_inventory, etc.)
- [ ] Test with sample data (10 records each)

### Phase 3: Full Data Load (Week 2)
- [ ] Run full historical load (90 days of sales data if available)
- [ ] Validate record counts in Relevance AI
- [ ] Verify product matching accuracy (target: >95%)
- [ ] Check for data quality issues (nulls, duplicates, etc.)

### Phase 4: Agent Deployment (Week 2-3)
- [ ] Update "Production & Supply Chain Agent" prompt with SAQ KBs
- [ ] Deploy "Inventory Forecasting & Planning Agent" (requires SAQ data)
- [ ] Test agent queries:
  - Stock ruptures by territory
  - Stores under minimum stock
  - Replenishment recommendations
  - Sales velocity analysis
- [ ] Validate agent accuracy with client

### Phase 5: Automation & Monitoring (Week 3-4)
- [ ] Schedule `saq_data_scraper.py` (weekly, Monday 6 AM)
- [ ] Schedule N8N workflows to auto-process new downloads
- [ ] Set up Slack/Email alerts for:
  - Scraper failures
  - Data quality issues
  - Agent errors
- [ ] Create dashboard for data freshness monitoring

---

## Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Product Matching Accuracy | >95% | Count matched records / total SAQ products |
| Data Freshness | <7 days | Check `last_updated` timestamps |
| Agent Query Success Rate | >90% | Monitor agent error logs |
| Rupture Detection Accuracy | >95% | Validate against manual checks |
| Representative Assignment Accuracy | 100% | Verify with client team |

---

## Next Steps After Implementation

1. **Build Alert System**: Auto-email reps when stores hit low stock
2. **Create Weekly Report**: Auto-generate Monday morning rupture summary
3. **Forecasting Dashboard**: Visualize 30-day demand projections
4. **Production Planning Integration**: Link SAQ forecasts to Odoo MRP
5. **Performance Analytics**: Track rep performance by territory

---

**End of Document**
