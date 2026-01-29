# Cherry River - COO Dashboard Status Update
**Date:** January 28, 2026

---

## ✅ COMPLETED FEATURES

### 1. SAQ Sales & Inventory Dashboard (Live)
- Real-time warehouse inventory visibility (Montreal & Quebec City)
- Automatic alerts when products need reordering (COMMANDER / SURVEILLER / OK)
- Year-over-year sales comparison by product and SAQ period
- Open orders tracking with delivery countdown
- Store-level inventory across 381+ SAQ locations
- KPI summary cards (total stock, units on order, bottles in stores)

### 2. Automated Daily Data Updates
- Daily inventory updates flow automatically from Patrick's automated rapport
- Warehouse, store inventory, and order status refresh daily
- No manual data entry required for SAQ data

### 3. ID Foods Forecast Management
- System ready for Alyssa to upload ID Foods forecasts (3-4x per year)
- Simple CSV upload form — paste data, click submit
- Monthly forecast view by product

### 4. Product Lead Times
- All 465 supplier lead times imported and linked to Odoo products
- Foundation ready for production planning calculations


![COO Cockpit](COOCockpit.png)

---

## 🔄 IN PROGRESS / NEXT PHASE

### 1. ID Foods Tracking
- **Need:** Actual order data from ID Foods to compare forecast vs reality
- **Deliverable:** Dashboard showing forecast accuracy and variance

### 2. Bars & Restaurants (Private Imports)
- **Need:** Clarify data source (Odoo sales orders?)
- **Deliverable:** Sales tracking by restaurant/bar client

### 3. Production Planning
- **Need:** Finalize BOM data sync from Odoo
- **Deliverable:** "What to produce" recommendations based on forecasted demand

### 4. Purchasing Planning
- **Need:** Inventory thresholds for raw materials & packaging
- **Deliverable:** Automated alerts for bottles, cans, ingredients, etc.

---

## 🔮 FUTURE PHASES

- Production calendar with capacity planning
- Automated PO generation and supplier email drafts
- Logistics module (pickup scheduling, bills of lading)

---

## 📊 CURRENT DASHBOARD ACCESS

The dashboard is live and accessible in Retool. Data refreshes automatically.

**What Francis can do now:**
- See which products SAQ will order soon
- Compare this year's sales vs last year
- Track all open SAQ orders and delivery dates
- View inventory distribution across all SAQ stores

---

## ⚠️ BLOCKERS - WHAT WE NEED TO PROCEED

### 1. SAQ to Odoo Product Mapping (From Patrick)

We need a file that links SAQ product codes to Odoo product IDs. This is critical for:

- **Production Planning:** Knowing which Odoo product to produce when SAQ stock is low
- **Inventory Reconciliation:** Matching SAQ sales data with Odoo inventory
- **BOM Explosion:** Calculating raw material needs based on SAQ demand

**Required format:**

| SAQ Code | Odoo Product ID | Product Name |
|----------|-----------------|--------------|
| 14001338 | 78 | Cherry River Vodka Premium |
| 14064873 | ??? | Cherry River Érable |
| ... | ... | ... |

Patrick mentioned he would provide this mapping. Once received, we can:
- Link SAQ demand forecasts to Odoo production
- Calculate raw material requirements automatically
- Enable the full production planning module

### 2. ID Foods Actual Orders

To show forecast vs actual comparison, we need:
- Historical order data from ID Foods (what they actually ordered)
- Or: set up a process to log incoming ID Foods POs

### 3. Bars & Restaurants Data Source

Clarification needed:
- Are bar/restaurant sales tracked in Odoo as sales orders?
- If yes, which customer category identifies them?
- If no, how is this data currently tracked?

---

## 📞 ACTION ITEMS

| Item | Owner | Status |
|------|-------|--------|
| Provide SAQ-to-Odoo product mapping | Patrick | Pending |
| Confirm ID Foods order tracking method | Francis | Pending |
| Clarify bars/restaurants data source | Francis | Pending |
| Dashboard refinements based on feedback | Dev Team | Ready when above items received |
