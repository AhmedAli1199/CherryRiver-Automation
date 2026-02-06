@echo off
REM ==============================================
REM Deploy GitHub Actions Automation
REM Copies files to correct locations
REM ==============================================

echo.
echo ============================================================
echo DEPLOYING GITHUB ACTIONS AUTOMATION
echo ============================================================
echo.

REM Check if we're in the right directory
if not exist "workflows\saq_weekly_update.yml" (
    echo ERROR: Run this script from the github-actions-setup folder!
    pause
    exit /b 1
)

echo This will:
echo   1. Copy run_weekly_pipeline.py to project root
echo   2. Create .github/workflows/ folder
echo   3. Copy workflow file to .github/workflows/
echo.
echo Press any key to continue, or Ctrl+C to cancel...
pause > nul

REM Copy pipeline script to root
echo.
echo [1/3] Copying run_weekly_pipeline.py to project root...
copy /Y run_weekly_pipeline.py ..\
if errorlevel 1 (
    echo ERROR: Failed to copy pipeline script!
    pause
    exit /b 1
)
echo ✓ Pipeline script copied

REM Create .github/workflows directory
echo.
echo [2/3] Creating .github/workflows directory...
if not exist "..\.github" mkdir "..\.github"
if not exist "..\.github\workflows" mkdir "..\.github\workflows"
echo ✓ Directory created

REM Copy workflow file
echo.
echo [3/3] Copying workflow file...
copy /Y workflows\saq_weekly_update.yml ..\.github\workflows\
if errorlevel 1 (
    echo ERROR: Failed to copy workflow file!
    pause
    exit /b 1
)
echo ✓ Workflow file copied

echo.
echo ============================================================
echo ✓ DEPLOYMENT COMPLETE!
echo ============================================================
echo.
echo Files deployed:
echo   ✓ run_weekly_pipeline.py → Project root
echo   ✓ saq_weekly_update.yml → .github/workflows/
echo.
echo Next steps:
echo   1. git add .
echo   2. git commit -m "Add automated SAQ pipeline"
echo   3. git push
echo   4. Add secrets to GitHub (see SETUP_GUIDE.md)
echo   5. Test workflow manually on GitHub Actions
echo.
pause
