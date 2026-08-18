# bin/deploy/find_demerit.py
import os

def search_dir(path):
    print(f"Searching in {path}...")
    try:
        for root, dirs, files in os.walk(path):
            if "demerit_custom" in dirs:
                print(f"FOUND: {os.path.join(root, 'demerit_custom')}")
            # Don't go deep into .gemini or snap directories to avoid loop/permission issues
            if ".gemini" in root or ".cache" in root or ".local" in root or "snap" in root:
                continue
    except Exception as e:
        print(f"Error: {e}")

search_dir("/home/mohan")
