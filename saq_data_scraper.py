"""
SAQ B2B Data Scraper
Automates the download of sales, inventory, and product data from SAQ B2B portal
"""

import os
import time
from datetime import datetime
from pathlib import Path
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options

# Configuration
SAQ_LOGIN_URL = "https://www.saq-b2b.com/"
SAQ_REPORTS_URL = "https://www.saq-b2b.com/wxic/fr/Report.Selection$Prep"

# Get credentials from environment variables or prompt
USERNAME = os.getenv("SAQ_USERNAME", "")  # Set environment variable or update here
PASSWORD = os.getenv("SAQ_PASSWORD", "")  # Set environment variable or update here

# Download directory
DOWNLOAD_DIR = Path(__file__).parent / "SAQ Documents 2"
DOWNLOAD_DIR.mkdir(exist_ok=True)

# File mapping - Maps table row index to filename
FILE_MAPPING = {
    3: "Weekly_Sales_Selected_Products",
    4: "Inventories_By_Branch",
    5: "Total_Inventories_Warehouses",
    6: "Inventories_Subtotal_Warehouse_CSM",
    7: "Orders_In_Progress",
    8: "Products_And_UPC",
    9: "Other_Related_Data",
    10: "My_Products",
    11: "Product_Performance_SAQ_Inspire"
}


class SAQScraper:
    def __init__(self, username, password, download_dir, headless=False):
        self.username = username
        self.password = password
        self.download_dir = str(download_dir.absolute())
        self.headless = headless
        self.driver = None
        self.wait = None

    def setup_driver(self):
        """Initialize Chrome WebDriver with download preferences"""
        chrome_options = Options()

        if self.headless:
            chrome_options.add_argument("--headless=new")

        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--window-size=1920,1080")

        # Additional stability options
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)

        # Set download preferences
        prefs = {
            "download.default_directory": self.download_dir,
            "download.prompt_for_download": False,
            "download.directory_upgrade": True,
            "safebrowsing.enabled": True
        }
        chrome_options.add_experimental_option("prefs", prefs)

        # Try to initialize driver with better error handling
        driver_initialized = False

        # Method 1: Check for chromedriver.exe in project directory
        project_dir = Path(__file__).parent
        local_chromedriver = project_dir / "chromedriver.exe"

        if local_chromedriver.exists():
            try:
                print(f"Found local chromedriver at: {local_chromedriver}")
                service = Service(str(local_chromedriver))
                self.driver = webdriver.Chrome(service=service, options=chrome_options)
                self.wait = WebDriverWait(self.driver, 20)
                print(f"✓ Chrome driver initialized (using local chromedriver.exe)")
                print(f"✓ Downloads will be saved to: {self.download_dir}")
                driver_initialized = True
            except Exception as e:
                print(f"⚠ Local chromedriver failed: {str(e)[:100]}")

        # Method 2: Try to find chromedriver in PATH
        if not driver_initialized:
            try:
                from shutil import which
                chromedriver_path = which("chromedriver")

                if chromedriver_path:
                    print(f"Found chromedriver in PATH: {chromedriver_path}")
                    service = Service(chromedriver_path)
                    self.driver = webdriver.Chrome(service=service, options=chrome_options)
                    self.wait = WebDriverWait(self.driver, 20)
                    print(f"✓ Chrome driver initialized (using PATH chromedriver)")
                    print(f"✓ Downloads will be saved to: {self.download_dir}")
                    driver_initialized = True
            except Exception as e:
                print(f"⚠ PATH chromedriver failed: {str(e)[:100]}")

        # Method 3: Try with system Chrome (Selenium 4.6+ auto-downloads driver)
        if not driver_initialized:
            try:
                print("Attempting to use system Chrome with auto-driver...")
                self.driver = webdriver.Chrome(options=chrome_options)
                self.wait = WebDriverWait(self.driver, 20)
                print(f"✓ Chrome driver initialized (auto-downloaded)")
                print(f"✓ Downloads will be saved to: {self.download_dir}")
                driver_initialized = True
            except Exception as e:
                print(f"⚠ Auto-driver failed: {str(e)[:100]}")

        # If all methods failed, provide instructions
        if not driver_initialized:
            print("\n" + "="*60)
            print("CHROMEDRIVER SETUP REQUIRED")
            print("="*60)
            print("\nRun the setup helper script:")
            print("  python setup_chromedriver.py")
            print("\nOr download manually:")
            print("1. Go to: https://chromedriver.chromium.org/downloads")
            print("2. Download version matching your Chrome (check chrome://version)")
            print("3. Extract chromedriver.exe to this folder:")
            print(f"   {project_dir}")
            print("="*60 + "\n")
            raise Exception("Could not initialize ChromeDriver. Run setup_chromedriver.py")

    def login(self):
        """Log into SAQ B2B portal"""
        print(f"\n{'='*60}")
        print("STEP 1: Logging into SAQ B2B Portal")
        print(f"{'='*60}")

        self.driver.get(SAQ_LOGIN_URL)
        print(f"✓ Navigated to: {SAQ_LOGIN_URL}")

        # Wait for login form to load
        username_field = self.wait.until(
            EC.presence_of_element_located((By.NAME, "Session_Username"))
        )
        password_field = self.driver.find_element(By.NAME, "Session_Password")

        # Enter credentials
        username_field.clear()
        username_field.send_keys(self.username)
        print(f"✓ Entered username: {self.username}")

        password_field.clear()
        password_field.send_keys(self.password)
        print(f"✓ Entered password: {'*' * len(self.password)}")

        # Submit the form (multiple methods to ensure it works)
        try:
            # Method 1: Submit via JavaScript (most reliable)
            self.driver.execute_script("document.forms.LoginForm.submit();")
            print(f"✓ Submitted login form (via JavaScript)")
        except:
            try:
                # Method 2: Find and click the login button
                login_button = self.driver.find_element(
                    By.XPATH,
                    "//input[@type='submit' and @value='LOGIN']"
                )
                login_button.click()
                print(f"✓ Clicked LOGIN button")
            except:
                # Method 3: Press Enter on password field
                from selenium.webdriver.common.keys import Keys
                password_field.send_keys(Keys.RETURN)
                print(f"✓ Submitted via Enter key")

        # Wait for successful login (check for page change)
        time.sleep(3)

        if "session.access.login" in self.driver.current_url.lower():
            raise Exception("Login failed! Please check credentials.")

        print(f"✓ Login successful!")

    def navigate_to_reports(self):
        """Navigate to Business Information / Reports page"""
        print(f"\n{'='*60}")
        print("STEP 2: Navigating to Business Information Page")
        print(f"{'='*60}")

        self.driver.get(SAQ_REPORTS_URL)
        print(f"✓ Navigated to: {SAQ_REPORTS_URL}")

        # Wait for reports table to load
        self.wait.until(
            EC.presence_of_element_located((By.CLASS_NAME, "reportsTable"))
        )
        print(f"✓ Reports page loaded successfully")
        time.sleep(2)

    def download_sales_summary(self):
        """Download the Sales Summary - All Products CSV"""
        print(f"\n{'='*60}")
        print("STEP 3: Downloading Sales Summary (All Products)")
        print(f"{'='*60}")

        try:
            # Find all tables with class 'reportsTable'
            tables = self.driver.find_elements(By.CLASS_NAME, "reportsTable")

            if len(tables) < 1:
                print("✗ Could not find Reports table")
                return False

            # First table contains the Sales Summary link
            first_table = tables[0]

            # Find the link in 3rd tr, 1st td
            summary_link = first_table.find_element(
                By.XPATH,
                ".//tr[3]/td[1]/a"
            )

            link_text = summary_link.text
            print(f"✓ Found link: {link_text}")

            # Click the link to go to intermediate page
            summary_link.click()
            print(f"✓ Clicked on Sales Summary link")
            time.sleep(3)

            # Now we're on the intermediate page
            # Navigate to the table: /html/body/div[1]/div[5]/div/div/table/tbody/tr/td[2]/form/table[1]
            # Then get 3rd tr, 3rd td anchor tag

            download_table = self.wait.until(
                EC.presence_of_element_located(
                    (By.XPATH, "/html/body/div[1]/div[5]/div/div/table/tbody/tr/td[2]/form/table[1]")
                )
            )

            download_link = download_table.find_element(
                By.XPATH,
                ".//tr[3]/td[3]/a"
            )

            print(f"✓ Found download link")

            # Get current file count before download
            files_before = set(os.listdir(self.download_dir))

            download_link.click()
            print(f"✓ Clicked download link")

            # Wait for download
            time.sleep(5)

            print(f"✓ Sales Summary download complete")

            # Navigate back to reports page
            print(f"Navigating back to reports page...")
            self.driver.get(SAQ_REPORTS_URL)
            time.sleep(3)

            # Wait for the reports table to load again
            self.wait.until(
                EC.presence_of_element_located((By.CLASS_NAME, "reportsTable"))
            )
            print(f"✓ Back at reports page")

            return True

        except Exception as e:
            print(f"✗ Error downloading Sales Summary: {str(e)}")
            # Try to navigate back anyway
            try:
                self.driver.get(SAQ_REPORTS_URL)
                time.sleep(3)
            except:
                pass
            return False

    def download_raw_data_files(self):
        """Download all files from the 'Downloading raw data' table"""
        print(f"\n{'='*60}")
        print("STEP 4: Downloading Raw Data Files")
        print(f"{'='*60}")

        try:
            # SPECIAL HANDLING FOR ROW 3 (Weekly Sales - goes to intermediate page like Sales Summary)
            print(f"\n  [1/6] Weekly Sales for Selected Products")
            print(f"      (Special handling - intermediate page)")

            # Get row 3 (table row index 4) from the second table
            tables = self.driver.find_elements(By.CLASS_NAME, "reportsTable")
            if len(tables) < 2:
                print("✗ Could not find Raw Data table")
                return False

            raw_data_table = tables[1]
            # Row 3 data is in tr[4] (tr[1]=header, tr[2]=subheader, tr[3]=header row, tr[4]=first data row)
            row_3 = raw_data_table.find_element(By.XPATH, ".//tr[4]")

            # Click the link in row 3 to go to intermediate page
            weekly_sales_link = row_3.find_element(By.XPATH, "./td[3]/a")
            weekly_sales_link.click()
            print(f"      ✓ Navigated to intermediate page")
            time.sleep(3)

            # Get the download link from the intermediate page
            # Table: /html/body/div[1]/div[5]/div/div/table/tbody/tr/td[2]/form/table[1]
            # Link in: 3rd tr, 3rd td
            download_table = self.wait.until(
                EC.presence_of_element_located(
                    (By.XPATH, "/html/body/div[1]/div[5]/div/div/table/tbody/tr/td[2]/form/table[1]")
                )
            )

            download_link = download_table.find_element(By.XPATH, ".//tr[3]/td[3]/a")
            print(f"      ✓ Found download link")

            # Get current files before download
            files_before = set(os.listdir(self.download_dir))

            download_link.click()
            print(f"      ✓ Download initiated")

            # Wait for download
            time.sleep(5)

            print(f"      ✓ Weekly Sales download complete")

            # Navigate back to reports page
            print(f"      Navigating back to reports page...")
            self.driver.get(SAQ_REPORTS_URL)
            time.sleep(3)

            # Wait for the reports table to load again
            self.wait.until(
                EC.presence_of_element_located((By.CLASS_NAME, "reportsTable"))
            )
            print(f"      ✓ Back at reports page")

            # REGULAR HANDLING FOR ROWS 4-8 (Direct downloads)
            print(f"\n  Downloading remaining files (rows 4-8, direct downloads)...")

            # Rows 4-8 correspond to table row indices 5-9
            for row_index in range(4, 9):  # 4, 5, 6, 7, 8
                try:
                    # Re-fetch the table to avoid stale element
                    tables = self.driver.find_elements(By.CLASS_NAME, "reportsTable")
                    raw_data_table = tables[1]

                    # Row index 4 = table tr[5], row index 5 = table tr[6], etc.
                    row = raw_data_table.find_element(By.XPATH, f".//tr[{row_index + 1}]")

                    # Get file description from first column
                    description = row.find_element(By.XPATH, "./td[1]").text

                    # Get download link from third column
                    download_link = row.find_element(By.XPATH, "./td[3]/a")

                    print(f"\n  [{row_index - 2}/6] {description}")

                    # Get current file count before download
                    files_before = set(os.listdir(self.download_dir))

                    # Click download
                    download_link.click()
                    print(f"      ✓ Download initiated")

                    # Wait for download
                    time.sleep(3)

                except Exception as e:
                    print(f"      ✗ Error: {str(e)}")
                    continue

            print(f"\n✓ All raw data downloads complete")
            return True

        except Exception as e:
            print(f"✗ Error downloading raw data files: {str(e)}")
            import traceback
            traceback.print_exc()
            return False

    def _wait_for_download(self, files_before, expected_filename, timeout=60):
        """Wait for a file to finish downloading

        Args:
            files_before: Set of files before download
            expected_filename: If None, keeps original filename. Otherwise renames to this.
            timeout: Seconds to wait for download
        """
        print(f"      ⏳ Waiting for download to complete...")

        # Ensure download_dir is a Path object
        download_dir = Path(self.download_dir)

        start_time = time.time()
        while time.time() - start_time < timeout:
            files_after = set(os.listdir(download_dir))
            new_files = files_after - files_before

            # Check if any new files (excluding .crdownload or .tmp)
            completed_files = [f for f in new_files if not f.endswith(('.crdownload', '.tmp'))]

            if completed_files:
                downloaded_file = completed_files[0]
                print(f"      ✓ Downloaded: {downloaded_file}")

                # Only rename if expected_filename is provided
                if expected_filename and downloaded_file != expected_filename:
                    old_path = download_dir / downloaded_file
                    new_path = download_dir / expected_filename

                    # If target exists, add timestamp
                    if new_path.exists():
                        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                        base = expected_filename.rsplit('.', 1)[0]
                        ext = expected_filename.rsplit('.', 1)[1] if '.' in expected_filename else ''
                        expected_filename = f"{base}_{timestamp}.{ext}"
                        new_path = download_dir / expected_filename

                    try:
                        os.rename(old_path, new_path)
                        print(f"      ✓ Renamed to: {expected_filename}")
                    except Exception as e:
                        print(f"      ⚠ Could not rename: {str(e)}")

                return True

            time.sleep(1)

        print(f"      ✗ Download timeout after {timeout} seconds")
        return False

    def run(self):
        """Main execution flow"""
        try:
            print(f"\n{'#'*60}")
            print(f"# SAQ B2B Data Scraper")
            print(f"# Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'#'*60}")

            self.setup_driver()
            self.login()
            self.navigate_to_reports()
            self.download_sales_summary()
            self.download_raw_data_files()

            print(f"\n{'#'*60}")
            print(f"# ✓ SCRAPING COMPLETED SUCCESSFULLY")
            print(f"# Files saved to: {self.download_dir}")
            print(f"# Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'#'*60}\n")

        except Exception as e:
            print(f"\n{'#'*60}")
            print(f"# ✗ ERROR: {str(e)}")
            print(f"{'#'*60}\n")
            raise

        finally:
            if self.driver:
                print(f"Closing browser...")
                time.sleep(3)  # Give time to see final state
                self.driver.quit()
                print(f"✓ Browser closed\n")


def main():
    """Entry point"""
    # Prompt for credentials if not in environment
    username = USERNAME or input("Enter SAQ B2B Username: ")
    password = PASSWORD or input("Enter SAQ B2B Password: ")

    if not username or not password:
        print("Error: Username and password are required!")
        return

    # Ask if headless mode
    headless_input = input("Run in headless mode? (y/N): ").strip().lower()
    headless = headless_input == 'y'

    # Create scraper instance
    scraper = SAQScraper(
        username=username,
        password=password,
        download_dir=DOWNLOAD_DIR,
        headless=headless
    )

    # Run the scraper
    scraper.run()


if __name__ == "__main__":
    main()
