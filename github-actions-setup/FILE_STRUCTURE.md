# 📁 File Structure Guide

This document shows where each file should go for the automation to work.

## 🎯 Current Setup Folder

```
github-actions-setup/           ← You are here
├── README.md                   ← Quick start guide
├── SETUP_GUIDE.md             ← Complete setup instructions
├── FILE_STRUCTURE.md          ← This file
├── DEPLOY.bat                 ← Auto-deploy script
├── run_weekly_pipeline.py     ← Master pipeline script
├── test_local.bat             ← Test locally
└── workflows/
    └── saq_weekly_update.yml  ← GitHub Actions workflow
```

## 🎯 Target Project Structure (After Deployment)

```
CherryRiver/                           ← Project root
├── .env                               ← Your credentials (DO NOT COMMIT!)
├── .gitignore                         ← Updated to ignore .env
├── requirements.txt                   ← Python dependencies
├── saq_data_scraper.py               ← SAQ scraper (existing)
├── run_weekly_pipeline.py            ← NEW: Master pipeline
│
├── .github/                           ← NEW: GitHub Actions folder
│   └── workflows/
│       └── saq_weekly_update.yml     ← NEW: Automation workflow
│
├── scripts/
│   ├── unzip_saq_files.py            ← Unzip SAQ files (existing)
│   └── saq_weekly_update.py          ← Upload to Supabase (existing)
│
├── github-actions-setup/              ← This setup folder (keep for reference)
│   ├── README.md
│   ├── SETUP_GUIDE.md
│   ├── DEPLOY.bat
│   └── ...
│
└── SAQ Documents 2/                   ← Downloaded files (ignored by git)
```

## 🚀 Deployment Options

### Option 1: Automatic (Recommended)

Run the deployment script:

```bash
# From github-actions-setup folder
DEPLOY.bat
```

This automatically copies files to the right locations.

### Option 2: Manual

Copy files manually:

1. **Copy to project root:**
   - `run_weekly_pipeline.py` → `../run_weekly_pipeline.py`

2. **Create .github/workflows/ folder:**
   ```bash
   mkdir ../.github
   mkdir ../.github/workflows
   ```

3. **Copy workflow file:**
   - `workflows/saq_weekly_update.yml` → `../.github/workflows/saq_weekly_update.yml`

## ✅ Verification Checklist

After deployment, verify these files exist:

```bash
# Check if files are in place
ls ../run_weekly_pipeline.py           # Should exist
ls ../.github/workflows/saq_weekly_update.yml  # Should exist
```

Or in Windows:

```cmd
dir ..\run_weekly_pipeline.py
dir ..\.github\workflows\saq_weekly_update.yml
```

## 📋 What Gets Committed to GitHub

✅ **COMMIT THESE:**
- `run_weekly_pipeline.py`
- `.github/workflows/saq_weekly_update.yml`
- `saq_data_scraper.py` (updated)
- `scripts/*.py` (all scripts)
- `.gitignore` (updated)
- `requirements.txt`
- `github-actions-setup/` folder (optional, for reference)

❌ **DO NOT COMMIT:**
- `.env` (contains passwords!)
- `SAQ Documents 2/` (large files)
- `.venv/` (virtual environment)
- `*.csv`, `*.zip` (data files)

The `.gitignore` file already prevents these from being committed.

## 🔐 Secrets Configuration

Secrets are NOT stored in files. They go in GitHub's web interface:

**Location:** GitHub Repo → Settings → Secrets and variables → Actions

**Required secrets:**
1. `SAQ_USERNAME`
2. `SAQ_PASSWORD`
3. `SUPABASE_URL`
4. `SUPABASE_KEY`

See `SETUP_GUIDE.md` for detailed instructions.

## 🎬 Action Flow

When you push to GitHub, here's what happens:

```
1. GitHub detects .github/workflows/saq_weekly_update.yml
2. Reads the schedule (every Monday 3 AM EST)
3. At scheduled time:
   a. Spins up Ubuntu VM
   b. Installs Python + Chrome
   c. Checks out your code
   d. Runs: python run_weekly_pipeline.py
   e. Pipeline runs:
      - saq_data_scraper.py (download from SAQ)
      - scripts/unzip_saq_files.py (unzip)
      - scripts/saq_weekly_update.py (upload to Supabase)
   f. Success! Data updated
```

## 📞 Need Help?

- **Quick start:** See `README.md`
- **Full guide:** See `SETUP_GUIDE.md`
- **Test locally:** Run `test_local.bat`
- **Deploy files:** Run `DEPLOY.bat`
