# SAQ B2B Data Scraper

## Overview
Automated Python script to download sales, inventory, and product data from the SAQ B2B portal.

## Features
- ✅ Headless browser automation with Selenium
- ✅ Automatic login and navigation
- ✅ Downloads all 10 data files:
  - Sales Summary (All Products)
  - Weekly Sales (Selected Products)
  - Inventories by Branch
  - Total Inventories (Warehouses)
  - Inventories Subtotal (Warehouse CSM)
  - Orders in Progress
  - Products and UPC
  - Other Related Data
  - My Products
  - Product Performance (SAQ Inspire)
- ✅ Automatic file renaming and organization
- ✅ Visual progress tracking
- ✅ Error handling and recovery

## Installation

### 1. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 2. Set Up Credentials (Optional)
You can either:
- **Option A**: Set environment variables
  ```bash
  set SAQ_USERNAME=your_username
  set SAQ_PASSWORD=your_password
  ```
- **Option B**: Enter credentials when prompted (default)

## Usage

### Run the Scraper
```bash
python saq_data_scraper.py
```

### With Visible Browser (Recommended for First Run)
When prompted "Run in headless mode? (y/N):", press **N** or just **Enter**
- You'll see the browser window
- You can watch the automation in real-time
- Useful for debugging

### Headless Mode (Background)
When prompted, enter **y**
- Runs in background
- Faster execution
- Good for scheduled/automated runs

## Output
All files are saved to:
```
SAQ Documents/
├── Sales_Summary_All_Products.csv
├── Weekly_Sales_Selected_Products.csv
├── Inventories_By_Branch.csv
├── Total_Inventories_Warehouses.csv
├── Inventories_Subtotal_Warehouse_CSM.csv
├── Orders_In_Progress.csv
├── Products_And_UPC.csv
├── Other_Related_Data.csv
├── My_Products.csv
└── Product_Performance_SAQ_Inspire.csv
```

## Example Output
```
############################################################
# SAQ B2B Data Scraper
# Started: 2025-12-29 14:30:00
############################################################
✓ Chrome driver initialized
✓ Downloads will be saved to: C:\Users\Zestro\Desktop\My Automations\CherryRiver\SAQ Documents

============================================================
STEP 1: Logging into SAQ B2B Portal
============================================================
✓ Navigated to: https://www.saq-b2b.com/
✓ Entered username: your_username
✓ Entered password: ************
✓ Clicked LOGIN button
✓ Login successful!

============================================================
STEP 2: Navigating to Business Information Page
============================================================
✓ Navigated to: https://www.saq-b2b.com/wxic/fr/Report.Selection$Prep
✓ Reports page loaded successfully

============================================================
STEP 3: Downloading Sales Summary (All Products)
============================================================
✓ Found link: Sales Summary - All Products (CSV)
✓ Clicked on Sales Summary link
✓ Found download link
✓ Clicked download link
      ⏳ Waiting for download to complete...
      ✓ Downloaded: Sales_Summary_All_Products.csv

============================================================
STEP 4: Downloading Raw Data Files
============================================================
✓ Found 11 total rows in raw data table

  [1/9] Weekly sales for selected products
      → Target: Weekly_Sales_Selected_Products.csv
      ✓ Download initiated
      ⏳ Waiting for download to complete...
      ✓ Downloaded: Weekly_Sales_Selected_Products.csv

  [2/9] Inventories by branch
      → Target: Inventories_By_Branch.csv
      ✓ Download initiated
      ⏳ Waiting for download to complete...
      ✓ Downloaded: Inventories_By_Branch.csv

... [continues for all files]

✓ Raw data downloads complete

############################################################
# ✓ SCRAPING COMPLETED SUCCESSFULLY
# Files saved to: C:\Users\Zestro\Desktop\My Automations\CherryRiver\SAQ Documents
# Finished: 2025-12-29 14:32:45
############################################################

Closing browser...
✓ Browser closed
```

## Scheduling Automated Runs

### Windows Task Scheduler
1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (e.g., daily at 6 AM)
4. Action: Start a program
5. Program: `python`
6. Arguments: `saq_data_scraper.py`
7. Start in: `C:\Users\Zestro\Desktop\My Automations\CherryRiver`

### Cron (Linux/Mac)
```bash
# Daily at 6 AM
0 6 * * * cd /path/to/CherryRiver && python saq_data_scraper.py
```

## Troubleshooting

### "Login failed! Please check credentials"
- Verify your SAQ B2B username and password
- Make sure you can log in manually first

### "Could not find Reports table"
- Check if SAQ portal structure changed
- Run in non-headless mode to see what's happening

### Download timeout
- Increase timeout in `_wait_for_download()` method
- Check your internet connection
- Verify files aren't blocked by antivirus

### Chrome driver issues
- The script auto-downloads the correct ChromeDriver
- If issues persist, update Chrome browser

## Next Steps

After downloading data, you can:
1. Process files with N8N workflow (to be created)
2. Upload to Relevance AI Knowledge Bases
3. Use AI agents for forecasting and analysis

## Support
For issues or questions, contact the development team.
