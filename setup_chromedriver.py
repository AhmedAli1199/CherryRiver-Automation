"""
Helper script to download and setup ChromeDriver
"""

import os
import sys
import zipfile
import requests
from pathlib import Path
import subprocess
import json

def get_chrome_version():
    """Get the installed Chrome version on Windows"""
    try:
        # Try to get Chrome version from registry
        import winreg
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Google\Chrome\BLBeacon")
        version, _ = winreg.QueryValueEx(key, "version")
        winreg.CloseKey(key)
        return version
    except:
        try:
            # Alternative: Try command line
            result = subprocess.run(
                ['reg', 'query', 'HKEY_CURRENT_USER\\Software\\Google\\Chrome\\BLBeacon', '/v', 'version'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'version' in line:
                        version = line.split()[-1]
                        return version
        except:
            pass

    # Fallback: Try to get from Chrome executable
    chrome_paths = [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        os.path.expanduser(r"~\AppData\Local\Google\Chrome\Application\chrome.exe")
    ]

    for chrome_path in chrome_paths:
        if os.path.exists(chrome_path):
            try:
                result = subprocess.run(
                    [chrome_path, '--version'],
                    capture_output=True,
                    text=True
                )
                version = result.stdout.strip().split()[-1]
                return version
            except:
                pass

    return None

def get_chromedriver_url(chrome_version):
    """Get the appropriate ChromeDriver download URL for the Chrome version"""
    major_version = chrome_version.split('.')[0]

    print(f"Chrome major version: {major_version}")

    # For Chrome 115+, use the new Chrome for Testing downloads
    if int(major_version) >= 115:
        # Get the latest stable version for this major version
        try:
            url = f"https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
            response = requests.get(url, timeout=10)
            data = response.json()

            # Get the stable channel version
            stable_version = data['channels']['Stable']['version']
            downloads = data['channels']['Stable']['downloads']['chromedriver']

            # Find Windows 64-bit download
            for download in downloads:
                if download['platform'] == 'win64':
                    return download['url'], stable_version

            # Fallback to win32
            for download in downloads:
                if download['platform'] == 'win32':
                    return download['url'], stable_version

        except Exception as e:
            print(f"Error getting Chrome for Testing URL: {e}")

    # For older Chrome versions, use the old ChromeDriver repository
    try:
        # Get the closest ChromeDriver version
        url = f"https://chromedriver.storage.googleapis.com/LATEST_RELEASE_{major_version}"
        response = requests.get(url, timeout=10)
        driver_version = response.text.strip()

        download_url = f"https://chromedriver.storage.googleapis.com/{driver_version}/chromedriver_win32.zip"
        return download_url, driver_version
    except Exception as e:
        print(f"Error getting ChromeDriver URL: {e}")
        return None, None

def download_chromedriver(url, dest_dir):
    """Download and extract ChromeDriver"""
    print(f"Downloading ChromeDriver from: {url}")

    # Download
    response = requests.get(url, stream=True, timeout=30)
    zip_path = dest_dir / "chromedriver.zip"

    with open(zip_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    print(f"✓ Downloaded to: {zip_path}")

    # Extract
    print("Extracting...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(dest_dir)

    # Find the chromedriver.exe (it might be in a subdirectory)
    chromedriver_exe = None
    for root, dirs, files in os.walk(dest_dir):
        for file in files:
            if file == 'chromedriver.exe':
                chromedriver_exe = Path(root) / file
                break
        if chromedriver_exe:
            break

    if chromedriver_exe:
        # Move to root of dest_dir if it's in a subdirectory
        final_path = dest_dir / "chromedriver.exe"
        if chromedriver_exe != final_path:
            if final_path.exists():
                final_path.unlink()
            chromedriver_exe.rename(final_path)

        # Clean up zip and subdirectories
        zip_path.unlink()
        for item in dest_dir.iterdir():
            if item.is_dir() and item.name.startswith('chromedriver'):
                import shutil
                shutil.rmtree(item)

        print(f"✓ Extracted to: {final_path}")
        return final_path
    else:
        print("✗ Could not find chromedriver.exe in the archive")
        return None

def main():
    print("="*60)
    print("ChromeDriver Setup Helper")
    print("="*60)

    # Get Chrome version
    print("\nDetecting Chrome version...")
    chrome_version = get_chrome_version()

    if not chrome_version:
        print("✗ Could not detect Chrome version")
        print("\nPlease ensure Google Chrome is installed:")
        print("https://www.google.com/chrome/")
        return False

    print(f"✓ Found Chrome version: {chrome_version}")

    # Get ChromeDriver URL
    print("\nFinding matching ChromeDriver...")
    url, driver_version = get_chromedriver_url(chrome_version)

    if not url:
        print("✗ Could not find matching ChromeDriver")
        print(f"\nPlease download manually from:")
        print(f"https://chromedriver.chromium.org/downloads")
        return False

    print(f"✓ Found ChromeDriver version: {driver_version}")

    # Download to project directory
    dest_dir = Path(__file__).parent
    print(f"\nInstalling to: {dest_dir}")

    chromedriver_path = download_chromedriver(url, dest_dir)

    if chromedriver_path:
        print("\n" + "="*60)
        print("✓ SUCCESS!")
        print("="*60)
        print(f"\nChromeDriver installed at: {chromedriver_path}")
        print("\nYou can now run: python saq_data_scraper.py")
        return True
    else:
        print("\n" + "="*60)
        print("✗ Installation failed")
        print("="*60)
        return False

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
