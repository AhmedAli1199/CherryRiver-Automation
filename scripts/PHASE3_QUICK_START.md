# Phase 3: Production Planning - READY TO USE!

## ✅ You Already Have Everything You Need!

Looking at your Supabase schema, you already have all the data syncing from Odoo:

### Data Sources (All Live via n8n)

| Data Needed | Where It Comes From | Status |
|-------------|-------------------|---------|
| Cherry River Inventory | `products.qty_available` | ✅ Syncing |
| Lead Times | `products.x_lead_time_days` OR `lead_times.lead_time_days` | ✅ Syncing |
| Safety Stock | `products.x_min_stock` | ✅ Syncing |
| SAQ Warehouse Inventory | `saq_inventaire_entrepot` | ✅ Syncing |
| Sales Forecasts | Phase 2 functions | ✅ Working |
| BOM Data | `bom_lines` table | ✅ Syncing (for Phase 4) |

**No CSV files needed. No manual data entry needed.**

---

## Deploy Phase 3 (5 minutes)

### Step 1: Run the Schema

1. Open Supabase SQL Editor
2. Copy and paste entire contents of [phase3_production_planning.sql](phase3_production_planning.sql)
3. Click "Run"
4. Should see: "Phase 3 schema created - Using existing Odoo data!"

### Step 2: Generate Production Plans

Run this:
```sql
SELECT generate_all_production_plans(14);
```

Should return: `24` (number of products planned)

### Step 3: Review Results

```sql
SELECT
    product_name,
    cherry_river_stock_bottles,
    saq_warehouse_stock_bottles,
    total_available_bottles,
    forecasted_demand_bottles,
    recommended_production_bottles,
    production_priority,
    days_until_stockout
FROM v_production_summary
ORDER BY production_priority, forecasted_demand_bottles DESC;
```

---

## What You'll See

### Example Output:

| product_name | cherry_river | saq_warehouse | total | forecast_14d | recommended | priority | days_until_stockout |
|-------------|--------------|---------------|-------|--------------|-------------|----------|---------------------|
| Limonade Petits Fruits | 1,200 | 8,400 | 9,600 | 6,623 | 0 | NONE | 20 |
| 6 Pack Mixologie | 0 | 2,400 | 2,400 | 3,784 | 1,384 | HIGH | 4 |
| Orange sanguine | 500 | 3,600 | 4,100 | 3,693 | 0 | LOW | 15 |

**Translation:**
- **Limonade Petits Fruits**: You have enough stock (9,600 bottles), no production needed
- **6 Pack Mixologie**: Only 4 days of stock left, need to produce 1,384 units NOW (HIGH priority)
- **Orange sanguine**: Comfortable stock level, no urgency

---

## Understanding Priority Levels

| Priority | Meaning | What to Do |
|----------|---------|------------|
| **HIGH** 🔴 | Will run out before production completes | Start production TODAY |
| **MEDIUM** 🟡 | Need production to meet forecast | Schedule production this week |
| **LOW** 🟢 | Sufficient stock but could replenish | No urgency, monitor |
| **NONE** ⚪ | Overstocked | Do not produce |

---

## Check Urgent Items

```sql
SELECT * FROM v_production_high_priority;
```

Shows only products that **need immediate production** (stockout risk).

---

## About Bottles Per Case

I assumed **12 bottles per case** for SAQ inventory conversion.

If some products have different case sizes (like 24-packs), you can:
1. Check SAQ product specs for actual case size
2. Update the conversion in the view (line 25, 41 of the SQL)
3. Or add a `bottles_per_case` field to `products` table in Odoo

For now, 12 bottles/case is a reasonable default.

---

## Next Steps

1. **Deploy Phase 3** (run the SQL)
2. **Generate plans** (`SELECT generate_all_production_plans(14);`)
3. **Review with Francis** - Show him the production summary
4. **Act on HIGH priority items** - Start production today
5. **Weekly updates** - Re-run after SAQ data updates

---

## Weekly Automation

Add to your weekly SAQ update workflow:

**After SAQ data import, run:**
```sql
SELECT generate_all_production_plans(14);
```

This refreshes production recommendations with latest sales and inventory data.

---

## Questions?

- **"Why is everything HIGH priority?"** - Check if Odoo inventory sync is working (`SELECT * FROM v_current_inventory`)
- **"Forecasts are 0"** - Go back to Phase 2, verify forecast function works
- **"Lead times missing"** - Check if `products.x_lead_time_days` or `lead_times` table has data

**You're ready to go!** Just run the SQL and you'll have working production planning.
