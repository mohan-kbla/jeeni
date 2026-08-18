# bin/deploy/find_ruby.py
import os

paths_to_check = [
    "/home/mohan/.rbenv/shims",
    "/home/mohan/snap/antigravity/5/miniconda3/envs/ecom-env/bin",
    "/usr/bin",
    "/usr/local/bin"
]

for p in paths_to_check:
    print(f"\nChecking: {p}")
    if os.path.exists(p):
        try:
            files = os.listdir(p)
            for f in files:
                if "ruby" in f or "bundle" in f or "rails" in f:
                    print(f" - {f}")
        except Exception as e:
            print(f"Error listing {p}: {e}")
    else:
        print("Path does not exist")
