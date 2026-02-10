#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SAQ Weekly Pipeline - Complete Automation
Runs every Monday to scrape SAQ data and update Supabase

Pipeline Steps:
1. Scrape SAQ B2B portal (download CSV/ZIP files)
2. Unzip downloaded files
3. Process and upload data to Supabase
"""

import os
import sys
import subprocess
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file (for local testing)
load_dotenv()

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except:
        pass

def print_header(message):
    """Print a formatted header"""
    print("\n" + "="*70)
    print(f"  {message}")
    print("="*70 + "\n")

def run_command(description, command, check=True):
    """Run a shell command and handle errors"""
    print(f"> {description}")
    print(f"  Command: {command}\n")
    print("-" * 70)

    # Run without capturing output - shows real-time progress
    result = subprocess.run(
        command,
        shell=True
    )

    print("-" * 70)

    if result.returncode != 0:
        print(f"\n[ERROR] {description} failed!")
        if check:
            sys.exit(1)
        return False

    print(f"\n[OK] {description} completed successfully\n")
    return True

def main():
    print_header("SAQ WEEKLY PIPELINE STARTED")
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Working directory: {os.getcwd()}\n")

    # Verify environment variables
    print("Checking environment variables...")
    required_vars = ["SAQ_USERNAME", "SAQ_PASSWORD", "SUPABASE_URL", "SUPABASE_KEY"]
    missing_vars = [var for var in required_vars if not os.getenv(var)]

    if missing_vars:
        print(f"[ERROR] Missing required environment variables: {', '.join(missing_vars)}")
        sys.exit(1)

    print(f"[OK] All required environment variables found\n")

    # Step 1: Run SAQ scraper
    print_header("STEP 1: Scraping SAQ B2B Portal")
    success = run_command(
        "SAQ Data Scraper",
        f'"{sys.executable}" saq_data_scraper.py'
    )

    if not success:
        print("[ERROR] Scraper failed, aborting pipeline")
        sys.exit(1)

    # Step 2: Unzip downloaded files
    print_header("STEP 2: Unzipping Downloaded Files")
    run_command(
        "Unzip SAQ Files",
        f'"{sys.executable}" scripts/unzip_saq_files.py'
    )

    # Step 3: Process and upload to Supabase
    print_header("STEP 3: Processing and Uploading to Supabase")
    run_command(
        "SAQ Weekly Update",
        f'"{sys.executable}" scripts/saq_weekly_update.py --folder "SAQ Documents 2"'
    )

    # Summary
    print_header("PIPELINE COMPLETED SUCCESSFULLY")
    print(f"Finished at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("\nAll steps completed successfully!")
    print("Data has been scraped and uploaded to Supabase.\n")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[ERROR] Pipeline interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n[ERROR] Pipeline failed with error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
