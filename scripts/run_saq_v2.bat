@echo off
REM SAQ Processor V2 - Uses Mes produits.csv as master list

REM Change to the project root directory (parent of scripts folder)
cd /d "%~dp0.."

echo ============================================================
echo SAQ TO SUPABASE PIPELINE V2
echo ============================================================
echo Working directory: %CD%
echo.
echo Strategy:
echo 1. Load 79 Cherry River products from Mes produits.csv
echo 2. Filter all other files by those SAQ codes
echo 3. Upload to Supabase with correct column names
echo.

REM Step 1: Unzip any ZIP files first
echo Step 1: Unzipping downloaded files...
echo.
python scripts\unzip_saq_files.py
echo.

REM Step 2: Run processor V2 (using system Python, no venv needed)
echo Step 2: Running SAQ Processor V2...
python processors\saq_processor_v2.py

echo.
echo ============================================================
echo Pipeline completed. Check logs above for status.
echo ============================================================
pause
