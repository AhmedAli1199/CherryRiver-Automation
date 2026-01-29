"""
SAQ Weekly Data Update Script
=============================
This script processes downloaded SAQ CSV files and updates Supabase.

Run after the scraper downloads new weekly CSVs.

Usage:
    python saq_weekly_update.py --folder "path/to/SAQ Documents 2"
"""

import os
import csv
import re
from datetime import datetime
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

# Supabase connection
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")  # Can use anon key if RLS allows, or service key
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Cherry River SAQ codes (from Mes produits.csv)
CHERRY_RIVER_CODES = {
    '14001338','14064873','14250123','14545132','14558831','14561781','14682882',
    '14682891','14758699','14954868','14954876','14954892','14960213','14964880',
    '14964978','14989770','14989788','14989796','14989809','14989825','14989833',
    '15026641','15026836','15026861','15026967','15047160','15047178','15056779',
    '15066248','15079760','15095284','15096092','15096105','15096113','15096121',
    '15168156','15182960','15183559','15183735','15231215','15255701','15256551',
    '15298014','15303872','15303910','15311581','15359323','15384553','15401202',
    '15419357','15449046','15449071','15449206','15449214','15449249','15450979',
    '15469258','15471243','15474217','15489099','15493792','15493821','15494154',
    '15499596','15499625','15513802','15521562','15525563','15546348','15546356',
    '15546364','15546372','15546381','15546399','15546401','15546410','15546428',
    '15546436','15559691'
}


def clean_value(val):
    """Remove quotes and whitespace from values"""
    if val is None:
        return None
    return str(val).strip().strip('"').strip("'")


def reset_sequence(table_name, id_column):
    """Reset auto-increment sequence to prevent duplicate key errors"""
    try:
        # SQL to reset the sequence
        sql = f"""
        SELECT setval(
            pg_get_serial_sequence('{table_name}', '{id_column}'),
            (SELECT COALESCE(MAX({id_column}), 0) + 1 FROM {table_name}),
            false
        );
        """
        supabase.rpc('exec_sql', {'query': sql}).execute()
    except Exception as e:
        # If RPC doesn't exist, sequence will be manually fixed
        # This is not critical - the error message will show if it fails
        pass


def parse_date(date_str):
    """Convert SAQ date format (2025/12/27) to ISO format"""
    if not date_str:
        return None
    date_str = clean_value(date_str)
    try:
        return datetime.strptime(date_str, '%Y/%m/%d').strftime('%Y-%m-%d')
    except:
        return None


def find_csv_file(folder, pattern):
    """Find CSV file matching pattern in folder"""
    for f in os.listdir(folder):
        if f.endswith('.csv') and pattern.lower() in f.lower():
            return os.path.join(folder, f)
    return None


def process_ventes(folder):
    """
    Process Ventes (Sales) CSV
    - Filter Cherry River products only
    - APPEND new rows (sales are historical, never delete)
    """
    filepath = find_csv_file(folder, 'Ventes_20')  # Matches Ventes_2025103.csv
    if not filepath:
        print("X Ventes file not found")
        return 0

    print(f"* Processing Ventes: {os.path.basename(filepath)}")

    rows_to_insert = []
    with open(filepath, 'r', encoding='latin-1') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            code_saq = clean_value(row.get('SAQ CODE (IPC)/CODE SAQ (CIP)', ''))

            # Filter Cherry River only
            if code_saq not in CHERRY_RIVER_CODES:
                continue

            rows_to_insert.append({
                'code_saq': code_saq,
                'no_fournisseur': int(clean_value(row.get('SUPPLIER NO/NO FOURNISSEUR', 0)) or 0),
                'no_succursale': clean_value(row.get('OUTLET NO/NO SUCCURSALE', '')),
                'type_client': int(clean_value(row.get('CLIENT TYPE/TYPE CLIENT', 0)) or 0),
                'no_da': int(clean_value(row.get('AD NO/NO DA', 0)) or 0),
                'annee': int(clean_value(row.get('YEAR/ANNÉE', 0)) or 0),
                'periode': int(clean_value(row.get('PERIOD/PÉRIODE', 0)) or 0),
                'semaine': int(clean_value(row.get('WEEK/SEMAINE', 0)) or 0),
                'bouteille': int(clean_value(row.get('QTY OF BOTTLES/QTÉ BOUTEILLE', 0)) or 0),
                'montant': float(clean_value(row.get('AMOUNT/MONTANT', 0)) or 0)
            })

    if rows_to_insert:
        # Check for duplicates before inserting
        sample = rows_to_insert[0]
        existing = supabase.table('saq_ventes').select('saq_ventes_id').eq('annee', sample['annee']).eq('periode', sample['periode']).eq('semaine', sample['semaine']).limit(1).execute()

        if existing.data:
            print(f"!  Data for {sample['annee']}-P{sample['periode']}-W{sample['semaine']} already exists. Skipping.")
            return 0

        # Insert in batches of 500
        for i in range(0, len(rows_to_insert), 500):
            batch = rows_to_insert[i:i+500]
            supabase.table('saq_ventes').insert(batch).execute()

        print(f"OK Inserted {len(rows_to_insert)} sales records")

    return len(rows_to_insert)


def process_inventaire_succursales(folder):
    """
    Process Store Inventory CSV
    - Filter Cherry River products only
    - UPSERT (replace current week's data)
    """
    filepath = find_csv_file(folder, 'Inventaires succursales')
    if not filepath:
        print("X Inventaires succursales file not found")
        return 0

    print(f"* Processing Store Inventory: {os.path.basename(filepath)}")

    rows_to_upsert = []
    with open(filepath, 'r', encoding='latin-1') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            code_saq = clean_value(row.get('CODE SAQ (CIP)', ''))

            if code_saq not in CHERRY_RIVER_CODES:
                continue

            rows_to_upsert.append({
                'succursale': clean_value(row.get('NO SUCCURSALE', '')),
                'code_saq': code_saq,
                'qty': int(clean_value(row.get('QTÉ INVENTAIRE(unités)', 0)) or 0),
                'annee': int(clean_value(row.get('ANNÉE', 0)) or 0),
                'periode': int(clean_value(row.get('PÉRIODE', 0)) or 0),
                'semaine': int(clean_value(row.get('SEMAINE', 0)) or 0),
                'date_du_jour': clean_value(row.get('DATE DU JOUR', ''))
            })

    if rows_to_upsert:
        # Use UPSERT to handle duplicates gracefully
        # If a record exists, it will be updated; if not, inserted
        for i in range(0, len(rows_to_upsert), 500):
            batch = rows_to_upsert[i:i+500]
            try:
                # Try upsert with on_conflict parameter (composite key)
                supabase.table('saq_inventaire').upsert(
                    batch,
                    on_conflict='code_saq,succursale,annee,periode,semaine'
                ).execute()
            except Exception as e:
                # Fallback: try regular upsert (will use primary key)
                supabase.table('saq_inventaire').upsert(batch).execute()

        print(f"OK Upserted {len(rows_to_upsert)} store inventory records")

    return len(rows_to_upsert)


def process_inventaire_entrepots(folder):
    """
    Process Warehouse Inventory CSV
    - Filter Cherry River products only
    - UPSERT (replace current week's data)
    - THIS IS KEY for predicting SAQ orders!
    """
    filepath = find_csv_file(folder, 'Inventaires entrepots')
    if not filepath or 'CSM' in filepath:
        # Try without CSM
        for f in os.listdir(folder):
            if 'Inventaires entrepots' in f and 'CSM' not in f and f.endswith('.csv'):
                filepath = os.path.join(folder, f)
                break

    if not filepath:
        print("X Inventaires entrepots file not found")
        return 0

    print(f"* Processing Warehouse Inventory: {os.path.basename(filepath)}")

    rows_to_upsert = []
    with open(filepath, 'r', encoding='latin-1') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            code_saq = clean_value(row.get('CODE SAQ (CIP)', ''))

            if code_saq not in CHERRY_RIVER_CODES:
                continue

            rows_to_upsert.append({
                'entrepot': clean_value(row.get('ENTREPÔT', '')),
                'code_saq': code_saq,
                'qty': float(clean_value(row.get('QTÉ INVENTAIRE(caisse)', 0)) or 0),
                'annee': int(clean_value(row.get('ANNÉE', 0)) or 0),
                'periode': int(clean_value(row.get('PÉRIODE', 0)) or 0),
                'semaine': int(clean_value(row.get('SEMAINE', 0)) or 0),
                'date': parse_date(row.get('DATE DU JOUR', ''))
            })

    if rows_to_upsert:
        # Use UPSERT to handle duplicates gracefully
        for i in range(0, len(rows_to_upsert), 500):
            batch = rows_to_upsert[i:i+500]
            try:
                # Try upsert with on_conflict parameter (composite key)
                supabase.table('saq_inventaire_entrepot').upsert(
                    batch,
                    on_conflict='code_saq,entrepot,annee,periode,semaine'
                ).execute()
            except Exception as e:
                # Fallback: try regular upsert (will use primary key)
                supabase.table('saq_inventaire_entrepot').upsert(batch).execute()

        print(f"OK Upserted {len(rows_to_upsert)} warehouse inventory records")

    return len(rows_to_upsert)


def process_sous_commandes(folder):
    """
    Process SAQ Orders (Sous-commandes) CSV
    - Already filtered to Cherry River (it's "My Products" orders)
    - APPEND new orders
    """
    filepath = find_csv_file(folder, 'Sous-commandes')
    if not filepath:
        print("X Sous-commandes file not found")
        return 0

    print(f"* Processing SAQ Orders: {os.path.basename(filepath)}")

    rows_to_insert = []
    with open(filepath, 'r', encoding='latin-1') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            no_commande = clean_value(row.get('NO COMMANDE', ''))

            # Check if order already exists
            existing = supabase.table('saq_commandes').select('id').eq('no_commande', no_commande).limit(1).execute()
            if existing.data:
                continue

            rows_to_insert.append({
                'code_saq': clean_value(row.get('CODE SAQ (CIP)', '')),
                'no_commande': no_commande,
                'date_commande': parse_date(row.get('DATE COMMANDE', '')),
                'qty_commandee': int(clean_value(row.get('QTÉ COMMANDÉE', 0)) or 0),
                'unite_commande': clean_value(row.get('UNITÉ DE COMMANDE', '')),
                'date_livraison_prevue': parse_date(row.get('DATE PRÉVUE LIVRAISON', '')),
                'prix_achat': float(clean_value(row.get('PRIX ACHAT ORIGINE', 0)) or 0),
                'code_monnaie': clean_value(row.get('CODE MONNAIE', '')),
                'annee': int(clean_value(row.get('ANNÉE', 0)) or 0),
                'periode': int(clean_value(row.get('PÉRIODE', 0)) or 0),
                'semaine': int(clean_value(row.get('SEMAINE', 0)) or 0)
            })

    if rows_to_insert:
        supabase.table('saq_commandes').insert(rows_to_insert).execute()
        print(f"OK Inserted {len(rows_to_insert)} new SAQ orders")
    else:
        print("i  No new orders to insert")

    return len(rows_to_insert)


def main(folder):
    """Main function to process all SAQ files"""
    print("=" * 60)
    print("SAQ WEEKLY DATA UPDATE")
    print(f"Folder: {folder}")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    if not os.path.exists(folder):
        print(f"X Folder not found: {folder}")
        return

    # Process each file type
    ventes_count = process_ventes(folder)
    store_count = process_inventaire_succursales(folder)
    warehouse_count = process_inventaire_entrepots(folder)
    orders_count = process_sous_commandes(folder)

    print("=" * 60)
    print("SUMMARY")
    print(f"  Sales records: {ventes_count}")
    print(f"  Store inventory: {store_count}")
    print(f"  Warehouse inventory: {warehouse_count}")
    print(f"  New orders: {orders_count}")
    print("=" * 60)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='Update SAQ data in Supabase')
    parser.add_argument('--folder', type=str, default=r'c:\Users\Zestro\Desktop\My Automations\CherryRiver\SAQ Documents 2', help='Path to SAQ CSV folder')
    args = parser.parse_args()

    main(args.folder)
