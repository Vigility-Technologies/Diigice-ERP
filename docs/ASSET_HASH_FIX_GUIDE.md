# Asset Hash Mismatch Fix Guide

## Problem Overview

When running `bench start`, you get **404 errors** for CSS and JavaScript files in the browser console, even though the files exist in the dist folders:

```
GET /assets/frappe/dist/css/website.bundle.KPMH5STP.css HTTP/1.1" 404
GET /assets/erpnext/dist/js/erpnext.bundle.O4MMUXVO.js HTTP/1.1" 404
```

### Root Cause

The problem occurs because:

1. **Build Process**: When you run `bench build`, it compiles all CSS/JS files and generates **unique hash values** in the filenames:

   - Example: `website.bundle.22CZNFEN.css` (hash: `22CZNFEN`)

2. **Asset Mapping File**: The `sites/assets/assets.json` file maps logical asset names to their actual file paths with hashes:

   ```json
   {
     "website.bundle.css": "/assets/frappe/dist/css/website.bundle.22CZNFEN.css"
   }
   ```

3. **The Mismatch**: When `assets.json` contains **old/stale hash values** that don't match the actual built files, the browser tries to load assets that don't exist → **404 errors**

### Why This Happens

- The `assets.json` file is generated during the build process
- Sometimes this file doesn't get updated properly (Redis connection issues, build interruptions, etc.)
- Old hash values remain in the file even though new files were built with different hashes

---

## Solution Steps

### Step 1: Identify the Problem

Check the logs when accessing the app:

```bash
# Look for 404 errors in bench start output
curl http://127.0.0.1:8001
# Check if you see 404s for CSS/JS files
```

### Step 2: Check What Files Actually Exist

```bash
# List actual frappe CSS files
ls /home/ghild/vaibhav/Diigice-ERP/sites/assets/frappe/dist/css/ | grep -v map | grep -v rtl

# List actual frappe JS files
ls /home/ghild/vaibhav/Diigice-ERP/sites/assets/frappe/dist/js/ | grep -v map

# List actual erpnext CSS files
ls /home/ghild/vaibhav/Diigice-ERP/sites/assets/erpnext/dist/css/ | grep -v map | grep -v rtl

# List actual erpnext JS files
ls /home/ghild/vaibhav/Diigice-ERP/sites/assets/erpnext/dist/js/ | grep -v map
```

Example output:

```
website.bundle.22CZNFEN.css  ← This is the ACTUAL file
desk.bundle.6ZHVT5SU.css
report.bundle.27GACZ6X.css
```

### Step 3: Compare with assets.json

```bash
# Check what assets.json currently has
cat /home/ghild/vaibhav/Diigice-ERP/sites/assets/assets.json

# Look for mismatches:
# assets.json says: "website.bundle": "/assets/frappe/dist/css/website.bundle.KPMH5STP.css"
# But actual file is: website.bundle.22CZNFEN.css
# ❌ Hash mismatch: KPMH5STP vs 22CZNFEN
```

### Step 4: Regenerate assets.json Automatically

The **BEST solution** is to regenerate `assets.json` automatically from the actual files:

```bash
# Stop the server first
# Press Ctrl+C in the bench start terminal

# Run this Python script to generate correct assets.json
python3 << 'EOF'
import os
import json

assets = {}

# Get all frappe JS files
frappe_js = "/home/ghild/vaibhav/Diigice-ERP/sites/assets/frappe/dist/js"
for f in os.listdir(frappe_js):
    if f.endswith('.js') and not f.endswith('.map'):
        name = f.replace('.js', '').rsplit('.', 1)[0] + '.js'
        assets[name] = f"/assets/frappe/dist/js/{f}"

# Get all frappe CSS files
frappe_css = "/home/ghild/vaibhav/Diigice-ERP/sites/assets/frappe/dist/css"
for f in os.listdir(frappe_css):
    if f.endswith('.css') and not f.endswith('.map') and '-rtl' not in f:
        name = f.replace('.css', '').rsplit('.', 1)[0] + '.css'
        assets[name] = f"/assets/frappe/dist/css/{f}"

# Get all erpnext JS files
erpnext_js = "/home/ghild/vaibhav/Diigice-ERP/sites/assets/erpnext/dist/js"
for f in os.listdir(erpnext_js):
    if f.endswith('.js') and not f.endswith('.map'):
        name = f.replace('.js', '').rsplit('.', 1)[0] + '.js'
        assets[name] = f"/assets/erpnext/dist/js/{f}"

# Get all erpnext CSS files
erpnext_css = "/home/ghild/vaibhav/Diigice-ERP/sites/assets/erpnext/dist/css"
for f in os.listdir(erpnext_css):
    if f.endswith('.css') and not f.endswith('.map') and '-rtl' not in f:
        name = f.replace('.css', '').rsplit('.', 1)[0] + '.css'
        assets[name] = f"/assets/erpnext/dist/css/{f}"

# Write the JSON file
with open('/home/ghild/vaibhav/Diigice-ERP/sites/assets/assets.json', 'w') as f:
    json.dump(assets, f, indent=4, sort_keys=True)

print("✅ assets.json regenerated successfully!")
print(f"Total assets mapped: {len(assets)}")
EOF
```

### Step 5: Start the Server Again

```bash
cd /home/ghild/vaibhav/Diigice-ERP
bench start
```

### Step 6: Verify the Fix

Check the browser logs - you should see **200 responses** instead of 404:

```
GET /assets/frappe/dist/css/website.bundle.22CZNFEN.css HTTP/1.1" 200 ✅
GET /assets/erpnext/dist/css/erpnext.bundle.RZHWBP2I.css HTTP/1.1" 200 ✅
```

---

## Manual Fix (If Auto-Generation Fails)

If you prefer to manually fix it:

1. **Get one actual filename**:

   ```bash
   ls /home/ghild/vaibhav/Diigice-ERP/sites/assets/frappe/dist/css/ | head -1
   # Output: desk.bundle.6ZHVT5SU.css
   ```

2. **Extract the hash** from the filename:

   - Filename: `desk.bundle.6ZHVT5SU.css`
   - Hash: `6ZHVT5SU`

3. **Update assets.json manually**:

   ```bash
   # Open the file
   nano /home/ghild/vaibhav/Diigice-ERP/sites/assets/assets.json

   # Find and replace old hashes with new ones
   # Find:    "desk.bundle.css": "/assets/frappe/dist/css/desk.bundle.ZNEBQ3KO.css"
   # Replace: "desk.bundle.css": "/assets/frappe/dist/css/desk.bundle.6ZHVT5SU.css"
   ```

---

## Prevention Tips

To avoid this problem in the future:

### 1. **Always Rebuild After Code Changes**

```bash
bench stop
rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist
bench build --force
bench start
```

### 2. **Keep Redis Running**

The build process needs Redis to update `assets.json`. If Redis is not running:

```bash
# Make sure Redis is available before building
redis-cli ping  # Should return "PONG"
```

### 3. **Check Build Completion**

Always wait for the build to complete - watch for this message:

```
 DONE  Total Build Time: XX.XXXs
```

### 4. **Create a Helper Script**

Save this as `rebuild.sh` in your project root:

```bash
#!/bin/bash

echo "🛑 Stopping bench..."
pkill -f "bench start"
sleep 2

echo "🗑️  Cleaning dist folders..."
rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist

echo "🔨 Building assets..."
bench build --force

echo "🔄 Regenerating assets.json..."
python3 << 'EOF'
import os
import json

assets = {}
frappe_js = "sites/assets/frappe/dist/js"
for f in os.listdir(frappe_js):
    if f.endswith('.js') and not f.endswith('.map'):
        name = f.replace('.js', '').rsplit('.', 1)[0] + '.js'
        assets[name] = f"/assets/frappe/dist/js/{f}"

frappe_css = "sites/assets/frappe/dist/css"
for f in os.listdir(frappe_css):
    if f.endswith('.css') and not f.endswith('.map') and '-rtl' not in f:
        name = f.replace('.css', '').rsplit('.', 1)[0] + '.css'
        assets[name] = f"/assets/frappe/dist/css/{f}"

erpnext_js = "sites/assets/erpnext/dist/js"
for f in os.listdir(erpnext_js):
    if f.endswith('.js') and not f.endswith('.map'):
        name = f.replace('.js', '').rsplit('.', 1)[0] + '.js'
        assets[name] = f"/assets/erpnext/dist/js/{f}"

erpnext_css = "sites/assets/erpnext/dist/css"
for f in os.listdir(erpnext_css):
    if f.endswith('.css') and not f.endswith('.map') and '-rtl' not in f:
        name = f.replace('.css', '').rsplit('.', 1)[0] + '.css'
        assets[name] = f"/assets/erpnext/dist/css/{f}"

with open('sites/assets/assets.json', 'w') as f:
    json.dump(assets, f, indent=4, sort_keys=True)
print("✅ Done! Starting server...")
EOF

echo "🚀 Starting bench..."
bench start
```

Usage:

```bash
chmod +x rebuild.sh
./rebuild.sh
```

### 5. **Monitor for Issues**

```bash
# In a separate terminal, watch for 404s
while true; do
  sleep 5
  curl -s http://127.0.0.1:8001 2>&1 | grep -i "404\|error" && echo "⚠️  Error found!" || echo "✅ OK"
done
```

---

## Quick Reference Cheat Sheet

| Issue                  | Command                                                     |
| ---------------------- | ----------------------------------------------------------- |
| Check actual files     | `ls sites/assets/frappe/dist/css/ \| grep -v map`           |
| Regenerate assets.json | `python3 /tmp/generate_assets.py`                           |
| Stop server            | `Ctrl+C` or `pkill -f "bench start"`                        |
| Clear dist folders     | `rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist` |
| Rebuild                | `bench build --force`                                       |
| Start server           | `bench start`                                               |
| Check asset loads      | `curl http://127.0.0.1:8001`                                |
| View assets.json       | `cat sites/assets/assets.json`                              |

---

## Understanding assets.json Structure

```json
{
  "website.bundle.css": "/assets/frappe/dist/css/website.bundle.22CZNFEN.css",
  //  ↑ Logical name (used by app)     ↑ Actual file path with hash

  "desk.bundle.js": "/assets/frappe/dist/js/desk.bundle.B6FRELQE.js",
  "erpnext.bundle.css": "/assets/erpnext/dist/css/erpnext.bundle.RZHWBP2I.css"
}
```

**The hash** (e.g., `22CZNFEN`) ensures browser caches are invalidated when files change - if the hash changes, the browser knows to download the new version instead of using the old cached version.

---

## Troubleshooting

| Problem                     | Solution                                           |
| --------------------------- | -------------------------------------------------- |
| Still getting 404 after fix | Ctrl+F5 hard refresh in browser, clear cache       |
| assets.json keeps reverting | Stop Redis, run auto-generation script, restart    |
| Build fails                 | Check: `bench setup requirements` first            |
| Files not in dist folder    | Build didn't complete - check for errors in output |

---

## When to Use This Guide

✅ Use this guide when you see:

- CSS/JS files returning 404 in browser console
- Styling breaks or disappears
- JavaScript bundles not loading
- After running `bench build` or switching branches
- After Git operations that change files

---

**Last Updated**: November 12, 2025  
**Created by**: Diigice-ERP Development Team
