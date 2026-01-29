"""
Unzip SAQ files from SAQ Documents 2 folder
SAQ Infocom downloads files as ZIP archives that need to be extracted
"""
import zipfile
import os
from pathlib import Path

def unzip_saq_files():
    """Unzip all ZIP files in SAQ Documents 2 folder"""
    saq_dir = Path(__file__).parent.parent / "SAQ Documents 2"

    print("=" * 60)
    print("UNZIPPING SAQ FILES")
    print(f"Directory: {saq_dir}")
    print("=" * 60)

    if not saq_dir.exists():
        print(f"X Directory not found: {saq_dir}")
        return

    zip_files = list(saq_dir.glob("*.zip"))

    if not zip_files:
        print("+ No ZIP files found (already extracted)")
        return

    print(f"Found {len(zip_files)} ZIP files to extract:\n")

    for zip_path in zip_files:
        try:
            print(f"* Extracting: {zip_path.name}")

            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                # Extract to same directory
                zip_ref.extractall(saq_dir)

                # List extracted files
                for member in zip_ref.namelist():
                    print(f"   + {member}")

            # Delete the ZIP file after successful extraction
            zip_path.unlink()
            print(f"   -  Deleted: {zip_path.name}\n")

        except Exception as e:
            print(f"   X Failed to extract {zip_path.name}: {e}\n")

    print("=" * 60)
    print("EXTRACTION COMPLETE")
    print("=" * 60)

    # List all CSV files now available
    csv_files = list(saq_dir.glob("*.csv"))
    print(f"\n+ {len(csv_files)} CSV files ready for processing:")
    for csv in csv_files:
        size_mb = csv.stat().st_size / 1024 / 1024
        print(f"   • {csv.name} ({size_mb:.2f} MB)")

if __name__ == "__main__":
    unzip_saq_files()
