@echo off
REM SAQ Weekly Update - Imports latest weekly CSVs into Supabase

REM Change to the project root directory
cd /d "%~dp0.."

echo ============================================================
echo SAQ WEEKLY DATA UPDATE
echo ============================================================
echo Working directory: %CD%
echo Target folder: SAQ Documents 2
echo.
echo This script will:
echo 1. Process Ventes CSV (append new sales data)
echo 2. Process Store Inventory (replace snapshot)
echo 3. Process Warehouse Inventory (replace snapshot)
echo 4. Process Orders (append new orders)
echo.

REM Step 1: Unzip any ZIP files first
echo Step 1: Unzipping downloaded files...
echo.
python scripts\unzip_saq_files.py
echo.

REM Step 2: Run weekly update script
echo Step 2: Running SAQ Weekly Update...
python scripts\saq_weekly_update.py --folder "SAQ Documents 2"

echo.
echo ============================================================
echo Update completed. Check summary above.
echo ============================================================
pause
