"""
SAQ to Supabase Data Processor
Processes SAQ CSV files and uploads to Supabase tables
Calculates rupture alerts and sales metrics
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

class SAQProcessor:
    """Main processor for SAQ data"""

    def __init__(self):
        """Initialize processor and load mapping files"""
        logger.info("Initializing SAQ Processor...")

        # Load product mapping
        product_map_path = MAPPINGS_DIR / "saq_odoo_product_mapping.csv"
        if product_map_path.exists():
            self.product_mapping = pd.read_csv(product_map_path)
            logger.info(f"Loaded {len(self.product_mapping)} product mappings")
        else:
            logger.warning(f"Product mapping file not found: {product_map_path}")
            self.product_mapping = pd.DataFrame()

        # Load store territory mapping
        store_map_path = MAPPINGS_DIR / "saq_store_territory_mapping.csv"
        if store_map_path.exists():
            self.store_mapping = pd.read_csv(store_map_path)
            logger.info(f"Loaded {len(self.store_mapping)} store mappings")
        else:
            logger.warning(f"Store mapping file not found: {store_map_path}")
            self.store_mapping = pd.DataFrame()

    def read_saq_csv(self, filename: str) -> pd.DataFrame:
        """Read SAQ CSV with proper encoding and delimiter"""
        csv_path = SAQ_DIR / filename

        if not csv_path.exists():
            logger.error(f"File not found: {csv_path}")
            return pd.DataFrame()

        logger.info(f"Reading {filename}...")

        encodings = ['latin-1', 'utf-8', 'iso-8859-1', 'cp1252']

        for encoding in encodings:
            try:
                # SAQ uses semicolon delimiter
                df = pd.read_csv(csv_path, delimiter=';', encoding=encoding)
                logger.info(f"✓ Read {len(df)} rows with encoding: {encoding}")
                return df
            except Exception as e:
                continue

        logger.error(f"Failed to read {filename} with any encoding")
        return pd.DataFrame()

    def process_products(self):
        """Process SAQ products and upload to Supabase"""
        logger.info("=" * 80)
        logger.info("PROCESSING SAQ PRODUCTS")
        logger.info("=" * 80)

        # Read products CSV
        df = self.read_saq_csv("Produits.csv")

        if df.empty:
            logger.error("Failed to read products file")
            return

        logger.info(f"Total products in file: {len(df)}")

        # Filter Cherry River products (supplier code 17972428)
        supplier_col = None
        for col in df.columns:
            if 'FOURN' in col.upper():
                supplier_col = col
                break

        if supplier_col:
            df = df[df[supplier_col] == '17972428']
            logger.info(f"Filtered to {len(df)} Cherry River products")

        # Merge with Odoo mapping if available
        if not self.product_mapping.empty:
            saq_code_col = None
            for col in df.columns:
                if 'CODE SAQ' in col.upper() or 'SAQ CODE' in col.upper():
                    saq_code_col = col
                    break

            if saq_code_col:
                df = df.merge(
                    self.product_mapping,
                    left_on=saq_code_col,
                    right_on='saq_code',
                    how='left'
                )
                logger.info(f"Merged with Odoo mapping")

        # Prepare records for Supabase
        records = []

        for _, row in df.iterrows():
            # Find column names dynamically
            saq_code = None
            product_name = None
            format_val = None
            volume = None

            for col in df.columns:
                col_upper = col.upper()
                if 'CODE SAQ' in col_upper or 'SAQ CODE' in col_upper:
                    saq_code = str(row[col])
                elif 'DESCRIPTION' in col_upper or 'PRODUIT' in col_upper:
                    product_name = str(row[col])
                elif 'FORMAT' in col_upper:
                    format_val = str(row[col])
                elif 'VOLUME' in col_upper or 'CONTENANT' in col_upper:
                    volume = str(row[col])

            if not saq_code:
                continue

            record = {
                "saq_code": saq_code,
                "product_name": product_name or "Unknown",
                "format": format_val,
                "volume_ml": volume,
                "odoo_product_id": int(row.get('odoo_product_id')) if pd.notna(row.get('odoo_product_id')) else None,
                "odoo_product_name": str(row.get('odoo_product_name')) if pd.notna(row.get('odoo_product_name')) else None,
                "is_active": True,
                "last_updated": datetime.now().isoformat()
            }

            records.append(record)

        logger.info(f"Prepared {len(records)} product records")

        # Upload to Supabase (upsert)
        if records:
            try:
                # Batch insert (Supabase handles upsert with on_conflict)
                batch_size = 100
                for i in range(0, len(records), batch_size):
                    batch = records[i:i+batch_size]
                    supabase.table('saq_products').upsert(batch).execute()
                    logger.info(f"Uploaded batch {i//batch_size + 1}/{(len(records)-1)//batch_size + 1}")

                logger.info(f"✓ Successfully uploaded {len(records)} products to Supabase")
            except Exception as e:
                logger.error(f"Failed to upload products: {e}")

    def process_weekly_sales(self):
        """Process SAQ weekly sales data"""
        logger.info("=" * 80)
        logger.info("PROCESSING WEEKLY SALES")
        logger.info("=" * 80)

        # Read sales CSV (filename varies by date)
        sales_files = list(SAQ_DIR.glob("Ventes_*.csv"))

        if not sales_files:
            logger.error("No sales file found matching pattern 'Ventes_*.csv'")
            return

        # Use most recent file
        sales_file = sorted(sales_files)[-1]
        logger.info(f"Using file: {sales_file.name}")

        df = self.read_saq_csv(sales_file.name)

        if df.empty:
            logger.error("Failed to read sales file")
            return

        logger.info(f"Total sales records: {len(df)}")

        # Filter Cherry River products if supplier column exists
        supplier_col = None
        for col in df.columns:
            if 'FOURN' in col.upper():
                supplier_col = col
                break

        if supplier_col:
            df = df[df[supplier_col] == '17972428']
            logger.info(f"Filtered to {len(df)} Cherry River sales records")

        # Prepare records
        records = []

        for _, row in df.iterrows():
            # Find columns dynamically
            saq_code = None
            store_no = None
            qty_sold = None
            sale_date = None

            for col in df.columns:
                col_upper = col.upper()
                if 'CODE SAQ' in col_upper or 'SAQ CODE' in col_upper:
                    saq_code = str(row[col])
                elif 'SUCC' in col_upper or 'STORE' in col_upper:
                    store_no = str(row[col])
                elif 'QTE' in col_upper or 'QTY' in col_upper or 'QUANTITE' in col_upper:
                    qty_sold = row[col]
                elif 'DATE' in col_upper:
                    sale_date = row[col]

            if not saq_code or not store_no:
                continue

            record = {
                "saq_code": saq_code,
                "store_no": store_no,
                "qty_bottles_sold": int(qty_sold) if pd.notna(qty_sold) else 0,
                "week_ending_date": str(sale_date) if pd.notna(sale_date) else None,
                "created_at": datetime.now().isoformat()
            }

            records.append(record)

        logger.info(f"Prepared {len(records)} sales records")

        # Upload to Supabase
        if records:
            try:
                batch_size = 100
                for i in range(0, len(records), batch_size):
                    batch = records[i:i+batch_size]
                    supabase.table('saq_weekly_sales').insert(batch).execute()
                    logger.info(f"Uploaded batch {i//batch_size + 1}/{(len(records)-1)//batch_size + 1}")

                logger.info(f"✓ Successfully uploaded {len(records)} sales records")
            except Exception as e:
                logger.error(f"Failed to upload sales: {e}")

    def process_store_inventory(self):
        """Process SAQ store inventory and detect ruptures"""
        logger.info("=" * 80)
        logger.info("PROCESSING STORE INVENTORY")
        logger.info("=" * 80)

        df = self.read_saq_csv("Inventaires succursales.csv")

        if df.empty:
            logger.error("Failed to read inventory file")
            return

        logger.info(f"Total inventory records: {len(df)}")

        # Filter Cherry River products
        supplier_col = None
        for col in df.columns:
            if 'FOURN' in col.upper():
                supplier_col = col
                break

        if supplier_col:
            df = df[df[supplier_col] == '17972428']
            logger.info(f"Filtered to {len(df)} Cherry River inventory records")

        # Prepare records
        records = []
        rupture_alerts = []

        for _, row in df.iterrows():
            # Find columns
            saq_code = None
            store_no = None
            qty_inventory = None

            for col in df.columns:
                col_upper = col.upper()
                if 'CODE SAQ' in col_upper or 'SAQ CODE' in col_upper:
                    saq_code = str(row[col])
                elif 'SUCC' in col_upper or 'STORE' in col_upper:
                    store_no = str(row[col])
                elif 'QTE' in col_upper or 'QTY' in col_upper or 'INVENTAIRE' in col_upper:
                    qty_inventory = row[col]

            if not saq_code or not store_no:
                continue

            qty = int(qty_inventory) if pd.notna(qty_inventory) else 0

            record = {
                "saq_code": saq_code,
                "store_no": store_no,
                "qty_bottles": qty,
                "snapshot_date": datetime.now().date().isoformat(),
                "created_at": datetime.now().isoformat()
            }

            records.append(record)

            # Detect rupture (0 inventory)
            if qty == 0:
                # Get store info from mapping
                store_info = None
                if not self.store_mapping.empty:
                    store_match = self.store_mapping[self.store_mapping['store_no'] == store_no]
                    if not store_match.empty:
                        store_info = store_match.iloc[0]

                alert = {
                    "saq_code": saq_code,
                    "store_no": store_no,
                    "alert_type": "rupture",
                    "severity": "critical",
                    "detected_date": datetime.now().date().isoformat(),
                    "status": "active",
                    "assigned_rep": store_info.get('representative_email') if store_info is not None else None,
                    "created_at": datetime.now().isoformat()
                }

                rupture_alerts.append(alert)

        logger.info(f"Prepared {len(records)} inventory records")
        logger.info(f"Detected {len(rupture_alerts)} ruptures")

        # Upload inventory
        if records:
            try:
                batch_size = 100
                for i in range(0, len(records), batch_size):
                    batch = records[i:i+batch_size]
                    supabase.table('saq_store_inventory').insert(batch).execute()
                    logger.info(f"Uploaded inventory batch {i//batch_size + 1}")

                logger.info(f"✓ Successfully uploaded {len(records)} inventory records")
            except Exception as e:
                logger.error(f"Failed to upload inventory: {e}")

        # Upload rupture alerts
        if rupture_alerts:
            try:
                supabase.table('rupture_alerts').insert(rupture_alerts).execute()
                logger.info(f"✓ Created {len(rupture_alerts)} rupture alerts")
            except Exception as e:
                logger.error(f"Failed to create alerts: {e}")

    def run_full_process(self):
        """Run complete SAQ data processing pipeline"""
        logger.info("\n" + "🚀" * 40)
        logger.info("STARTING SAQ DATA PROCESSING PIPELINE")
        logger.info("🚀" * 40 + "\n")

        start_time = datetime.now()

        try:
            # Step 1: Process products
            self.process_products()

            # Step 2: Process weekly sales
            self.process_weekly_sales()

            # Step 3: Process store inventory and detect ruptures
            self.process_store_inventory()

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
    processor = SAQProcessor()
    success = processor.run_full_process()

    if not success:
        exit(1)

if __name__ == "__main__":
    main()
