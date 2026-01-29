# SAQ Email Alert System - Complete Package

## 📦 What's Included

This folder contains everything you need to set up the automated email alert system for Cherry River's SAQ inventory monitoring.

### Files in This Package:

1. **`saq_email_alerts_workflow.json`** ⭐ MAIN FILE
   - Complete N8N workflow (ready to import)
   - 8 nodes configured and connected
   - Runs daily at 9:00 AM (Mon-Fri)

2. **`SETUP_GUIDE.md`** 📖 STEP-BY-STEP INSTRUCTIONS
   - Complete setup walkthrough (30 minutes)
   - Screenshots and examples
   - Troubleshooting section
   - Success checklist

3. **`CREDENTIALS_QUICK_REFERENCE.md`** 🔐 CREDENTIAL SETUP
   - Supabase PostgreSQL connection details
   - Gmail OAuth2 setup
   - Testing instructions
   - Security best practices

4. **`email_logs_table.sql`** 🗄️ DATABASE TABLE
   - SQL script to create logging table
   - Run in Supabase SQL Editor
   - Tracks all emails sent

5. **`EMAIL_PREVIEW_EXAMPLE.html`** 👀 PREVIEW
   - Open in browser to see email design
   - Shows exactly what sales reps will receive
   - Professional, branded layout

6. **`README.md`** (this file) 📄 OVERVIEW
   - Quick start guide
   - File descriptions
   - What to do next

---

## 🚀 Quick Start (3 Steps)

### Step 1: Create Email Logs Table
```bash
1. Open Supabase Dashboard
2. Go to SQL Editor
3. Copy contents of email_logs_table.sql
4. Run the query
5. ✓ Table created!
```

### Step 2: Set Up N8N
```bash
1. Create N8N Cloud account (n8n.io)
2. Set up 2 credentials:
   - Supabase PostgreSQL (see CREDENTIALS_QUICK_REFERENCE.md)
   - Gmail OAuth2 (see CREDENTIALS_QUICK_REFERENCE.md)
3. ✓ Credentials ready!
```

### Step 3: Import Workflow
```bash
1. In N8N: Workflows → Add Workflow
2. Import from File → Select saq_email_alerts_workflow.json
3. Link credentials to nodes
4. Test workflow
5. Activate workflow
6. ✓ You're live!
```

**Total Setup Time:** ~30 minutes

---

## 📧 What This System Does

### Daily Operations:
- **Schedule:** Runs every weekday at 9:00 AM
- **Data Source:** Queries Supabase for inventory alerts
- **Recipients:** Sales representatives (from store_territory_mapping)
- **Email Content:** Beautiful HTML with all critical/warning alerts
- **Logging:** Tracks every email sent in database

### Alert Types:
- 🔴 **CRITICAL:** < 7 days of inventory OR rupture (0 stock)
- 🟡 **WARNING:** < 14 days of inventory

### Email Includes:
- Summary count (e.g., "3 Critical, 5 Warning")
- Detailed table with:
  - Product name, format, category
  - Store name, city, region
  - Current stock quantity
  - Average weekly sales
  - Days of inventory remaining
- Recommended action items
- Professional branding

---

## 🎯 Who Gets Emails?

Emails are automatically sent to sales representatives based on the `saq_store_territory_mapping.csv` file.

**Current Sales Reps:**
- Sophie Sabourin (sophie@cherryriver.ca) - Montreal territory
- Junior Rivas Torres (junior@cherryriver.ca) - North Shore territory
- Marie Tremblay (marie@cherryriver.ca) - Quebec territory

**To add more sales reps:**
1. Edit `mappings/saq_store_territory_mapping.csv`
2. Add row: `store_no,store_name,store_city,store_region,representative_name,representative_email`
3. Run `python processors/saq_processor_v2.py` to update Supabase
4. Next day, they'll start receiving emails automatically!

---

## 📊 How It Works (Technical Overview)

```
┌─────────────────────────────────────────┐
│ STEP 1: Schedule Trigger                │
│ Fires Mon-Fri at 9:00 AM                │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│ STEP 2: Query Supabase                  │
│ SELECT * FROM saq_store_inventory       │
│ WHERE is_critical = true                │
│    OR is_warning = true                 │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│ STEP 3: Group by Sales Rep              │
│ Groups alerts by representative_email   │
│ Counts critical vs warning              │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│ STEP 4: Build HTML Email                │
│ Creates beautiful email with table      │
│ Sorts by severity (critical first)      │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│ STEP 5: Send via Gmail                  │
│ Sends to each sales rep individually    │
└─────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│ STEP 6: Log to Database                 │
│ INSERT INTO email_logs                  │
│ Track delivery, counts, timestamps      │
└─────────────────────────────────────────┘
```

---

## ✅ Success Checklist

Use this to track your setup progress:

### Database Setup:
- [ ] Created `email_logs` table in Supabase
- [ ] Verified `saq_store_inventory` table has data
- [ ] Verified `saq_stores` has `representative_email` column populated

### N8N Setup:
- [ ] Created N8N Cloud account
- [ ] Set up Supabase PostgreSQL credential
- [ ] Tested Supabase connection successfully
- [ ] Set up Gmail OAuth2 credential
- [ ] Tested Gmail by sending test email
- [ ] Imported workflow JSON
- [ ] Linked credentials to all nodes
- [ ] Executed test workflow successfully

### Verification:
- [ ] Received test email in inbox
- [ ] Email has correct formatting and data
- [ ] `email_logs` table has new row
- [ ] No errors in N8N execution log

### Production:
- [ ] Activated workflow (toggle ON)
- [ ] Verified schedule is Mon-Fri 9:00 AM
- [ ] Notified sales reps to expect emails
- [ ] Set up monitoring/alerting

---

## 🔧 Customization Options

### Change Email Schedule:

Edit the "Schedule" node:
- Daily at 8 AM: `0 8 * * *`
- Every 4 hours: `0 */4 * * *`
- Only Mondays: `0 9 * * 1`
- Twice daily: `0 9,17 * * *`

### Change Alert Thresholds:

Edit SQL query in "Query Supabase" node:
```sql
-- Current: < 7 days critical, < 14 days warning
-- To change: Modify numbers in processor or add WHERE clause
WHERE days_of_inventory < 10  -- More aggressive
```

### Add CC Recipients:

In "Send Email via Gmail" node:
- Add parameter: **CC**
- Value: `francis@cherryriver.ca,operations@cherryriver.ca`

### Customize Email Design:

Edit the "Build HTML Email" node:
- Change colors (search for hex codes like `#7c3aed`)
- Modify text
- Add logo image
- Change layout

---

## 📞 Support & Troubleshooting

### Common Issues:

**Problem: No emails being sent**
- Check N8N workflow is activated (toggle ON)
- Check N8N execution logs for errors
- Verify Gmail credential is still connected
- Check if alerts exist in database

**Problem: Wrong data in emails**
- Verify `saq_store_inventory` table is up to date
- Run `python processors/saq_processor_v2.py` to refresh
- Check velocity calculation ran successfully

**Problem: Email going to spam**
- Add sender to address book
- Use company domain (@cherryriver.ca) instead of Gmail
- Set up SPF/DKIM records

**Problem: Workflow execution failed**
- Check N8N execution log for error details
- Verify all credentials are working
- Test each node individually
- Re-authenticate OAuth if expired

### Get Help:

1. **Check Logs:**
   - N8N: Executions tab → Click failed execution → See error
   - Supabase: Logs tab → Filter by table/operation

2. **Test Components:**
   - Test Supabase query in SQL Editor
   - Send test email from N8N Gmail node
   - Execute workflow manually (don't wait for schedule)

3. **Documentation:**
   - N8N Docs: https://docs.n8n.io
   - Supabase Docs: https://supabase.com/docs
   - This guide: `SETUP_GUIDE.md`

---

## 💰 Cost Breakdown

**Monthly Costs:**
- N8N Cloud: $20/month (or free self-hosted)
- Gmail: Free (or $6/user for Google Workspace)
- Supabase: $0 (Free tier includes 500MB DB, 2GB bandwidth)

**Total: $20-26/month**

**ROI:**
- Prevents lost sales from ruptures
- Reduces manual monitoring time
- Proactive alerts vs reactive fire-fighting
- Professional communication with sales reps

---

## 🎉 Next Steps

### After Setup:

1. **Monitor for 1 Week:**
   - Check emails are being sent
   - Verify data accuracy
   - Gather feedback from sales reps

2. **Optimize:**
   - Adjust alert thresholds if needed
   - Add more sales reps
   - Customize email content

3. **Expand:**
   - Add Slack notifications
   - Create Retool dashboard
   - Integrate with Odoo for PO automation

---

## 📝 For Francis (Client)

**Tell Francis:**

> "The email alert system is ready to deploy. Here's what I've built:
>
> **What It Does:**
> - Automatically checks inventory every weekday at 9 AM
> - Sends beautiful branded emails to sales reps with critical/warning alerts
> - Tracks all emails in database for auditing
> - Zero manual work once set up
>
> **What You Need:**
> - N8N account ($20/month) - https://n8n.io
> - Gmail account for sending (alerts@cherryriver.ca)
> - 30 minutes to follow setup guide
>
> **Files Included:**
> - Complete N8N workflow (import and activate)
> - Step-by-step setup guide with screenshots
> - SQL script for email logging
> - Email preview (open in browser to see design)
>
> **Benefits:**
> - Sales reps get proactive alerts instead of finding out from store managers
> - Prevents ruptures = prevents lost sales
> - Professional communication
> - Complete automation
>
> **Next Phase:**
> - Retool dashboards for visual monitoring
> - Odoo integration for PO automation
> - Mobile app for sales reps (future)
>
> I'm available to help with setup if you need assistance!"

---

## 📚 File Reference

| File | Purpose | When to Use |
|------|---------|-------------|
| `saq_email_alerts_workflow.json` | N8N workflow | Import into N8N |
| `SETUP_GUIDE.md` | Detailed instructions | Read first, follow step-by-step |
| `CREDENTIALS_QUICK_REFERENCE.md` | Credential setup | When setting up Supabase/Gmail |
| `email_logs_table.sql` | Database schema | Run in Supabase SQL Editor |
| `EMAIL_PREVIEW_EXAMPLE.html` | Email design preview | Open in browser to see |
| `README.md` | This file | Overview and quick start |

---

**Last Updated:** January 11, 2026
**Version:** 1.0
**Contact:** Cherry River Development Team

**Status:** ✅ READY FOR PRODUCTION

---

## 🔥 Let's Get This Live!

Follow the Quick Start section above, and you'll have automated alerts running within 30 minutes.

Questions? Check `SETUP_GUIDE.md` for detailed help!
