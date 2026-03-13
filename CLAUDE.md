# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

Automated weekly data pipeline for Cherry River's SAQ (Quebec liquor board) sales data. It scrapes the SAQ B2B portal using Selenium, processes the downloaded CSVs, and uploads to Supabase for a Retool dashboard.

## Running the Pipeline

```bash
# Full pipeline (scrape → unzip → upload to Supabase)
python run_weekly_pipeline.py

# Individual steps
python saq_data_scraper.py
python scripts/unzip_saq_files.py
python scripts/saq_weekly_update.py --folder "SAQ Documents 2"
```

Required environment variables (copy `.env.example` to `.env`):
```
SAQ_USERNAME, SAQ_PASSWORD, SUPABASE_URL, SUPABASE_KEY
```

The pipeline checks these at startup and exits immediately if any are missing.

## Architecture

```
run_weekly_pipeline.py          ← Orchestrator, runs all 3 steps in sequence
  ↓
saq_data_scraper.py             ← Selenium/Chrome logs into SAQ B2B portal
  SAQScraper class              ← Navigates to reports, downloads 6 CSVs/ZIPs
  → SAQ Documents 2/            ← Download directory
  ↓
scripts/unzip_saq_files.py      ← Extracts ZIPs, deletes them after
  ↓
scripts/saq_weekly_update.py    ← Reads CSVs, filters to Cherry River SKUs, uploads
  → saq_ventes                  ← Sales (APPEND only — never deleted)
  → saq_inventaire              ← Store inventory (UPSERT weekly)
  → saq_inventaire_entrepot     ← Warehouse inventory (UPSERT weekly)
  → saq_commandes               ← Orders (APPEND, deduped by no_commande)
```

**Additionally**, Patrick's daily automated rapport (via n8n webhook) populates three separate daily snapshot tables:
- `saq_daily_warehouse` — warehouse cases by MTL/QC, includes `uvc` and `inv_alloc_cdm`
- `saq_daily_stores` — store-level bottle inventory
- `saq_order_status` — open SAQ purchase orders

## Key Files

| File | Purpose |
|------|---------|
| `saq_data_scraper.py` | SAQ portal login + download (Selenium) |
| `run_weekly_pipeline.py` | Pipeline orchestrator |
| `scripts/saq_weekly_update.py` | CSV → Supabase uploader |
| `scripts/create_dashboard_views.sql` | All Supabase views for Retool dashboard |
| `scripts/create_daily_tables.sql` | Schema for daily snapshot tables + RPC functions |
| `.github/workflows/saq_weekly_update.yml` | GitHub Actions (runs Mondays 8 AM UTC) |

## Supabase Views (Dashboard)

All dashboard views are in `scripts/create_dashboard_views.sql`. Run this file in Supabase SQL Editor to deploy. Since views use `CREATE OR REPLACE`, you must `DROP` them first if renaming columns:

```sql
DROP VIEW IF EXISTS v_dashboard_kpi;
DROP VIEW IF EXISTS v_po_prediction;
-- then run the full SQL file
```

**`v_po_prediction`** — The core prediction view. Uses Patrick's anomaly-cleaned average:
1. Rank all weeks per product by sales (highest first)
2. Compute baseline average using all weeks **except** the top 4
3. Remove **all** weeks where `week_total > baseline * 1.5` (not just the top 4)
4. `weeks_of_stock = warehouse_bottles / cleaned_avg`
5. Alert: `< 4 weeks → COMMANDER`, `< 6 → SURVEILLER`, else `OK`

Warehouse stock uses `inventaire_cdm + inventaire_cdq` (cases) × `uvc` (bottles/case). Sales velocity is already in bottles from `saq_ventes.bouteille`. When `uvc` is NULL, defaults to 12.

**`v_sku_summary`** — The consolidated single source of truth per SKU. Combines:
- Gross physical warehouse stock (`inventaire_cdm` for MTL, `inventaire_cdq` for QC). Also exposes `warehouse_mtl_free` = `inv_alloc_cdm` (cases not yet spoken for by SAQ orders) as informational.
- Inbound orders from `saq_order_status` (statuses "Attente" + "Attente récept." only — `qty_commandee` is in **cases**, multiplied by `uvc` to get bottles)
- Lead time from existing `lead_times` table via `code_saq` column (added by migration). Stored in `lead_time_days`, converted to weeks by dividing by 7. Default 72 days (~10 weeks) when not set.
- `weeks_of_stock` = warehouse only; `weeks_of_stock_total` = warehouse + inbound
- Alert based on effective stock (warehouse + inbound combined)

**Warehouse stock fields explained** (`saq_daily_warehouse`):
- `inventaire_cdm` = gross physical cases at MTL warehouse (use this for reorder calculations)
- `inv_alloc_cdm` = MTL cases not yet allocated to SAQ store orders (informational only; can be 0 when all stock is spoken for but not yet shipped)
- `inventaire_cdq` = gross physical cases at QC warehouse (no allocation equivalent exists)

## Product Filtering

76 Cherry River SAQ product codes are hardcoded in `scripts/saq_weekly_update.py` in the `CHERRY_RIVER_CODES` set. All CSV processing filters to only these codes.

## CSV Format

SAQ CSVs use:
- Delimiter: `;` (semicolon)
- Encoding: `latin-1`
- Date format: `YYYY/MM/DD`

## GitHub Actions

Scheduled: every Monday at 8 AM UTC via `.github/workflows/saq_weekly_update.yml`. Uses Xvfb virtual display (not headless Chrome) for stability. Secrets must be added as **repository secrets** (not environment secrets) unless the workflow specifies `environment:`.

Chrome driver initialization in `saq_data_scraper.py` tries three fallback methods: local `chromedriver.exe` → PATH → Selenium auto-download.

## Supabase Patterns

```python
# Insert
supabase.table('table_name').insert(rows).execute()

# Upsert with composite key
supabase.table('table_name').upsert(rows, on_conflict='col1,col2').execute()

# Check existence before insert
existing = supabase.table('t').select('id').eq('col', val).limit(1).execute()
```

All uploads use batch size of 500 rows.
