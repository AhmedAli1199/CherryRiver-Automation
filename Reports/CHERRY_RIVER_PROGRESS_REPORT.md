# Cherry River - COO Weekly Ops Pack
## Progress Report & Next Steps

**Prepared for:** Francis
**Date:** January 2026
**Project:** Automated Inventory Intelligence & Decision Support System

---

## Executive Summary

We have successfully built the foundation of Alyssa's COO Weekly Ops Pack - an automated system that monitors SAQ store inventory, identifies critical stockouts, and provides actionable intelligence every Monday morning.

**Current Status:** Phase 1 Complete (SAQ Intelligence) - Ready for Demo
**Next Milestone:** SAQ-Odoo Integration (Requires product mapping)

---

## What We've Built So Far

### 1. SAQ Data Pipeline (100% Complete)

**What it does:**
- Automatically downloads weekly sales and inventory data from SAQ
- Processes data for all 24 Cherry River products across 390+ SAQ stores
- Calculates sales velocity, days of inventory, and stockout risk
- Updates database every week (can be automated for Monday 6 AM)

**Business Value:**
- No more manual data downloads from SAQ portal
- Real-time visibility into store-level performance
- Historical tracking of sales trends

---

### 2. Automated Email Alerts (100% Complete)

**What it does:**
- Sends daily email alerts to sales reps when their stores have critical inventory issues
- Groups alerts by territory (Sophie → Montreal, Junior → North Shore, etc.)
- Highlights urgent ruptures vs. routine restocking needs

**Business Value:**
- Sales reps know exactly which stores need attention
- No more checking spreadsheets manually
- Faster response to stockouts = fewer lost sales

---

### 3. COO Dashboard - SAQ Intelligence (65% Complete)

**What it does:**
- Single-page view of entire SAQ network health
- Color-coded sections showing urgency levels
- Drill-down tables for detailed investigation
- One-click export to CSV for reporting

#### Dashboard Sections:

**Executive Summary (Green)**
| Metric | Current Value | Status |
|--------|---------------|--------|
| Overall Rupture Rate | 3.1% | ✅ Below 5% target |
| Inventory Turnover | 19.9x/year | ✅ Excellent (industry: 20-30x) |
| Weekly Sales | $820,391 | ✅ Strong performance |
| Avg Sales per Store | $2,104 | ✅ Healthy |

**Critical Actions Required (Red)**
| Metric | Current Value | Meaning |
|--------|---------------|---------|
| Critical Ruptures | 3 locations | High-volume stores (>10 bottles/week) completely out of stock |
| Stores Affected | 3 stores | Need immediate restocking |
| Products in Crisis | 3 SKUs | These products are losing sales RIGHT NOW |

**Routine Operations (Blue)**
| Metric | Current Value | Meaning |
|--------|---------------|---------|
| Routine Stockouts | 68 locations | Low-volume stores, normal restocking cycle |
| Products for Restock | 15 items | Standard weekly restocking |
| Total Stockout Rate | 71 of 2,299 (3.1%) | Well within normal operations |

**Risk Monitoring (Orange)**
| Metric | Current Value | Meaning |
|--------|---------------|---------|
| High Risk Locations | 241 locations | Less than 2.5 weeks of supply |
| Medium Risk Locations | 38 locations | 2.5-4 weeks of supply |
| Stores with Alerts | 297 stores (76%) | Proactive monitoring coverage |

---

### 4. Detailed Drill-Down Reports (100% Complete)

Alyssa can click any card to see full details:

**Critical Ruptures Detail:**
- Exact product name, store name, location
- Sales rep responsible
- Weekly sales velocity (shows business impact)
- Recommended order quantity

**Routine Stockouts Detail:**
- Prioritized by sales velocity
- Low-volume stores identified
- Standard restocking quantities

**Risk Monitoring Detail:**
- Forecasted stockout dates
- Weeks of supply remaining
- Recommended order quantities

**Sales Performance by Product:**
- Top-selling products ranked
- Rupture rate per product
- Total inventory value

---



### Top 3 Priority Restocks Right Now

| Product | Store | Sales/Week | Impact |
|---------|-------|------------|--------|
| Cherry River Tequila Silver | SAQ Montreal Downtown | 18 bottles | High - Popular store |
| Cherry River Petits Fruits Basilic | Store 23102 | 17 bottles | High |
| Opémiska Boréal Bleuets | Store 23067 | 11 bottles | Medium |

### Products with Highest Rupture Rates

| Product | Stores Carrying | Stores in Rupture | Rate |
|---------|-----------------|-------------------|------|
| Collection Réconfort | 22 | 4 | 18.2% |
| Crème Glacée Coaticook | 53 | 6 | 11.3% |
| Opémiska Whisky Érable | 56 | 5 | 8.9% |

*Note: These may need attention in upcoming restocking cycles*

---

## What's Left to Complete the COO Weekly Ops Pack

### Phase 2: SAQ-Odoo Integration (Blocked - Need Your Input)

**The Missing Link:** We need a mapping between SAQ product codes and your Odoo product IDs.

**Why it matters:**
- Currently we know: "SAQ stores need 450 bottles of Tequila"
- We can't answer: "Do we have 450 bottles in Cherry River's warehouse?"
- We can't generate: "Produce 330 more bottles" or "Ship from warehouse"

**What we need from you:**

A simple spreadsheet:

| SAQ Code | Cherry River Product Name | Odoo Product ID |
|----------|---------------------------|-----------------|
| 14954892 | Cherry River Tequila Silver 750ml | ? |
| 14758699 | Opémiska Boréal Bleuets Sauvages | ? |
| ... | ... | ... |

**How to get this:**
- Option A: Export from Odoo if SAQ codes are stored there
- Option B: Manual mapping (30 minutes of your time)
- Option C: We extract from your SAQ invoices if available

---

### Phase 3: Complete COO Cockpit (After Mapping)

Once we have the mapping, we will add:

**1. Supply Chain View**
- SAQ Demand vs. Warehouse Stock (side by side)
- "Can we fulfill this order from warehouse?" - Yes/No
- "Do we need to produce more?" - Automatically calculated

**2. PO Recommendations**
- Auto-generated purchase orders based on demand
- Alyssa clicks "Approve" → Creates PO in Odoo
- No more manual calculations

**3. Production Priority List**
- Which products to produce first (7-14 day horizon)
- Based on SAQ demand + current warehouse stock
- Includes raw material requirements

**4. 30-Day Demand Forecast**
- Projected stockouts by week
- Production scheduling recommendations
- Early warning for seasonal demand changes

---

## Technical Architecture (Simplified)

```
┌─────────────────┐     ┌─────────────────┐
│   SAQ Portal    │     │     Odoo        │
│  (Store Data)   │     │  (Warehouse)    │
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│            Supabase Database            │
│    (Central Data Storage & Processing)  │
└────────────────────┬────────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│  Retool Dashboard │   │  N8N Workflows  │
│  (COO Cockpit)    │   │  (Email Alerts) │
└─────────────────┘     └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│           Alyssa (COO)                  │
│    Approves actions in < 30 minutes     │
└─────────────────────────────────────────┘
```

---

## Success Criteria Progress

| Criteria | Target | Current Status |
|----------|--------|----------------|
| COO can approve all weekly actions in < 30 minutes | 100% | 60% (SAQ side ready, need Odoo integration) |
| No SKU enters stockout without appearing in COO Brief | 100% | ✅ 100% (All 24 SKUs monitored) |
| Automated Monday morning reports | Enabled | ✅ Ready (just need to schedule) |
| Email alerts to sales reps | Enabled | ✅ Complete |
| PO generation from dashboard | Enabled | 🔄 Pending (needs mapping) |
| Production scheduling | Enabled | 🔄 Pending (needs mapping) |

---

## Recommended Next Steps

### Immediate (This Week)

1. **Review this dashboard** - Does the information make sense? Any changes needed?
2. **Provide SAQ-Odoo mapping** 
3. **Confirm Alyssa's requirements** - Any additional metrics she needs?

### Short-Term (Next 2 Weeks)

1. Load mapping into system
2. Build unified SAQ + Odoo view
3. Add PO recommendation engine
4. Test with Alyssa

### Medium-Term (Month 2)

1. Automate Monday 6 AM runs
2. Add production scheduling
3. Integrate approval workflow with Odoo
4. Train Alyssa on full system

---

## Questions for Francis

1. **SAQ-Odoo Mapping:** Can you provide this mapping, or should we extract it from invoices?

2. **Approval Workflow:** Should Alyssa be the only approver, or should POs route to multiple people?

3. **Odoo Integration:** Do you want us to create POs directly in Odoo, or generate them for manual entry?

4. **Production Planning:** Who manages production scheduling? Should they have access to the dashboard?

5. **Historical Data:** Do you want us to load historical SAQ data (past weeks/months) for trend analysis?

---

## Summary

**What you're getting:**
- Complete visibility into SAQ store inventory across Quebec
- Automated alerts before stockouts happen
- One dashboard for all operational decisions
- < 30 minute weekly approval workflow

**What's working today:**
- 24 products monitored
- 390 stores tracked
- 3.1% rupture rate (excellent)
- $820K weekly sales visibility
- Automated email alerts

**What's next:**
- Connect SAQ demand to Cherry River warehouse
- Auto-generate PO recommendations
- Production scheduling integration

---

*Dashboard available at: https://ahmedsarpak999.retool.com/embedded/public/c4485a73-5d3f-417b-902c-ba21ff830064*
