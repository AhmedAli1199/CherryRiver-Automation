# Salesrep Cockpit — Session Handoff

> Last updated: 2026-03-05
> Resume by reading this file + `sql/vw_cockpit_product_summary.sql`

---

## What We're Building

A Retool dashboard for Cherry River sales reps at `cherryriver2.retool.com`.
Supabase resource: **"Cherry River Core Data Supabase"**

**Phase 1 goal**: Replicate the main product sales table from `https://saq.cherryriver.ca/` inside Retool.

One row per Cherry River product (~80 products) with these columns:
`Code | Name | P11LY | P11TY | Var% | S1 | S2 | S3 | S4 | PTDLY | PTDTY | Var% | CDM I | CDQ I | Succ | NB Succ | TotalLY | TotalTY`

---

## Current State

### SQL View: READY TO DEPLOY
File: `salesrep_cockpit/sql/vw_cockpit_product_summary.sql`

**Run this file in Supabase SQL Editor.** It will create `vw_cockpit_product_summary`.

Then verify:
```sql
SELECT COUNT(*) FROM vw_cockpit_product_summary;
-- Expected: ~80 rows

SELECT * FROM vw_cockpit_product_summary LIMIT 5;
-- Check s4 > 0 for active products, cdm_i/cdq_i match today's warehouse report
```

### Data Sources Used
| Source | What it provides | Why this one |
|---|---|---|
| `saq_ventes` | All sales columns (P11LY/TY, S1-S4, PTD, totals) | Live — updated weekly by pipeline |
| `saq_daily_warehouse` | CDM I, CDQ I inventory | Live — updated daily by Patrick's n8n |
| `saq_product` | Product list + `format_caisse` for unit conversion | Cherry River catalog only |

**DO NOT use** `saq_ventes_sommaire` — it's a static snapshot from Mar 2 (missing P12 W4 data).
**DO NOT use** `saq_inventaire_entrepot` — superseded by `saq_daily_warehouse`.

### Units
- `saq_ventes.bouteille` = **bottles** → divide by `saq_product.format_caisse` → **cases**
- `saq_daily_warehouse` inventory = already in **cases**
- All output columns are in **cases** (matching WordPress table format)

---

## Known Issues / Bugs

### 1. n8n daily warehouse update is broken (two bugs)
**Bug A** — Wrong ON CONFLICT clause:
```sql
-- WRONG (what n8n currently sends):
ON CONFLICT (code_saq) DO UPDATE SET ...

-- CORRECT (matches the UNIQUE constraint on the table):
ON CONFLICT (code_saq, date_inventaire) DO UPDATE SET ...
```
Fix this in the n8n workflow node that inserts into `saq_daily_warehouse`.

**Bug B** — n8n server IP not in Supabase allowlist:
Error: `Address not in tenant allow_list: {72, 62, 171, 103}`
Fix: Supabase Dashboard → Settings → Network Restrictions → Add `72.62.171.103/32`

### 2. WordPress "Succ" column not understood
WordPress table shows "Succ = 1,264.79" (a decimal, NOT a store count).
The NB Succ column (91 -9 (76/15)) is the store count — our `succ`/`nb_succ_*` columns match that.
The "Succ" column source needs to be investigated in `wp_wpdatatables.csv`.

---

## Verified Working (from comparison test)
For product 15168156, after dividing our bottles by 24:
- P11LY ✅, P11TY ✅, S1 ✅, S2 ✅, S3 ✅, PTDLY ✅, TotalLY ✅

---

## Next Steps

1. **Deploy the view** — paste `vw_cockpit_product_summary.sql` into Supabase SQL Editor
2. **Fix n8n** — update ON CONFLICT clause + add IP to Supabase allowlist
3. **Build Retool table**:
   - Create Resource Query using `vw_cockpit_product_summary`
   - Bind to Table component
   - Format: Var% columns red if negative, NB Succ as combined `91 -9 (76/15)` string
   - Add product_type filter (RTD / Spirits) and name search bar
4. **Add summary rows** — second query grouped by product_type for totals at bottom
5. **Investigate Succ column** — check wp_wpdatatables.csv Table ID 2 SQL

---

## Project Context

### Francis's Supabase migration (completed ~Mar 2 2026)
- Migrated ~4.1M rows from WordPress/MySQL to Supabase
- 6 existing views deployed with `vw_` prefix (store-level, rep territory, commissions, etc.)
- saq_product: 80 rows, Cherry River catalog only (NOT 155K WordPress catalog)
- saq_product enhanced columns: `product_type`, `commission_rate`, `format_caisse`, `nom_acf`

### Key file locations
| File | Purpose |
|---|---|
| `salesrep_cockpit/sql/vw_cockpit_product_summary.sql` | Main view (ready to deploy) |
| `salesrep_cockpit/messages.txt` | WhatsApp with Francis — context/requirements |
| `salesrep_cockpit/MEMORY.md` | Francis's own Claude Code memory from his machine |
| `salesrep_cockpit/wp_wpdatatables.csv` | Actual SQL queries from WordPress table plugin |
| `scripts/create_daily_tables.sql` | Schema for saq_daily_warehouse and related tables |
| `scripts/create_dashboard_views.sql` | All existing Supabase views |

### SAQ calendar
- 13 periods per year, ~4 weeks each
- Current: 2025 / Period 12 / Week 4
- Column naming in flat tables: P[period][week] e.g. P121 = Period 12 Week 1
