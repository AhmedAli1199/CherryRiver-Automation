# 🚀 GitHub Actions Automation - Ready to Deploy

This folder contains everything you need to set up automated SAQ data updates.

## 📁 What's in This Folder

```
github-actions-setup/
├── README.md                    ← You are here
├── SETUP_GUIDE.md              ← Complete setup instructions
├── run_weekly_pipeline.py      ← Master pipeline script (copy to project root)
├── test_local.bat              ← Test locally before deploying
└── workflows/
    └── saq_weekly_update.yml   ← GitHub Actions workflow (copy to .github/workflows/)
```

## ⚡ Quick Start (5 minutes)

### 1. Copy Files to Project Root

```bash
# Copy the pipeline script to project root
copy run_weekly_pipeline.py ..\

# Create .github/workflows folder and copy workflow
mkdir ..\.github\workflows
copy workflows\saq_weekly_update.yml ..\.github\workflows\
```

Or manually:
- Move `run_weekly_pipeline.py` → Project root folder
- Move `workflows/saq_weekly_update.yml` → `.github/workflows/saq_weekly_update.yml`

### 2. Test Locally (Optional but Recommended)

```bash
# From project root
python github-actions-setup\test_local.bat
```

### 3. Push to GitHub

```bash
git add .
git commit -m "Add automated SAQ pipeline"
git push
```

### 4. Add Secrets to GitHub

Go to: **GitHub Repo → Settings → Secrets and variables → Actions**

Add these 4 secrets:

| Secret Name | Value |
|------------|-------|
| `SAQ_USERNAME` | `delagecherry` |
| `SAQ_PASSWORD` | `Samuel1995!!cherryriver` |
| `SUPABASE_URL` | `https://nqxqqoinpoomcqdddoqq.supabase.co` |
| `SUPABASE_KEY` | (your key from .env) |

### 5. Test on GitHub

1. Go to **Actions** tab
2. Click **"SAQ Weekly Data Update"**
3. Click **"Run workflow"** → **"Run workflow"**
4. Watch it complete ✅

### 6. Done! 🎉

It will now run automatically every Monday at 3 AM EST.

---

## 📖 Need More Details?

Read the complete guide: **[SETUP_GUIDE.md](SETUP_GUIDE.md)**

---

## 🆘 Troubleshooting

**Problem:** Workflow fails
**Solution:** 99% of the time it's wrong secrets. Double-check all 4 secrets.

**Problem:** Can't find Actions tab
**Solution:** Enable GitHub Actions in repo settings.

**Problem:** Want to change schedule
**Solution:** Edit `saq_weekly_update.yml`, change the cron expression.

---

## 📅 Schedule

Runs every Monday at 3:00 AM EST (8:00 AM UTC)

---

## 💰 Cost

**$0.00** - Completely free using GitHub Actions free tier

---

## ✅ Checklist

- [ ] Copy `run_weekly_pipeline.py` to project root
- [ ] Copy `workflows/saq_weekly_update.yml` to `.github/workflows/`
- [ ] Push to GitHub
- [ ] Add 4 secrets (SAQ_USERNAME, SAQ_PASSWORD, SUPABASE_URL, SUPABASE_KEY)
- [ ] Test run manually
- [ ] Verify data in Supabase
- [ ] Done! ✨
