import time
from playwright.sync_api import sync_playwright
from pathlib import Path
import subprocess
import os
import sys

# --- CONFIGURATION ---
# The URL of your Gitea Service in Snowflake
SPCS_URL = "https://service-url.snowflakecomputing.app"

user_home = Path.home()
# 2. Construct the paths
# pathlib allows using the '/' operator to join paths on any OS
cookie_dir = user_home / ".cookies"

# 3. Create the directory if it doesn't exist
# parents=True: creates parent directories if needed
# exist_ok=True: does not raise an error if the directory already exists
cookie_dir.mkdir(parents=True, exist_ok=True)


OUTPUT_FILE = cookie_dir / "gitea_snowpark_cookie.txt"


#optional and not called unless uncommented
def set_git_global_cookie_file(filename):
    """
    Sets the git global http.cookieFile to the absolute path of the provided filename.
    Works on Windows, Mac, and Linux.
    """
    # 1. Get the absolute path to ensure Git can find the file 
    #    regardless of where you run the command from.
    #    (e.g., converts 'cookies.txt' -> 'C:\Users\You\Project\cookies.txt')
    abs_path = os.path.abspath(filename)
    
    # 2. Construct the command as a list (safer than string)
    #    Note: We use "--global". Change to "--local" if you only want it for the current repo.
    command = ["git", "config", "--global", "http.cookieFile", abs_path]

    print(f"Setting Git cookieFile to: {abs_path}")

    try:
        # 3. Run the command
        #    check=True raises an error if the command fails (non-zero exit code)
        subprocess.run(command, check=True, capture_output=True)
        print("✅ Success! Git is now configured to use these cookies.")
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: Git returned a failure status.\n{e.stderr.decode()}")
    except FileNotFoundError:
        print("❌ Error: 'git' command not found. Is Git installed and in your PATH?")

def convert_to_netscape_format(cookies):
    """
    Git requires cookies in the Netscape/Mozilla format:
    domain <tab> flag <tab> path <tab> secure <tab> expiration <tab> name <tab> value
    """
    lines = ["# Netscape HTTP Cookie File"]
    for cookie in cookies:
        domain = cookie['domain']
        # Netscape format requires a leading dot for domain matching in some tools,
        # but usually exact match works. Let's ensure standard format.
        flag = "TRUE" if domain.startswith('.') else "FALSE"
        path = cookie['path']
        secure = "TRUE" if cookie['secure'] else "FALSE"
        expires = str(int(cookie['expires'])) if 'expires' in cookie and cookie['expires'] > 0 else "0"
        name = cookie['name']
        value = cookie['value']
        
        line = f"{domain}\t{flag}\t{path}\t{secure}\t{expires}\t{name}\t{value}"
        lines.append(line)
    return "\n".join(lines)

def main():
    with sync_playwright() as p:
        # Launch browser in HEADFUL mode (headless=False) so you can see the UI
        browser = p.chromium.launch(headless=False)
        context = browser.new_context()
        page = context.new_page()

        print(f"Opening {SPCS_URL}...")
        page.goto(SPCS_URL)

        print("--- ACTION REQUIRED ---")
        print("1. The browser window is open.")
        print("2. Please log in to Snowflake and complete your 2FA.")
        print("3. Wait until you see the Gitea homepage.")
        
        # Determine when login is finished. 
        # We wait for the URL to NOT look like a login page, or for a specific element.
        # Simplest way: Wait for user to press Enter in the terminal.
        input("\n>>> PRESS ENTER HERE ONCE YOU ARE SUCCESSFULLY LOGGED IN <<<\n")

        # Capture cookies from the current context
        cookies = context.cookies()
        
        # Filter for relevant cookies (optional, but grabbing all for the domain is safest)
        # SPCS usually relies on a cookie named similar to 'osb-session' or '_snowflake'
        
        if not cookies:
            print("No cookies found! Did you log in?")
            browser.close()
            return

        # Write to file in Netscape format
        cookie_content = convert_to_netscape_format(cookies)
        
        with open(OUTPUT_FILE, "w") as f:
            f.write(cookie_content)

        print(f"SUCCESS: Cookies saved to {OUTPUT_FILE}")
        print("You can now run your git commands.")
        
        browser.close()
        #set_git_global_cookie_file(OUTPUT_FILE)

        #optionally, you can set these globally with a git command, but it's not recommended.
        #local configs will overwrite global configs, so you will need to unset if you set otherwise.


if __name__ == "__main__":
    main()