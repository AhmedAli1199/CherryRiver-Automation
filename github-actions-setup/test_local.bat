@echo off
REM ==============================================
REM Test SAQ Pipeline Locally
REM Run this to test before pushing to GitHub
REM ==============================================

echo.
echo ============================================================
echo TESTING SAQ PIPELINE LOCALLY
echo ============================================================
echo.

REM Check if virtual environment exists
if not exist ".venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found!
    echo Please run: python -m venv .venv
    echo Then: .venv\Scripts\activate
    echo Then: pip install -r requirements.txt
    pause
    exit /b 1
)

REM Activate virtual environment
call .venv\Scripts\activate.bat

REM Check if .env file exists
if not exist ".env" (
    echo ERROR: .env file not found!
    echo Please create .env with:
    echo   SAQ_USERNAME=your_username
    echo   SAQ_PASSWORD=your_password
    echo   SUPABASE_URL=your_url
    echo   SUPABASE_KEY=your_key
    pause
    exit /b 1
)

echo ✓ Environment setup complete
echo.
echo Starting pipeline test...
echo This will:
echo   1. Scrape SAQ B2B portal
echo   2. Unzip files
echo   3. Upload to Supabase
echo.
echo Press Ctrl+C to cancel, or
pause

REM Run the pipeline
python run_weekly_pipeline.py

echo.
echo ============================================================
echo TEST COMPLETE
echo ============================================================
echo.
echo Check the output above for any errors.
echo If successful, you can now push to GitHub!
echo.
pause
