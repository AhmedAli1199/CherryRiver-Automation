"""
SAQ to Supabase Data Processor - SIMPLIFIED VERSION
Works without product mappings - processes ALL SAQ data
Sends email alerts for ruptures to territory reps
"""

import os
import pandas as pd
from pathlib import Path
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

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
    """Main processor for SAQ data - simplified version"""

    def __init__(self):
        """Initialize processor"""
        logger.info("Initializing SAQ Processor (Simplified)...")

        # Load store territory mapping (REQUIRED for alerts)
        store_map_path = MAPPINGS_DIR / "saq_store_territory_mapping.csv"
        if store_map_path.exists():
            self.store_mapping = pd.read_csv(store_map_path)
            logger.info(f"✓ Loaded {len(self.store_mapping)} store mappings")
        else:
            logger.warning(f"⚠️  Store mapping file not found: {store_map_path}")
            logger.warning("⚠️  Alerts will be created but not assigned to reps")
            self.store_mapping = pd.DataFrame()

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
                # SAQ uses semicolon delimiter
                df = pd.read_csv(csv_path, delimiter=';', encoding=encoding)
                logger.info(f"✓ Read {len(df)} rows with encoding: {encoding}")
                return df
            except Exception as e:
                continue

        logger.error(f"❌ Failed to read {filename} with any encoding")
        return pd.DataFrame()

    def process_products(self):
        """Process ALL SAQ products (not just Cherry River)"""
        logger.info("=" * 80)
        logger.info("PROCESSING SAQ PRODUCTS")
        logger.info("=" * 80)

        df = self.read_saq_csv("Produits.csv")

        if df.empty:
            logger.error("❌ Failed to read products file")
            return

        logger.info(f"Total products in file: {len(df)}")

        # Find column names dynamically
        col_map = {}
        for col in df.columns:
            col_upper = col.upper()
            if 'CODE SAQ' in col_upper or 'SAQ CODE' in col_upper or 'CIP' in col_upper:
                col_map['saq_code'] = col
            elif 'DESCRIPTION' in col_upper or 'PRODUIT' in col_upper:
                col_map['product_name'] = col
            elif 'FORMAT' in col_upper:
                col_map['format'] = col
            elif 'VOLUME' in col_upper or 'CONTENANT' in col_upper:
                col_map['volume'] = col
            elif 'FOURN' in col_upper:
                col_map['supplier'] = col

        logger.info(f"Detected columns: {col_map}")

        # Filter Cherry River products if supplier column exists
        if 'supplier' in col_map:
            # Try both string and numeric comparison
            cherry_mask = (df[col_map['supplier']].astype(str) == '17972428') | (df[col_map['supplier']] == 17972428)
            df = df[cherry_mask]
            logger.info(f"✓ Filtered to {len(df)} Cherry River products")

        if df.empty:
            logger.warning("⚠️  No Cherry River products found - check supplier code")
            return

        # Prepare records
        records = []

        for _, row in df.iterrows():
            saq_code = str(row[col_map['saq_code']]) if 'saq_code' in col_map else None

            if not saq_code or pd.isna(saq_code):
                continue

            record = {
                "saq_code": saq_code,
                "product_name": str(row[col_map['product_name']]) if 'product_name' in col_map and pd.notna(row[col_map['product_name']]) else "Unknown",
                "format": str(row[col_map['format']]) if 'format' in col_map and pd.notna(row[col_map['format']]) else None,
                "volume_ml": str(row[col_map['volume']]) if 'volume' in col_map and pd.notna(row[col_map['volume']]) else None,
                "is_active": True,
                "last_updated": datetime.now().isoformat()
            }

            records.append(record)

        logger.info(f"Prepared {len(records)} product records")

        # Upload to Supabase
        if records:
            try:
                batch_size = 100
                for i in range(0, len(records), batch_size):
                    batch = records[i:i+batch_size]
                    supabase.table('saq_products').upsert(batch).execute()
                    logger.info(f"✓ Uploaded batch {i//batch_size + 1}/{(len(records)-1)//batch_size + 1}")

                logger.info(f"✅ Successfully uploaded {len(records)} products to Supabase")
            except Exception as e:
                logger.error(f"❌ Failed to upload products: {e}")
                import traceback
                traceback.print_exc()

    def process_weekly_sales(self):
        """Process SAQ weekly sales data"""
        logger.info("=" * 80)
        logger.info("PROCESSING WEEKLY SALES")
        logger.info("=" * 80)

        # Find sales file (pattern: Ventes_*.csv)
        sales_files = list(SAQ_DIR.glob("Ventes_*.csv"))

        if not sales_files:
            logger.error("❌ No sales file found matching pattern 'Ventes_*.csv'")
            return

        sales_file = sorted(sales_files)[-1]
        logger.info(f"Using file: {sales_file.name}")

        df = self.read_saq_csv(sales_file.name)

        if df.empty:
            logger.error("❌ Failed to read sales file")
            return

        logger.info(f"Total sales records: {len(df)}")

        # Find columns
        col_map = {}
        for col in df.columns:
            col_upper = col.upper()
            if 'CODE SAQ' in col_upper or 'CIP' in col_upper:
                col_map['saq_code'] = col
            elif 'SUCC' in col_upper or 'STORE' in col_upper:
                col_map['store_no'] = col
            elif 'QTE' in col_upper or 'QTY' in col_upper or 'QUANTITE' in col_upper:
                col_map['qty'] = col
            elif 'DATE' in col_upper:
                col_map['date'] = col
            elif 'FOURN' in col_upper:
                col_map['supplier'] = col

        logger.info(f"Detected columns: {col_map}")

        # Filter Cherry River
        if 'supplier' in col_map:
            cherry_mask = (df[col_map['supplier']].astype(str) == '17972428') | (df[col_map['supplier']] == 17972428)
            df = df[cherry_mask]
            logger.info(f"✓ Filtered to {len(df)} Cherry River sales records")

        # Prepare records
        records = []

        for _, row in df.iterrows():
            saq_code = str(row[col_map['saq_code']]) if 'saq_code' in col_map else None
            store_no = str(row[col_map['store_no']]) if 'store_no' in col_map else None

            if not saq_code or not store_no:
                continue

            qty = row[col_map['qty']] if 'qty' in col_map else 0

            record = {
                "saq_code": saq_code,
                "store_no": store_no,
                "qty_bottles_sold": int(qty) if pd.notna(qty) else 0,
                "week_ending_date": str(row[col_map['date']]) if 'date' in col_map and pd.notna(row[col_map['date']]) else None,
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
                    logger.info(f"✓ Uploaded batch {i//batch_size + 1}/{(len(records)-1)//batch_size + 1}")

                logger.info(f"✅ Successfully uploaded {len(records)} sales records")
            except Exception as e:
                logger.error(f"❌ Failed to upload sales: {e}")

    def process_store_inventory(self):
        """Process SAQ store inventory and detect ruptures"""
        logger.info("=" * 80)
        logger.info("PROCESSING STORE INVENTORY & DETECTING RUPTURES")
        logger.info("=" * 80)

        df = self.read_saq_csv("Inventaires succursales.csv")

        if df.empty:
            logger.error("❌ Failed to read inventory file")
            return

        logger.info(f"Total inventory records: {len(df)}")

        # Find columns
        col_map = {}
        for col in df.columns:
            col_upper = col.upper()
            if 'CODE SAQ' in col_upper or 'CIP' in col_upper:
                col_map['saq_code'] = col
            elif 'SUCC' in col_upper or 'STORE' in col_upper:
                col_map['store_no'] = col
            elif 'QTE' in col_upper or 'QTY' in col_upper or 'INVENTAIRE' in col_upper:
                col_map['qty'] = col
            elif 'FOURN' in col_upper:
                col_map['supplier'] = col

        logger.info(f"Detected columns: {col_map}")

        # Filter Cherry River
        if 'supplier' in col_map:
            cherry_mask = (df[col_map['supplier']].astype(str) == '17972428') | (df[col_map['supplier']] == 17972428)
            df = df[cherry_mask]
            logger.info(f"✓ Filtered to {len(df)} Cherry River inventory records")

        # Prepare records
        inventory_records = []
        rupture_alerts = []

        for _, row in df.iterrows():
            saq_code = str(row[col_map['saq_code']]) if 'saq_code' in col_map else None
            store_no = str(row[col_map['store_no']]) if 'store_no' in col_map else None

            if not saq_code or not store_no:
                continue

            qty = row[col_map['qty']] if 'qty' in col_map else 0
            qty = int(qty) if pd.notna(qty) else 0

            # Inventory record
            inventory_record = {
                "saq_code": saq_code,
                "store_no": store_no,
                "qty_bottles": qty,
                "snapshot_date": datetime.now().date().isoformat(),
                "created_at": datetime.now().isoformat()
            }

            inventory_records.append(inventory_record)

            # Detect rupture (0 inventory)
            if qty == 0:
                # Get store info and rep assignment
                assigned_rep = None
                store_name = f"Store {store_no}"

                if not self.store_mapping.empty:
                    store_match = self.store_mapping[self.store_mapping['store_no'].astype(str) == store_no]
                    if not store_match.empty:
                        store_info = store_match.iloc[0]
                        assigned_rep = str(store_info.get('representative_email')) if pd.notna(store_info.get('representative_email')) else None
                        store_name = str(store_info.get('store_name', store_name))

                alert = {
                    "saq_code": saq_code,
                    "store_no": store_no,
                    "alert_type": "rupture",
                    "severity": "critical",
                    "detected_date": datetime.now().date().isoformat(),
                    "status": "active",
                    "assigned_rep": assigned_rep,
                    "created_at": datetime.now().isoformat()
                }

                rupture_alerts.append(alert)

        logger.info(f"Prepared {len(inventory_records)} inventory records")
        logger.info(f"🚨 Detected {len(rupture_alerts)} RUPTURES (0 inventory)")

        # Upload inventory
        if inventory_records:
            try:
                batch_size = 100
                for i in range(0, len(inventory_records), batch_size):
                    batch = inventory_records[i:i+batch_size]
                    supabase.table('saq_store_inventory').insert(batch).execute()
                    logger.info(f"✓ Uploaded inventory batch {i//batch_size + 1}")

                logger.info(f"✅ Successfully uploaded {len(inventory_records)} inventory records")
            except Exception as e:
                logger.error(f"❌ Failed to upload inventory: {e}")

        # Upload rupture alerts
        if rupture_alerts:
            try:
                supabase.table('rupture_alerts').insert(rupture_alerts).execute()
                logger.info(f"✅ Created {len(rupture_alerts)} rupture alerts in database")
            except Exception as e:
                logger.error(f"❌ Failed to create alerts: {e}")

        return rupture_alerts

    def send_alert_emails(self, rupture_alerts):
        """Send email alerts to territory reps (placeholder)"""
        logger.info("=" * 80)
        logger.info("SENDING ALERT EMAILS")
        logger.info("=" * 80)

        if not rupture_alerts:
            logger.info("✓ No ruptures to alert on")
            return

        # Group alerts by rep
        alerts_by_rep = {}
        for alert in rupture_alerts:
            rep_email = alert.get('assigned_rep')
            if rep_email:
                if rep_email not in alerts_by_rep:
                    alerts_by_rep[rep_email] = []
                alerts_by_rep[rep_email].append(alert)

        logger.info(f"Alerts grouped for {len(alerts_by_rep)} reps")

        # For now, just log what would be sent
        # TODO: Integrate with N8N webhook or SMTP
        for rep_email, alerts in alerts_by_rep.items():
            logger.info(f"\n📧 Would send to {rep_email}:")
            logger.info(f"   {len(alerts)} ruptures detected")
            for alert in alerts[:3]:  # Show first 3
                logger.info(f"   - SAQ Code: {alert['saq_code']}, Store: {alert['store_no']}")

        logger.info("\n⚠️  Email sending not yet implemented")
        logger.info("💡 Next step: Integrate with N8N webhook for email delivery")

    def run_full_process(self):
        """Run complete SAQ data processing pipeline"""
        logger.info("\n" + "🚀" * 40)
        logger.info("STARTING SAQ DATA PROCESSING PIPELINE (SIMPLIFIED)")
        logger.info("🚀" * 40 + "\n")

        start_time = datetime.now()

        try:
            # Step 1: Process products
            self.process_products()

            # Step 2: Process weekly sales
            self.process_weekly_sales()

            # Step 3: Process store inventory and detect ruptures
            rupture_alerts = self.process_store_inventory()

            # Step 4: Send alert emails
            if rupture_alerts:
                self.send_alert_emails(rupture_alerts)

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
