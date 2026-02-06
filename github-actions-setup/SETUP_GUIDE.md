# 🤖 SAQ Weekly Automation Setup Guide

This guide will help you set up **automated weekly SAQ data updates** that run every Monday in the cloud using GitHub Actions (FREE).

## 📋 What This Automation Does

Every Monday at 3:00 AM EST, the automation will:
1. ✅ Log into SAQ B2B portal
2. ✅ Download latest sales and inventory CSV files
3. ✅ Unzip the files
4. ✅ Process and upload data to Supabase
5. ✅ Send notifications if anything fails

**Total setup time:** ~10 minutes
**Cost:** FREE (GitHub Actions free tier)

---

## 🚀 Setup Instructions

### Step 1: Push Code to GitHub

1. **Create a GitHub repository** (if you haven't already):
   ```bash
   # In your project directory
   git init
   git add .
   git commit -m "Initial commit: SAQ automation"
   ```

2. **Create a new repo on GitHub:**
   - Go to https://github.com/new
   - Name it: `cherryriver-automation` (or any name)
   - Make it **Private** (to keep credentials safe)
   - Click "Create repository"

3. **Push your code:**
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/cherryriver-automation.git
   git branch -M main
   git push -u origin main
   ```

---

### Step 2: Add Secrets to GitHub

Your credentials need to be stored securely in GitHub Secrets.

1. **Go to your repository on GitHub**
2. **Click Settings** → **Secrets and variables** → **Actions**
3. **Click "New repository secret"**
4. **Add these 4 secrets:**

| Secret Name | Value | Where to Find |
|------------|-------|---------------|
| `SAQ_USERNAME` | `delagecherry` | Your SAQ B2B username |
| `SAQ_PASSWORD` | `Samuel1995!!cherryriver` | Your SAQ B2B password |
| `SUPABASE_URL` | `https://nqxqqoinpoomcqdddoqq.supabase.co` | From your `.env` file |
| `SUPABASE_KEY` | `eyJhbGci...` (long string) | From your `.env` file |

**⚠️ IMPORTANT:** Don't commit your `.env` file to GitHub!

---

### Step 3: Enable GitHub Actions

1. **Go to your repository** → **Actions** tab
2. You should see "SAQ Weekly Data Update" workflow
3. If it says "Workflows disabled", click **"I understand my workflows, go ahead and enable them"**

---

### Step 4: Test the Automation

Before waiting for Monday, test it manually:

1. **Go to Actions** → **SAQ Weekly Data Update**
2. **Click "Run workflow"** → **Run workflow** (green button)
3. **Watch the progress** (takes ~5-10 minutes)

You should see:
- ✅ Checkout Repository
- ✅ Set up Python
- ✅ Install Dependencies
- ✅ Install Chrome
- ✅ Run SAQ Pipeline
- ✅ Upload Artifacts

**If it fails:**
- Click on the failed step to see error logs
- Check that all 4 secrets are set correctly
- Verify SAQ credentials are correct

---

### Step 5: Verify Data in Supabase

After the workflow completes:

1. **Go to Supabase** → **Table Editor**
2. **Check these tables:**
   - `saq_ventes` - Should have new sales records
   - `saq_daily_warehouse` - Should have updated inventory
   - `saq_store_inventory` - Should have store stock levels

3. **Check your Retool dashboard**
   - Production Planning page should show updated data

---

## 📅 Schedule Details

**Current Schedule:** Every Monday at 3:00 AM EST (8:00 AM UTC)

**To change the schedule:**
1. Edit `.github/workflows/saq_weekly_update.yml`
2. Change the cron expression:
   ```yaml
   schedule:
     - cron: '0 8 * * 1'  # Monday 8 AM UTC
   ```

**Cron Examples:**
- `0 8 * * 1` - Every Monday at 8 AM UTC (3 AM EST)
- `0 12 * * 1` - Every Monday at 12 PM UTC (7 AM EST)
- `0 8 * * 1,4` - Every Monday and Thursday at 8 AM UTC
- `0 8 * * *` - Every day at 8 AM UTC

**Cron Helper:** https://crontab.guru/

---

## 📊 Monitoring & Notifications

### View Execution History

1. **Go to Actions** tab in GitHub
2. **Click "SAQ Weekly Data Update"**
3. **See all past runs** with status (✅ Success / ❌ Failed)

### Email Notifications

GitHub automatically sends email notifications when workflows fail.

**To configure:**
1. **GitHub Settings** → **Notifications**
2. **Actions** → Check "Send notifications for failed workflows"

### Add Slack/Discord Notifications (Optional)

Want notifications in Slack or Discord? Add this step to the workflow:

```yaml
- name: 📧 Notify Slack on Success
  if: success()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "✅ SAQ Weekly Update Completed Successfully!"
      }
```

---

## 🐛 Troubleshooting

### ❌ Workflow fails at "Run SAQ Pipeline"

**Possible causes:**
1. **SAQ website is down or changed**
   - Check https://www.saq-b2b.com/ manually
   - Wait and try again later

2. **Credentials are wrong**
   - Verify SAQ_USERNAME and SAQ_PASSWORD secrets
   - Test login manually

3. **Supabase connection failed**
   - Verify SUPABASE_URL and SUPABASE_KEY secrets
   - Check Supabase is online

### ❌ Workflow times out after 30 minutes

- Increase timeout in workflow file:
  ```yaml
  jobs:
    scrape-and-update:
      timeout-minutes: 60  # Increase to 60 minutes
  ```

### ❌ Chrome/ChromeDriver issues

The workflow automatically installs Chrome. If it fails:
- Update Chrome installation step in workflow
- Check GitHub Actions logs for specific error

### 📥 Download Artifacts for Debugging

If the workflow fails, you can download the CSV files that were scraped:

1. **Go to the failed workflow run**
2. **Scroll down to "Artifacts"**
3. **Download "saq-data-files-XXX.zip"**
4. **Inspect the files locally**

---

## 💰 Cost & Limits

**GitHub Actions Free Tier:**
- 2,000 minutes/month for private repos
- Unlimited for public repos

**Your usage:**
- ~10 minutes per run
- 4 runs/month (every Monday)
- **Total: ~40 minutes/month (2% of free tier)**

You're well within the free tier! 🎉

---

## 🔒 Security Best Practices

✅ **DO:**
- Store credentials in GitHub Secrets
- Use private repositories
- Keep `.env` file in `.gitignore`

❌ **DON'T:**
- Commit `.env` file to GitHub
- Share your repository publicly with secrets
- Hardcode credentials in code

---

## 🎯 What's Next?

Once this is running smoothly, you can:

1. **Add more data sources** to the pipeline
2. **Send email reports** after each run
3. **Add data quality checks** before upload
4. **Create a dashboard** showing automation health

---

## 📞 Support

**If you need help:**
1. Check workflow logs in GitHub Actions
2. Review error messages in Supabase logs
3. Test each script locally first
4. Verify all secrets are set correctly

**Common Issues:**
- Most failures are due to incorrect secrets
- SAQ website changes can break the scraper
- Supabase connection issues are usually temporary

---

## ✅ Checklist

Use this checklist to verify everything is set up:

- [ ] Code pushed to GitHub
- [ ] Repository is private
- [ ] All 4 secrets added (SAQ_USERNAME, SAQ_PASSWORD, SUPABASE_URL, SUPABASE_KEY)
- [ ] GitHub Actions enabled
- [ ] Test run completed successfully
- [ ] Data verified in Supabase
- [ ] Email notifications configured
- [ ] Schedule confirmed (every Monday)

---

**🎉 That's it! Your SAQ data will now update automatically every Monday without any manual work!**
