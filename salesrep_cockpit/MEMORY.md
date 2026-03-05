# SAQ Cherry River Migration — Project Memory

## Project Goal
Migrate WordPress SAQ sales management system to Supabase + Retool.
Source: https://saq.cherryriver.ca/wp-admin (GeneratePress theme)

## Credentials (change WP password after migration!)
- WP admin: delagefrancis@icloud.com / Samuel1995!!$
- Supabase host: aws-0-us-east-2.pooler.supabase.com
- Supabase db: postgres, user: postgres.nqxqqoinpoomcqdddoqq
- **Supabase password: NOT YET PROVIDED — must ask user**
- phpMyAdmin URL: https://saq.cherryriver.ca/wp-content/plugins/wp-phpmyadmin-extension/lib/phpMyAdmin_x2n1c9AfgBpVvKUkQXRTEWb/
- MySQL DB name: aa59ec0f_saq

## Extraction Status (completed)
- ✅ 29 WordPress users exported → saq_export/data/wp_users.csv
- ✅ All table schemas → saq_export/schema/*.txt
- ✅ 21 Gravity Forms JSON → saq_export/gf_forms/form_*.json
- ✅ 22,880 GF entries → saq_export/data/wp_gf_entry.csv
- ✅ 129,692 GF entry meta → saq_export/data/wp_gf_entry_meta.csv
- ✅ All operational tables (CSVs) → saq_export/data/
- ✅ Large tables (ventes 71MB, inventaire 31MB, etc.) → saq_export/data/
- ✅ PHP code → saq_export/php_code/ (functions.php 136K, shortcodes.php 484K, promopunch.php 14K)

## Key PHP Files
- functions.php: All AJAX handlers, shortcodes, GF hooks
- shortcodes.php: [gravity-form-list-product-and-qty] shortcode (484KB!)
- promopunch.php: Promo punch shortcode

## Key Forms (GF)
- Form 13: Rapport de visite (visit report) — 15 fields: date, time, rep, succursale, type, notes, recall
- Form 16: Promo Punch — 11 fields: date, time, rep, succursale, type, notes, période
- Form 11: Planification et gestion de temps — 19 fields
- Form 18: Demande de produits — 9 fields

## Database Tables Summary (5M total rows)
### Core operational (small):
- saq_commandes: 132 rows (orders)
- saq_commandes_items: 234 rows
- saq_meeting: 7 rows
- saq_heures_travail: 953 rows
- saq_demandes_reps: 7 rows
- saq_references: 6,463 rows
- saq_promotion: 9,739 rows
- saq_alerts: 104,497 rows
- saq_alerts_comments: 25,417 rows
- saq_comissions: 10,524 rows
- saq_delegate_alert: 42 rows
### Reference/catalog:
- saq_product: 155,213 rows (SAQ wine catalog)
### B2B:
- b2b_customers: 242, b2b_orders: 2,583, b2b_orders_items: 4,342
### Large import/analytics:
- saq_ventes: 1,035,364 rows (raw sales)
- saq_ventes_sommaire: 2,155,881 rows
- saq_inventaire: 522,384 rows

## Extraction Tools
- db_extract.py: paginated PMA queries (for small tables)
- export_large.py: single-request CSV/SQL export (for large tables)
- parse_gf_forms.py: parses GF form JSON from SQL export

## Supabase Connection (CONFIRMED WORKING)
- Host: aws-1-us-east-2.pooler.supabase.com (note: aws-**1**, not aws-0!)
- Port: 5432 (session pooler)
- User: postgres.nqxqqoinpoomcqdddoqq
- Password: Cherryriver2026!
- Direct host: db.nqxqqoinpoomcqdddoqq.supabase.co (IPv6 only, not reachable from this machine)
- IP allowlist: 174.88.231.112 must be in Supabase network restrictions

## Migration Status: COMPLETE
**4,112,830 rows imported** into Supabase on 2026-03-02.

### What was imported:
- gf_form/meta: 21 forms, 21 meta
- gf_entry: 22,880 entries, 129,692 meta, 21 notes
- wp_users: 29 reps, wp_usermeta: 611
- saq_alerts: 104,497, saq_alerts_comments: 25,417
- saq_inventaire: 522,384 (truncated+reimported)
- saq_inventaire_entrepot: 7,456
- saq_ventes_sommaire: 2,155,881
- saq_ventes_full: 431,552, saq_ventes_flat: 168,794
- All promotion, reference, b2b, heures_travail, etc. tables

### Preserved (not imported — different schema in new system):
- saq_ventes (295K Cherry River-specific rows, IDs 1-1.3M)
- saq_commandes (42 rows, new OP-XXXXXX format)
- saq_product (79 rows, Cherry River catalog only)

### Import scripts (in project dir):
- run_import.py — main import (use --resume to skip existing)
- fix_remaining.py — fixes for schema mismatches
- fix_wp_users.py — wp_users row-by-row with error handling
- verify_import.py — row count verification
- audit_schema.py — compare DB schema vs CSV headers

### Known data quality notes:
- Flat tables (ventes_flat, inventaire_flat, etc.): only P01-P25 imported (DB schema limit)
- saq_references: 6,447 of 6,463 (16 rows had encoding issues)
- wp_usermeta: 611 of 811 (200 rows malformed/skipped)
- b2b_orders: 25 of 44 CSV columns imported (new system has fewer cols)

## Step 3+4: Views + Commission Validator (COMPLETE 2026-03-02)

### Live views (vw_ prefix, all GRANTED to authenticated):
- vw_visit_history — GF Form 13 pivoted. Key fields: entry_id, date_visite, representant, rep_user_id, succursale_id (SAQ store#), type_rapport, confirmation_commande
- vw_promo_investments — GF Form 16 pivoted. Key fields: date_promo, representant, succursale_id, periode_choix
- vw_store_alerts — Alert counts + last visit date per store + couleur_alerte (lightpink/lightyellow/white/lightgreen based on days_since_visit)
- vw_sales_main_dashboard — saq_ventes by product+store+period with product_type, taux_commission_cad, format_caisse, commission_potentiel_cad
- vw_rep_territory_sales — Sales by rep (rep→store from visit history form 13)
- vw_commissions_summary — saq_comissions with decoded COMP period/week + commission_cad + commission_gagnee_cad

### Commission validator function:
- Function: validate_commissions() → INTEGER (count of commissions confirmed)
- Conditions: (1) visit exists for store in form 13 field_10=succ_id, (2) field_17='Oui' OR saq_commandes match, (3) saq_daily_stores qty>0 after visit
- pg_cron NOT installed: SCHEDULE via Supabase Dashboard → Database → Extensions → pg_cron
  Then: SELECT cron.schedule('validate-commissions-daily','0 11 * * *','SELECT validate_commissions()');

### saq_product enhanced columns (authoritative ACF data):
- product_type: 'spirits' (25 products $5/c12) or 'rtd' (5 products $2.50/c24)
- commission_rate: NUMERIC(5,2), format_caisse: INTEGER, nom_acf: VARCHAR, exclure_alertes: BOOLEAN
- RTD codes: 14960213, 15588353, 15168156, 15298014, 15474217
- Edge case: 15525563 Collection Réconfort (spirits, $5, caisse=6)

### GF Form 13 field map:
- field_8=date_visite (YYYY-MM-DD), field_9=rep_user_id, field_10=succursale_id (SAQ#)
- field_6=representant (text), field_7=succursale_nom (text)
- field_15=type_rapport, field_1=notes, field_17=confirmation_commande (Oui/Non)
- field_11.1=has_rappel, field_12=date_rappel

### Key join patterns:
- saq_comissions.succ_id::text = saq_daily_stores.store_id
- saq_comissions.prod_id::text = saq_product.code_saq
- gf_entry_meta.meta_value (field_10)::integer = saq_comissions.succ_id

### Step 3+4 SQL/scripts:
- create_views_and_validator.sql — all views + validate_commissions()
- update_commission_views.sql — refined 3 views using ACF commission_rate/format_caisse
- update_product_acf.py — parses wp_options.sql, updates saq_product
- deploy_views.py, deploy_updated_views.py — deployment scripts

## Step 5: Rep→Store Mapping (COMPLETE 2026-03-02)

### saq_stores new column: rep_user_id (INTEGER)
- Also populated: sales_rep_name, sales_rep_email
- 379 stores assigned across 6 reps (3 unassigned; 10 shared between reps → last update wins)

### Rep assignments:
| WP user_id | Name                | Email                       | Stores |
|-----------|---------------------|-----------------------------|--------|
| 29        | Junior Rivas Torres | junior@cherryriver.ca       | 93     |
| 30        | Priscilla Auger     | priscilla@cherryriver.ca    | 76     |
| 31        | Jacob Guyon         | jacob@cherryriver.ca        | 75     |
| 36        | Sophie Sabourin     | sophie@cherryriver.ca       | 59     |
| 42        | Alycia Gagné        | alycia@cherryriver.ca       | 46     |
| 43        | Cassandre           | cassandre@cherryriver.ca    | 30     |

### How the mapping works:
- wp_usermeta meta_key='succursales' → PHP serialized array of WP post IDs
- wp_postmeta meta_key='outlet_nono_succursale' → SAQ store number (5-digit)
- IMPORTANT: wp_usermeta CSV was truncated by phpMyAdmin HTML table (50 chars limit)
  → Must query live via SQL using SUBSTRING_INDEX to explode serialized arrays into rows
- Script: map_rep_stores.py
