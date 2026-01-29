# Cherry River COO Cockpit - Quick Summary
**Date:** January 29, 2026

---

## Overall Progress: 35% Complete

```
┌─────────────────────────────────────────────────────────────┐
│                    COO COCKPIT STATUS                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ✅ Sales Analytics              [████████████] 100%      │
│  ✅ Inventory Monitoring          [████████████] 100%      │
│  ✅ Data Pipeline                 [████████████] 100%      │
│  ❌ Production Planning           [░░░░░░░░░░░░]   0%      │
│  ❌ Purchase Planning             [░░░░░░░░░░░░]   0%      │
│  ❌ Production Calendar           [░░░░░░░░░░░░]   0%      │
│  ⚠️  Odoo Integration             [███░░░░░░░░░]  25%      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## What's Working Today ✅

### 1. SAQ Sales Dashboard
- Year-over-year comparison by product and period
- Weekly sales velocity calculations
- Sales trending (up/down indicators)
- Historical sales data back to 2021

### 2. Inventory Alerts
- Real-time warehouse stock (Montreal + Quebec)
- Weeks of stock remaining calculation
- Automated reorder alerts:
  - 🔴 CRITICAL: < 7 days of stock
  - 🟡 WARNING: < 14 days of stock
  - ✅ OK: > 14 days of stock

### 3. Store Monitoring
- 381+ SAQ store inventory tracking
- Rupture detection (0 stock alerts)
- Territory assignment to sales reps
- Daily email alerts to sales team

### 4. Data Automation
- Automated CSV import from SAQ B2B portal
- Daily warehouse/store inventory updates
- Weekly sales data processing
- N8N email workflow (Mon-Fri 9 AM)

---

## What's Missing ❌

### 1. Production Planning Module
**Francis Wants:**
- Which SKUs to produce next week
- Production priorities (urgent, short-term, mid-term)
- Quantities to produce per SKU
- 7/14/30 day planning horizons

**Current Status:** NOT STARTED

**Blocker:** Need SAQ-Odoo product mapping (only 2 of 76 products mapped)

---

### 2. Purchase Planning Module
**Francis Wants:**

**A. Packaging Requirements:**
- Bottles (glass, various sizes)
- Cans (355ml aluminum)
- Closures (caps, corks)
- Lids (can tops)
- Carton boxes (shipping cases)

**B. Raw Materials:**
- Ingredients (flavoring compounds)
- Flavors (natural/artificial)
- Neutral alcohol
- Rum
- Tequila
- Juice (mixers, concentrates)

**For Each Item:**
- Required quantity (based on production plan)
- Inventory on hand (from Odoo)
- Gap (required - on hand)
- Action: OK or TO ORDER

**Current Status:** NOT STARTED

**Blocker:**
1. Need complete BOM data from Odoo
2. Need automated Odoo inventory sync

---

### 3. Production Calendar
**Francis Wants:**
- Weekly/monthly calendar view
- SKUs scheduled for production
- Quantities per week
- Plant capacity visualization
- Conflict/overload indicators

**Current Status:** NOT STARTED

**Blocker:** Need production capacity data (max bottles/week)

---

## Critical Blockers 🚨

### Blocker #1: SAQ-Odoo Product Mapping (CRITICAL)
**Status:** ❌ BLOCKED
**Owner:** Patrick (Odoo admin)
**Impact:** Cannot calculate production needs
**Current:** 2 products mapped (2.6%)
**Needed:** 76 products mapped (100%)

**Required Format:**
```csv
saq_code,odoo_product_id,odoo_product_name
14545132,45,RTD Margarita 355ml
14682882,46,Mocktail Amaretto Sour 355ml
14001338,78,Cherry River Vodka Premium
... (73 more rows)
```

---

### Blocker #2: BOM Data Verification (HIGH)
**Status:** ⚠️ UNCLEAR
**Owner:** Patrick + Francis
**Impact:** Cannot calculate raw material needs

**Questions:**
1. Are all finished goods in Odoo with complete BOMs?
2. Do BOMs include both packaging AND raw materials?
3. Are quantities in correct units?

**Action Required:** Export sample BOM for 1 product to verify structure

---

### Blocker #3: Odoo Inventory Sync (MEDIUM)
**Status:** ⚠️ NOT AUTOMATED
**Owner:** Ahmed (developer)
**Impact:** Stale inventory data → incorrect recommendations

**Solution Options:**
- Option A: N8N workflow ($20/month, easy setup)
- Option B: Python script (free, more complex)

---

## 6-Week Roadmap 🗓️

### Phase 1: Data Foundation (1 week)
**Goal:** Get SAQ-Odoo mapping + set up Odoo sync
- Patrick provides product mapping
- Verify BOM data structure
- Set up automated Odoo inventory sync

---

### Phase 2: Production Planning (2 weeks)
**Goal:** Build "what to produce" dashboard
- Production plan algorithm
- BOM explosion logic
- Dashboard views (priorities, quantities, deadlines)
- Retool production planning dashboard

---

### Phase 3: Purchase Planning (1 week)
**Goal:** Build "what to order" dashboard
- Packaging requirements view
- Raw material requirements view
- Supplier lead time integration
- Retool purchase planning dashboard

---

### Phase 4: Production Calendar (1 week)
**Goal:** Visual weekly/monthly production schedule
- Define production capacity
- Build production scheduler
- Calendar view in Retool
- Capacity utilization tracking

---

### Phase 5: Automation & Alerts (1 week)
**Goal:** Auto-generate recommendations
- Daily production plan generation
- Email alerts for production manager
- Slack integration (optional)

---

## Required Data from Francis/Patrick 📋

### From Patrick (Odoo Admin):
1. ✅ **SAQ-Odoo Product Mapping** (CSV with 76 products)
2. ✅ **Sample BOM Export** (1 finished good to verify structure)
3. ✅ **Odoo API Credentials** (for automated inventory sync)

### From Francis (Operations):
1. ✅ **Production Capacity Data**
   - Max bottles per week: _______
   - Max liters per week: _______
   - Production time per 1000 bottles: _______ hours

2. ✅ **Safety Stock Policy**
   - Minimum stock buffer: _______ days/weeks
   - Reorder trigger: When stock < _______ days

3. ✅ **Production Priorities**
   - How do you decide which SKU to produce first?
   - Profitability? SAQ demand? Other factors?

---

## Cost Estimate 💰

### Development Cost
```
Phase 1: Data Foundation          $1,500
Phase 2: Production Planning      $4,500
Phase 3: Purchase Planning        $2,250
Phase 4: Production Calendar      $2,250
Phase 5: Automation               $1,500
─────────────────────────────────────────
TOTAL:                           $12,000
```

### Monthly Recurring
```
N8N Cloud:                           $20
Supabase:                            $0 (Free tier)
Retool:                              $0 (Existing)
─────────────────────────────────────────
TOTAL:                               $20/month
```

### ROI Calculation
**Manual Effort Saved:**
- Checking SAQ inventory: 10 hrs/week
- Calculating production needs: 5 hrs/week
- Checking raw material stock: 3 hrs/week
- **Total:** 18 hrs/week @ $50/hr = **$900/week saved**

**Break-Even:** 13 weeks (3 months)

---

## Next Steps (This Week) 🚀

### Step 1: Patrick - Provide SAQ-Odoo Mapping
**Deadline:** February 3, 2026
**Deliverable:** CSV file with all 76 mappings
**Priority:** CRITICAL (blocks all production planning work)

### Step 2: Patrick - Export Sample BOM
**Deadline:** February 3, 2026
**Deliverable:** Excel/CSV with BOM for 1 product
**Priority:** HIGH

### Step 3: Francis - Approve Roadmap
**Deadline:** February 3, 2026
**Decision:** Go/no-go on 6-week implementation plan
**Priority:** HIGH

---

## Key Insights 🔍

### What's Working Well
1. **SAQ Data Pipeline:** Fully automated, reliable
2. **Sales Analytics:** Comprehensive YoY comparisons
3. **Inventory Monitoring:** Real-time alerts working
4. **Email Alerts:** Sales reps receiving daily notifications

### What Needs Work
1. **Odoo Integration:** Tables exist but data is stale
2. **Product Mapping:** Only 2 of 76 products mapped
3. **BOM Data:** Structure unclear, needs verification
4. **Production Logic:** No algorithm exists yet

### Why We're Stuck
**Root Cause:** Missing SAQ-Odoo product mapping

Without knowing which SAQ product corresponds to which Odoo product, we cannot:
- Calculate production quantities
- Explode BOMs for raw materials
- Match sales demand to production capacity
- Generate purchase orders

**Solution:** Patrick provides complete mapping → unblocks Phases 2-5

---

## Questions for Francis ❓

### Strategic
1. How do you currently decide which SKU to produce first?
2. What's your minimum stock buffer policy?
3. Are there minimum/maximum production batch sizes?

### Operational
4. Can Patrick provide Odoo API credentials for sync?
5. Are all finished goods in Odoo with complete BOMs?
6. How should we track actual ID Foods orders vs forecasts?
7. Where is bars/restaurants sales data? (Odoo or separate?)

### Future
8. Should the system auto-generate draft POs in Odoo?
9. Do you want Slack notifications in addition to email?
10. Mobile dashboard access required?

---

## Visual Architecture 🏗️

```
┌─────────────────────────────────────────────────────────┐
│                    DATA SOURCES                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  SAQ B2B Portal  ─────┐                                │
│  (Daily CSVs)         │                                │
│                       ├──→ Supabase PostgreSQL         │
│  Odoo ERP        ─────┤    (Central Database)          │
│  (Inventory, BOMs)    │                                │
│                       │                                │
│  ID Foods        ─────┘                                │
│  (Forecast CSVs)                                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  PROCESSING LAYER                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ✅ Sales Velocity Calculator                          │
│  ✅ Inventory Alert Engine                             │
│  ✅ YoY Comparison Logic                               │
│  ❌ Production Plan Algorithm   ← NOT BUILT           │
│  ❌ BOM Explosion Engine         ← NOT BUILT           │
│  ❌ Purchase Recommender         ← NOT BUILT           │
│                                                         │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 DASHBOARD LAYER                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ✅ Retool: SAQ Sales Dashboard                        │
│  ✅ Retool: Inventory Alerts                           │
│  ✅ Retool: YoY Comparison                             │
│  ❌ Retool: Production Planning  ← NOT BUILT           │
│  ❌ Retool: Purchase Planning    ← NOT BUILT           │
│  ❌ Retool: Production Calendar  ← NOT BUILT           │
│                                                         │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  AUTOMATION LAYER                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ✅ N8N: Daily email alerts to sales reps              │
│  ✅ N8N: Rupture escalation (24h/48h/72h)              │
│  ⚠️  N8N: Odoo inventory sync    ← NEEDS SETUP        │
│  ❌ N8N: Production alerts       ← NOT BUILT           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Summary 📝

**What We Have:**
- Excellent SAQ sales and inventory monitoring
- Automated data pipeline
- Real-time alerts working

**What We Need:**
- SAQ-Odoo product mapping (CRITICAL)
- Production planning algorithm
- Purchase planning algorithm
- Production calendar

**Timeline:** 6 weeks after mapping received
**Cost:** $12,000 + $20/month
**ROI:** 3 months

**Recommendation:** Get product mapping from Patrick this week, approve roadmap, start Phase 1 next week.

---

**Prepared By:** Ahmed (Lead Developer)
**For:** Francis Delage, Cherry River
**Date:** January 29, 2026
**Status:** Ready for Review
