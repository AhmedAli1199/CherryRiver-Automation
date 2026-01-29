"""
SAQ to Supabase Processor - V2 (CORRECTED)
Uses "Mes produits.csv" as master list, filters all other files by those SAQ codes
Matches exact Supabase schema column names
"""

import os
import pandas as pd
from pathlib import Path
from datetime import datetime, timedelta
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Configuration
PROJECT_DIR = Path(__file__).parent.parent
SAQ_DIR = PROJECT_DIR / "SAQ Documents 2"
MAPPINGS_DIR = PROJECT_DIR / "mappings"

# Supabase connection
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in .env file")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

class SAQProcessorV2:
    """SAQ Data Processor - Uses Mes produits.csv as master list"""

    def __init__(self):
        """Initialize processor and load Cherry River product list"""
        logger.info("Initializing SAQ Processor V2...")

        # Load store territory mapping (for alerts)
        store_map_path = MAPPINGS_DIR / "saq_store_territory_mapping.csv"
        if store_map_path.exists():
            self.store_mapping = pd.read_csv(store_map_path)
            logger.info(f"✓ Loaded {len(self.store_mapping)} store mappings")
        else:
            logger.warning(f"⚠️  Store mapping not found: {store_map_path}")
            self.store_mapping = pd.DataFrame()

        # Load Cherry River product list from "Mes produits.csv"
        self.cherry_river_products = self.load_cherry_river_products()

    def load_cherry_river_products(self) -> set:
        """Load list of Cherry River SAQ codes from Mes produits.csv"""
        logger.info("=" * 80)
        logger.info("LOADING CHERRY RIVER PRODUCT LIST")
        logger.info("=" * 80)

        mes_produits_path = SAQ_DIR / "Mes produits.csv"

        if not mes_produits_path.exists():
            logger.error(f"❌ Mes produits.csv not found at: {mes_produits_path}")
            return set()

        try:
            df = pd.read_csv(mes_produits_path, delimiter=';', encoding='latin-1')
            logger.info(f"✓ Read Mes produits.csv: {len(df)} products")

            # Extract SAQ codes
            saq_codes = df['CODE SAQ (CIP)'].astype(str).unique()
            saq_codes_set = set(saq_codes)

            logger.info(f"✓ Loaded {len(saq_codes_set)} unique Cherry River SAQ codes")
            logger.info(f"Sample codes: {list(saq_codes_set)[:5]}")

            return saq_codes_set

        except Exception as e:
            logger.error(f"❌ Failed to load Mes produits.csv: {e}")
            return set()

    def read_saq_csv(self, filename: str) -> pd.DataFrame:
        """Read SAQ CSV with proper encoding and delimiter"""
        csv_path = SAQ_DIR / filename

        if not csv_path.exists():
            logger.error(f"❌ File not found: {csv_path}")
            return pd.DataFrame()

        logger.info(f"Reading {filename}...")

        encodings = ['latin-1', 'utf-8', 'iso-8859-1', 'cp1252']

        for encoding in encodings:
            try:
                df = pd.read_csv(csv_path, delimiter=';', encoding=encoding)
                logger.info(f"✓ Read {len(df)} rows with encoding: {encoding}")
                return df
            except:
                continue

        logger.error(f"❌ Failed to read {filename}")
        return pd.DataFrame()

    def process_products(self):
        """Process product master data from Mes produits.csv + Produits.csv"""
        logger.info("=" * 80)
        logger.info("PROCESSING SAQ PRODUCTS (Master Data)")
        logger.info("=" * 80)

        # Read Mes produits (your product list)
        mes_produits = self.read_saq_csv("Mes produits.csv")

        if mes_produits.empty:
            logger.error("❌ Cannot proceed without Mes produits.csv")
            return

        # Read full Produits.csv for additional details
        produits = self.read_saq_csv("Produits.csv")

        records = []

        for _, row in mes_produits.iterrows():
            saq_code = str(row['CODE SAQ (CIP)'])

            # Base info from Mes produits
            record = {
                "saq_code": saq_code,
                "description": str(row['DESCRIPTION']),
                "supplier_no": str(row['NO FOURNISSEUR']),
                "created_at": datetime.now().isoformat()
            }

            # Try to enrich from Produits.csv
            if not produits.empty:
                # Find matching product in Produits.csv
                saq_col = 'SAQ CODE (IPC)/CODE SAQ (CIP)'
                match = produits[produits[saq_col].astype(str) == saq_code]

                if not match.empty:
                    prod_row = match.iloc[0]
                    record["format"] = str(prod_row.get('FORMAT/FORMAT ARTICLE', ''))
                    record["sales_price"] = float(prod_row.get('PRODUCT SALES PRICE/PRIX VENDANT PRODUIT', 0))
                    record["status"] = str(prod_row.get('PRODUCT STATUS/STATUS DU PRODUIT', ''))

            records.append(record)

        logger.info(f"Prepared {len(records)} product records")

        # Upload to Supabase (UPSERT)
        if records:
            try:
                batch_size = 50
                for i in range(0, len(records), batch_size):
                    batch = records[i:i+batch_size]
                    supabase.table('saq_product').upsert(batch).execute()
                    logger.info(f"✓ Uploaded batch {i//batch_size + 1}/{(len(records)-1)//batch_size + 1}")

                logger.info(f"✅ Successfully uploaded {len(records)} products")
            except Exception as e:
                logger.error(f"❌ Failed to upload products: {e}")
                import traceback
                traceback.print_exc()

    def populate_stores(self, store_numbers: set):
        """Populate saq_stores table with unique stores from inventory"""
        logger.info("=" * 80)
        logger.info("POPULATING SAQ STORES TABLE")
        logger.info("=" * 80)

        logger.info(f"Found {len(store_numbers)} unique stores")

        store_records = []

        for store_no in store_numbers:
            # Check if we have mapping info
            store_name = f"SAQ Store {store_no}"
            sales_rep_email = None
            sales_rep_name = None
            city = None
            region = None

            if not self.store_mapping.empty:
                match = self.store_mapping[self.store_mapping['store_no'].astype(str) == store_no]
                if not match.empty:
                    info = match.iloc[0]
                    store_name = str(info.get('store_name', store_name))
                    sales_rep_email = str(info.get('representative_email', ''))
                    sales_rep_name = str(info.get('representative_name', ''))
                    city = str(info.get('store_city', ''))
                    region = str(info.get('store_region', ''))

            record = {
                "store_number": store_no,
                "store_name": store_name,
                "city": city,
                "region": region,
                "sales_rep_name": sales_rep_name,
                "sales_rep_email": sales_rep_email,
                "created_at": datetime.now().isoformat()
            }

            store_records.append(record)

        # Upload stores (UPSERT to avoid duplicates)
        if store_records:
            try:
                batch_size = 50
                for i in range(0, len(store_records), batch_size):
                    batch = store_records[i:i+batch_size]
                    supabase.table('saq_stores').upsert(batch).execute()
                    logger.info(f"✓ Uploaded store batch {i//batch_size + 1}")

                logger.info(f"✅ Successfully uploaded {len(store_records)} stores")
            except Exception as e:
                logger.error(f"❌ Failed to upload stores: {e}")

    def process_weekly_sales(self):
        """Process weekly sales data (Ventes_2025103.csv - NOT Ventes_Sommaires)"""
        logger.info("=" * 80)
        logger.info("PROCESSING WEEKLY SALES")
        logger.info("=" * 80)

        # Find sales file - use Ventes_*.csv but NOT Ventes_Sommaires
        sales_files = [f for f in SAQ_DIR.glob("Ventes_*.csv") if "Sommaires" not in f.name]

        if not sales_files:
            logger.error("❌ No Ventes_*.csv file found")
            return

        sales_file = sorted(sales_files)[-1]
        logger.info(f"Using file: {sales_file.name}")

        df = self.read_saq_csv(sales_file.name)

        if df.empty:
            logger.error("❌ Failed to read sales file")
            return

        logger.info(f"Total sales records: {len(df)}")

        # Column mapping
        saq_col = 'SAQ CODE (IPC)/CODE SAQ (CIP)'
        store_col = 'OUTLET NO/NO SUCCURSALE'
        qty_col = 'QTY OF BOTTLES/QTÉ BOUTEILLE'
        amount_col = 'AMOUNT/MONTANT'
        year_col = 'YEAR/ANNÉE'
        period_col = 'PERIOD/PÉRIODE'
        week_col = 'WEEK/SEMAINE'

        # Filter by Cherry River products
        df[saq_col] = df[saq_col].astype(str)
        df_filtered = df[df[saq_col].isin(self.cherry_river_products)]

        logger.info(f"✓ Filtered to {len(df_filtered)} Cherry River sales records")

        if df_filtered.empty:
            logger.warning("⚠️  No Cherry River sales found")
            return

        # Prepare records
        records = []

        for _, row in df_filtered.iterrows():
            # Calculate week start date (approximate)
            year = int(row[year_col])
            week = int(row[week_col])
            period = int(row[period_col])

            # Rough calculation: period 10, week 3 = early January 2025
            week_start = datetime(year, 1, 1) + timedelta(weeks=week)

            record = {
                "saq_code": str(row[saq_col]),
                "store_number": str(row[store_col]),
                "qty_bottles": int(row[qty_col]) if pd.notna(row[qty_col]) else 0,
                "amount": float(row[amount_col]) if pd.notna(row[amount_col]) else 0.0,
                "year": year,
                "period": period,
                "week": week,
                "week_start_date": week_start.date().isoformat(),
                # is_rupture is auto-generated by database
                "created_at": datetime.now().isoformat()
            }

            records.append(record)

        logger.info(f"Prepared {len(records)} sales records")

        # Check for duplicates in the prepared records
        import hashlib
        seen_keys = set()
        unique_records = []
        duplicates_removed = 0

        for record in records:
            key = f"{record['saq_code']}_{record['store_number']}_{record['year']}_{record['period']}_{record['week']}"
            if key not in seen_keys:
                seen_keys.add(key)
                unique_records.append(record)
            else:
                duplicates_removed += 1

        if duplicates_removed > 0:
            logger.warning(f"⚠️  Removed {duplicates_removed} duplicate records from CSV")

        logger.info(f"Final unique records to upload: {len(unique_records)}")

        # Upload to Supabase
        if unique_records:
            try:
                # FIRST: Populate stores from sales data (some stores in sales might not be in inventory)
                unique_stores_in_sales = set(record['store_number'] for record in unique_records)
                logger.info(f"Found {len(unique_stores_in_sales)} unique stores in sales data")
                self.populate_stores(unique_stores_in_sales)

                # SECOND: Clear ONLY this specific week's data (to allow re-running for same week)
                # This way we accumulate historical data but can safely re-process the same week
                logger.info(f"Clearing existing data for week {week}, period {period}, year {year}...")
                delete_result = supabase.table('saq_ventes')\
                    .delete()\
                    .eq('annee', year)\
                    .eq('periode', period)\
                    .eq('semaine', week)\
                    .execute()
                logger.info(f"✓ Cleared existing data for this week only")

                # THEN: Insert fresh data for this week
                batch_size = 100
                for i in range(0, len(unique_records), batch_size):
                    batch = unique_records[i:i+batch_size]
                    # Use insert since we just cleared this week's data
                    supabase.table('saq_ventes').insert(batch).execute()
                    logger.info(f"✓ Uploaded batch {i//batch_size + 1}/{(len(unique_records)-1)//batch_size + 1}")

                logger.info(f"✅ Successfully uploaded {len(unique_records)} sales records for week {week}")
            except Exception as e:
                logger.error(f"❌ Failed to upload sales: {e}")
                import traceback
                traceback.print_exc()

    def process_store_inventory(self):
        """Process store inventory and detect ruptures"""
        logger.info("=" * 80)
        logger.info("PROCESSING STORE INVENTORY & DETECTING RUPTURES")
        logger.info("=" * 80)

        df = self.read_saq_csv("Inventaires succursales.csv")

        if df.empty:
            logger.error("❌ Failed to read inventory file")
            return

        logger.info(f"Total inventory records: {len(df)}")

        # Clean up SAQ codes (remove quotes)
        df['CODE SAQ (CIP)'] = df['CODE SAQ (CIP)'].astype(str).str.replace("'", "")
        df['NO SUCCURSALE'] = df['NO SUCCURSALE'].astype(str).str.replace("'", "")

        # Filter by Cherry River products
        df_filtered = df[df['CODE SAQ (CIP)'].isin(self.cherry_river_products)]

        logger.info(f"✓ Filtered to {len(df_filtered)} Cherry River inventory records")

        if df_filtered.empty:
            logger.warning("⚠️  No Cherry River inventory found")
            return

        # FIRST: Populate saq_stores table with unique stores
        unique_stores = set(df_filtered['NO SUCCURSALE'].unique())
        self.populate_stores(unique_stores)

        # Prepare inventory records
        inventory_records = []
        rupture_alerts = []

        for _, row in df_filtered.iterrows():
            saq_code = str(row['CODE SAQ (CIP)'])
            store_no = str(row['NO SUCCURSALE'])
            qty = int(row['QTÉ INVENTAIRE(unités)']) if pd.notna(row['QTÉ INVENTAIRE(unités)']) else 0

            # Get snapshot date from file
            snapshot_date = str(row['DATE DU JOUR']).replace("'", "")

            # Inventory record
            inv_record = {
                "saq_code": saq_code,
                "store_number": store_no,
                "qty_inventory": qty,
                "snapshot_date": snapshot_date,
                "avg_weekly_sales": None,  # Calculate later
                "days_of_inventory": None,  # Calculate later
                "is_warning": qty < 10 and qty > 0,
                "is_critical": qty == 0,
                "created_at": datetime.now().isoformat()
            }

            inventory_records.append(inv_record)

            # Detect rupture (0 inventory)
            if qty == 0:
                # Get sales rep info
                sales_rep_email = None

                if not self.store_mapping.empty:
                    store_match = self.store_mapping[
                        self.store_mapping['store_no'].astype(str) == store_no
                    ]
                    if not store_match.empty:
                        sales_rep_email = str(store_match.iloc[0].get('representative_email', ''))

                alert = {
                    "saq_code": saq_code,
                    "store_number": store_no,
                    "alert_type": "rupture",
                    "status": "active",
                    "alert_date": datetime.now().date().isoformat(),
                    "days_in_rupture": 0,
                    "sales_rep_email": sales_rep_email,
                    "created_at": datetime.now().isoformat()
                }

                rupture_alerts.append(alert)

        logger.info(f"Prepared {len(inventory_records)} inventory records")
        logger.info(f"🚨 Detected {len(rupture_alerts)} RUPTURES")

        # Upload inventory (UPSERT to handle duplicates)
        if inventory_records:
            try:
                batch_size = 100
                for i in range(0, len(inventory_records), batch_size):
                    batch = inventory_records[i:i+batch_size]
                    # Use upsert with ignoreDuplicates=False to update existing snapshots
                    # The unique constraint uq_inventory_snapshot handles conflicts
                    supabase.table('saq_store_inventory').upsert(
                        batch,
                        ignore_duplicates=False
                    ).execute()
                    logger.info(f"✓ Uploaded inventory batch {i//batch_size + 1}/{(len(inventory_records)-1)//batch_size + 1}")

                logger.info(f"✅ Successfully uploaded {len(inventory_records)} inventory records")
            except Exception as e:
                logger.error(f"❌ Failed to upload inventory: {e}")
                import traceback
                traceback.print_exc()

        # Upload rupture alerts
        if rupture_alerts:
            try:
                supabase.table('rupture_alerts').insert(rupture_alerts).execute()
                logger.info(f"✅ Created {len(rupture_alerts)} rupture alerts")
            except Exception as e:
                logger.error(f"❌ Failed to create alerts: {e}")
                import traceback
                traceback.print_exc()

        return rupture_alerts

    def calculate_sales_velocity(self):
        """Calculate avg_weekly_sales and days_of_inventory for all inventory records"""
        logger.info("=" * 80)
        logger.info("CALCULATING SALES VELOCITY & DAYS OF INVENTORY")
        logger.info("=" * 80)

        try:
            # Fetch all sales data from Supabase
            sales_response = supabase.table('saq_ventes')\
                .select('code_saq, no_succursale, bouteille')\
                .execute()

            if not sales_response.data:
                logger.warning("⚠️  No sales data available to calculate velocity")
                return

            # Calculate average weekly sales per product per store
            sales_df = pd.DataFrame(sales_response.data)
            avg_sales = sales_df.groupby(['saq_code', 'store_number'])['qty_bottles'].mean().reset_index()
            avg_sales.columns = ['saq_code', 'store_number', 'avg_weekly_sales']

            logger.info(f"✓ Calculated average sales for {len(avg_sales)} product-store combinations")

            # Fetch all inventory records
            inventory_response = supabase.table('saq_store_inventory')\
                .select('id, saq_code, store_number, qty_inventory, snapshot_date')\
                .execute()

            if not inventory_response.data:
                logger.warning("⚠️  No inventory data to update")
                return

            inventory_df = pd.DataFrame(inventory_response.data)

            # Merge sales velocity with inventory
            merged = inventory_df.merge(
                avg_sales,
                on=['saq_code', 'store_number'],
                how='left'
            )

            # Calculate days of inventory
            updates = []
            warning_count = 0
            critical_count = 0

            for _, row in merged.iterrows():
                avg_weekly_sales = row.get('avg_weekly_sales', 0)
                qty_inventory = row.get('qty_inventory', 0)

                if pd.isna(avg_weekly_sales) or avg_weekly_sales == 0:
                    days_of_inventory = None
                    is_warning = False
                    is_critical = qty_inventory == 0
                else:
                    # Calculate days: qty / (avg_weekly_sales / 7)
                    days_of_inventory = round((qty_inventory / (avg_weekly_sales / 7)), 2)
                    is_warning = days_of_inventory < 14 and days_of_inventory > 0
                    is_critical = days_of_inventory < 7

                if is_warning:
                    warning_count += 1
                if is_critical:
                    critical_count += 1

                update = {
                    "id": row['id'],
                    "saq_code": row['saq_code'],
                    "store_number": row['store_number'],
                    "qty_inventory": int(qty_inventory),
                    "snapshot_date": row['snapshot_date'],
                    "avg_weekly_sales": float(avg_weekly_sales) if not pd.isna(avg_weekly_sales) else None,
                    "days_of_inventory": float(days_of_inventory) if days_of_inventory is not None else None,
                    "is_warning": is_warning,
                    "is_critical": is_critical
                }
                updates.append(update)

            # Update inventory records using UPSERT (much faster than individual updates)
            batch_size = 100
            for i in range(0, len(updates), batch_size):
                batch = updates[i:i+batch_size]
                # Use upsert to update multiple records at once
                supabase.table('saq_store_inventory').upsert(batch, ignore_duplicates=False).execute()
                logger.info(f"✓ Updated batch {i//batch_size + 1}/{(len(updates)-1)//batch_size + 1}")

            logger.info(f"✅ Successfully calculated and updated {len(updates)} inventory records")
            logger.info(f"   - {critical_count} critical alerts (< 7 days)")
            logger.info(f"   - {warning_count} warning alerts (< 14 days)")

            # Create alerts for low stock items
            self.create_low_stock_alerts(critical_count, warning_count)

        except Exception as e:
            logger.error(f"❌ Failed to calculate sales velocity: {e}")
            import traceback
            traceback.print_exc()

    def create_low_stock_alerts(self, critical_count, warning_count):
        """Create alerts for low stock items based on days_of_inventory"""
        if critical_count == 0 and warning_count == 0:
            logger.info("✓ No low stock alerts to create")
            return

        try:
            # Fetch inventory records that need alerts
            inventory_response = supabase.table('saq_store_inventory')\
                .select('saq_code, store_number, days_of_inventory, is_warning, is_critical')\
                .or_('is_warning.eq.true,is_critical.eq.true')\
                .execute()

            if not inventory_response.data:
                return

            # Fetch store mapping for sales rep emails
            low_stock_alerts = []

            for inv in inventory_response.data:
                saq_code = inv['saq_code']
                store_no = inv['store_number']
                days_remaining = inv['days_of_inventory']

                # Determine alert type
                if inv['is_critical']:
                    alert_type = 'critical'
                elif inv['is_warning']:
                    alert_type = 'warning'
                else:
                    continue

                # Get sales rep
                sales_rep_email = None
                if not self.store_mapping.empty:
                    store_match = self.store_mapping[
                        self.store_mapping['store_no'].astype(str) == store_no
                    ]
                    if not store_match.empty:
                        sales_rep_email = str(store_match.iloc[0].get('representative_email', ''))

                alert = {
                    "saq_code": saq_code,
                    "store_number": store_no,
                    "alert_type": alert_type,
                    "status": "active",
                    "alert_date": datetime.now().date().isoformat(),
                    "days_in_rupture": 0,
                    "sales_rep_email": sales_rep_email,
                    "created_at": datetime.now().isoformat()
                }

                low_stock_alerts.append(alert)

            # Insert alerts
            if low_stock_alerts:
                supabase.table('rupture_alerts').insert(low_stock_alerts).execute()
                logger.info(f"✅ Created {len(low_stock_alerts)} low stock alerts")

        except Exception as e:
            logger.error(f"❌ Failed to create low stock alerts: {e}")

    def log_rupture_summary(self, rupture_alerts):
        """Log summary of ruptures grouped by sales rep"""
        if not rupture_alerts:
            logger.info("✓ No ruptures detected")
            return

        logger.info("=" * 80)
        logger.info("RUPTURE ALERT SUMMARY")
        logger.info("=" * 80)

        # Group by sales rep
        alerts_by_rep = {}
        for alert in rupture_alerts:
            rep = alert.get('sales_rep_email', 'Unassigned')
            if rep not in alerts_by_rep:
                alerts_by_rep[rep] = []
            alerts_by_rep[rep].append(alert)

        for rep, alerts in alerts_by_rep.items():
            logger.info(f"\n📧 {rep}: {len(alerts)} ruptures")
            for alert in alerts[:5]:  # Show first 5
                logger.info(f"   - SAQ {alert['saq_code']} at Store {alert['store_number']}")
            if len(alerts) > 5:
                logger.info(f"   ... and {len(alerts) - 5} more")

    def run_full_process(self):
        """Run complete pipeline"""
        logger.info("\n" + "🚀" * 40)
        logger.info("SAQ DATA PROCESSING PIPELINE V2")
        logger.info("🚀" * 40 + "\n")

        start_time = datetime.now()

        try:
            if not self.cherry_river_products:
                logger.error("❌ No Cherry River products loaded. Cannot proceed.")
                return False

            # Step 1: Process products
            self.process_products()

            # Step 2: Process weekly sales
            self.process_weekly_sales()

            # Step 3: Process inventory and detect ruptures
            rupture_alerts = self.process_store_inventory()

            # Step 4: Calculate sales velocity and days of inventory
            self.calculate_sales_velocity()

            # Step 5: Log rupture summary
            if rupture_alerts:
                self.log_rupture_summary(rupture_alerts)

            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()

            logger.info("\n" + "✅" * 40)
            logger.info("PIPELINE COMPLETED SUCCESSFULLY")
            logger.info(f"Total time: {duration:.2f} seconds")
            logger.info("✅" * 40 + "\n")

            return True

        except Exception as e:
            logger.error(f"\n❌ Pipeline failed: {e}")
            import traceback
            traceback.print_exc()
            return False

def main():
    """Main entry point"""
    processor = SAQProcessorV2()
    success = processor.run_full_process()

    if not success:
        exit(1)

if __name__ == "__main__":
    main()
