"""
SAQ Data Schema Analyzer
Unzips all files in SAQ Documents 2 folder and analyzes CSV structure
Shows columns, data types, and sample rows for each file
"""

import os
import zipfile
import pandas as pd
from pathlib import Path
import json

# Configuration
DOWNLOAD_DIR = Path(__file__).parent / "SAQ Documents 2"

def extract_all_zips():
    """Extract all ZIP files in the directory"""
    print("=" * 80)
    print("EXTRACTING ZIP FILES")
    print("=" * 80)

    zip_files = list(DOWNLOAD_DIR.glob("*.zip"))

    if not zip_files:
        print("No ZIP files found")
        return

    for zip_file in zip_files:
        print(f"\n📦 Extracting: {zip_file.name}")
        try:
            with zipfile.ZipFile(zip_file, 'r') as zip_ref:
                # Extract to same directory
                zip_ref.extractall(DOWNLOAD_DIR)

                # Show extracted files
                file_list = zip_ref.namelist()
                for file in file_list:
                    print(f"   ✓ {file}")

        except Exception as e:
            print(f"   ✗ Error: {str(e)}")

    print("\n" + "=" * 80)

def find_all_csvs():
    """Find all CSV files recursively"""
    csv_files = []

    # Direct CSVs
    csv_files.extend(list(DOWNLOAD_DIR.glob("*.csv")))

    # CSVs in subdirectories
    csv_files.extend(list(DOWNLOAD_DIR.glob("**/*.csv")))

    # Remove duplicates
    csv_files = list(set(csv_files))

    return sorted(csv_files)

def analyze_csv(csv_path):
    """Analyze a single CSV file and return schema info"""
    print(f"\n{'='*80}")
    print(f"📄 FILE: {csv_path.name}")
    print(f"{'='*80}")
    print(f"Full path: {csv_path}")
    print(f"Size: {csv_path.stat().st_size / 1024:.2f} KB")

    try:
        # Try reading with different encodings
        encodings = ['utf-8', 'latin-1', 'iso-8859-1', 'cp1252']
        df = None

        for encoding in encodings:
            try:
                df = pd.read_csv(csv_path, encoding=encoding, nrows=1000)  # Read first 1000 rows for analysis
                print(f"✓ Encoding: {encoding}")
                break
            except:
                continue

        if df is None:
            print("✗ Could not read file with any encoding")
            return None

        # Basic info
        total_rows = len(df)
        total_cols = len(df.columns)

        print(f"\n📊 BASIC INFO:")
        print(f"   Rows (sample): {total_rows}")
        print(f"   Columns: {total_cols}")

        # Column information
        print(f"\n📋 COLUMNS ({total_cols} total):")
        print("-" * 80)

        schema = []
        for i, col in enumerate(df.columns, 1):
            dtype = str(df[col].dtype)
            non_null = df[col].notna().sum()
            null_pct = (df[col].isna().sum() / len(df)) * 100
            unique_vals = df[col].nunique()

            # Sample non-null value
            sample_val = df[col].dropna().iloc[0] if df[col].notna().any() else "NULL"

            print(f"{i:2}. {col:40} | Type: {dtype:10} | Nulls: {null_pct:5.1f}% | Unique: {unique_vals:6}")

            schema.append({
                "column_name": col,
                "data_type": dtype,
                "null_percentage": round(null_pct, 2),
                "unique_values": unique_vals,
                "sample_value": str(sample_val)[:50]
            })

        # Sample rows
        print(f"\n📝 SAMPLE ROWS (First 2):")
        print("-" * 80)

        # Show first 2 rows in a readable format
        for idx in range(min(2, len(df))):
            print(f"\nRow {idx + 1}:")
            for col in df.columns:
                value = df.iloc[idx][col]
                # Truncate long values
                value_str = str(value)[:60]
                if len(str(value)) > 60:
                    value_str += "..."
                print(f"   {col:35} = {value_str}")

        # Data quality checks
        print(f"\n🔍 DATA QUALITY:")
        print("-" * 80)

        # Check for completely empty columns
        empty_cols = [col for col in df.columns if df[col].isna().all()]
        if empty_cols:
            print(f"⚠️  Empty columns: {', '.join(empty_cols)}")
        else:
            print("✓ No completely empty columns")

        # Check for duplicate rows
        dup_count = df.duplicated().sum()
        if dup_count > 0:
            print(f"⚠️  Duplicate rows: {dup_count} ({dup_count/len(df)*100:.1f}%)")
        else:
            print("✓ No duplicate rows")

        # Identify potential ID columns
        potential_ids = [col for col in df.columns if df[col].nunique() == len(df)]
        if potential_ids:
            print(f"🔑 Potential ID columns: {', '.join(potential_ids)}")

        # Identify potential foreign keys (columns with limited unique values)
        potential_fks = [col for col in df.columns if df[col].nunique() < len(df) * 0.1 and df[col].nunique() > 1]
        if potential_fks:
            print(f"🔗 Potential FK/Category columns: {', '.join(potential_fks[:5])}")

        return {
            "filename": csv_path.name,
            "path": str(csv_path),
            "size_kb": round(csv_path.stat().st_size / 1024, 2),
            "rows": total_rows,
            "columns": total_cols,
            "schema": schema,
            "empty_columns": empty_cols,
            "duplicate_rows": dup_count,
            "potential_id_columns": potential_ids,
            "potential_fk_columns": potential_fks[:5]
        }

    except Exception as e:
        print(f"\n✗ ERROR analyzing file: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def generate_summary_report(all_schemas):
    """Generate a summary report of all files"""
    print("\n" + "=" * 80)
    print("📊 SUMMARY REPORT")
    print("=" * 80)

    if not all_schemas:
        print("No CSV files analyzed")
        return

    print(f"\nTotal CSV files found: {len(all_schemas)}")
    print("\nFile Overview:")
    print("-" * 80)

    for schema in all_schemas:
        if schema:
            print(f"\n{schema['filename']}")
            print(f"   Rows: {schema['rows']:,} | Columns: {schema['columns']} | Size: {schema['size_kb']:.2f} KB")

            if schema['potential_id_columns']:
                print(f"   🔑 ID columns: {', '.join(schema['potential_id_columns'][:3])}")

    # Save to JSON for reference
    output_file = Path(__file__).parent / "saq_data_schema_analysis.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(all_schemas, f, indent=2, ensure_ascii=False)

    print(f"\n💾 Full schema saved to: {output_file}")

def generate_supabase_suggestions(all_schemas):
    """Suggest Supabase table structures based on CSV analysis"""
    print("\n" + "=" * 80)
    print("🗄️  SUPABASE TABLE SUGGESTIONS")
    print("=" * 80)

    if not all_schemas:
        return

    for schema in all_schemas:
        if not schema:
            continue

        print(f"\n📋 Table for: {schema['filename']}")
        print("-" * 80)

        # Generate suggested table name
        table_name = schema['filename'].replace('.csv', '').replace('-', '_').replace(' ', '_').lower()
        print(f"Suggested table name: {table_name}")

        print("\nSuggested columns:")

        for col_info in schema['schema']:
            col_name = col_info['column_name'].replace(' ', '_').replace('-', '_').lower()

            # Map pandas dtypes to Supabase/PostgreSQL types
            dtype = col_info['data_type']
            if 'int' in dtype:
                pg_type = 'integer'
            elif 'float' in dtype:
                pg_type = 'numeric'
            elif 'datetime' in dtype or 'date' in dtype:
                pg_type = 'timestamp'
            elif 'bool' in dtype:
                pg_type = 'boolean'
            else:
                pg_type = 'text'

            # Suggest if column should be nullable
            nullable = "NULL" if col_info['null_percentage'] > 0 else "NOT NULL"

            print(f"   {col_name:40} {pg_type:15} {nullable}")

        # Suggest primary key
        if schema['potential_id_columns']:
            print(f"\n   PRIMARY KEY: {schema['potential_id_columns'][0]}")
        else:
            print(f"\n   PRIMARY KEY: Consider adding 'id SERIAL PRIMARY KEY'")

def main():
    """Main execution"""
    print("\n" + "🔍" * 40)
    print("SAQ DATA SCHEMA ANALYZER")
    print("🔍" * 40 + "\n")

    if not DOWNLOAD_DIR.exists():
        print(f"❌ Directory not found: {DOWNLOAD_DIR}")
        print(f"Please ensure the 'SAQ Documents 2' folder exists")
        return

    # Step 1: Extract all ZIPs
    extract_all_zips()

    # Step 2: Find all CSVs
    print("\n" + "=" * 80)
    print("FINDING CSV FILES")
    print("=" * 80)

    csv_files = find_all_csvs()

    if not csv_files:
        print("❌ No CSV files found")
        return

    print(f"\n✓ Found {len(csv_files)} CSV file(s):")
    for csv_file in csv_files:
        print(f"   - {csv_file.name}")

    # Step 3: Analyze each CSV
    all_schemas = []

    for csv_file in csv_files:
        schema = analyze_csv(csv_file)
        all_schemas.append(schema)

    # Step 4: Generate summary
    generate_summary_report(all_schemas)

    # Step 5: Supabase suggestions
    generate_supabase_suggestions(all_schemas)

    print("\n" + "✅" * 40)
    print("ANALYSIS COMPLETE!")
    print("✅" * 40 + "\n")

if __name__ == "__main__":
    main()
