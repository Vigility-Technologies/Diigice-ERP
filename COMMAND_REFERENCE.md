# 🎯 Command Reference - Asset Hash Fix

**Last Updated**: November 12, 2025

---

## ⚡ THE FASTEST WAY (2 minutes)

If you just want to fix it RIGHT NOW without reading anything:

```bash
cd /home/ghild/vaibhav/Diigice-ERP
./rebuild-assets.sh
```

**That's it!** One command fixes everything. ✅

---

## 📋 MANUAL STEPS (if you want to understand what's happening)

If the automated script doesn't work or you want to do it manually:

### Step 1: Navigate to Project Root

```bash
cd /home/ghild/vaibhav/Diigice-ERP
```

### Step 2: Clean Old Asset Files

```bash
rm -rf sites/assets/frappe/dist
rm -rf sites/assets/erpnext/dist
```

### Step 3: Rebuild Assets

```bash
bench build --force
```

### Step 4: Regenerate Asset Mapping

```bash
python3 << 'EOF'
import os
import json

assets = {}

# Scan frappe CSS
frappe_css_path = "sites/assets/frappe/dist/css"
if os.path.exists(frappe_css_path):
    for file in os.listdir(frappe_css_path):
        if file.endswith('.css'):
            name = file.rsplit('.', 1)[0]
            assets[name] = f"/assets/frappe/dist/css/{file}"

# Scan frappe JS
frappe_js_path = "sites/assets/frappe/dist/js"
if os.path.exists(frappe_js_path):
    for file in os.listdir(frappe_js_path):
        if file.endswith('.js'):
            name = file.rsplit('.', 1)[0]
            assets[name] = f"/assets/frappe/dist/js/{file}"

# Scan erpnext CSS
erpnext_css_path = "sites/assets/erpnext/dist/css"
if os.path.exists(erpnext_css_path):
    for file in os.listdir(erpnext_css_path):
        if file.endswith('.css'):
            name = file.rsplit('.', 1)[0]
            assets[name] = f"/assets/erpnext/dist/css/{file}"

# Scan erpnext JS
erpnext_js_path = "sites/assets/erpnext/dist/js"
if os.path.exists(erpnext_js_path):
    for file in os.listdir(erpnext_js_path):
        if file.endswith('.js'):
            name = file.rsplit('.', 1)[0]
            assets[name] = f"/assets/erpnext/dist/js/{file}"

# Write to assets.json
with open("sites/assets/assets.json", "w") as f:
    json.dump(assets, f, indent=2)

print(f"✅ Created assets.json with {len(assets)} assets")
EOF
```

### Step 5: Restart the Server

```bash
bench start
```

---

## 🔍 VERIFICATION STEPS

After running the fix, verify it worked:

### Check 1: Verify assets.json exists

```bash
ls -lh sites/assets/assets.json
```

Expected output: Shows file size (should be a few KB)

### Check 2: Verify assets are in dist folders

```bash
ls -la sites/assets/frappe/dist/css/ | head -5
ls -la sites/assets/frappe/dist/js/ | head -5
```

Expected output: Shows CSS and JS files with hash names

### Check 3: Open browser and check logs

1. Open: `http://localhost:8000`
2. Press `F12` to open Developer Tools
3. Go to **Console** tab
4. Look for asset loading messages
5. **Verify**: All CSS/JS files show `200` status (not 404)

---

## 🛠️ TROUBLESHOOTING COMMANDS

### If rebuild script fails:

**Check Redis is running:**

```bash
redis-cli -p 13000 ping
redis-cli -p 13001 ping
```

Expected output: `PONG` for both

**Check bench status:**

```bash
bench status
```

**Clear cache and try again:**

```bash
rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist
bench clear-cache
bench build --force
```

**Check if Python can scan directories:**

```bash
python3 << 'EOF'
import os
print("Frappe CSS files:", os.listdir("sites/assets/frappe/dist/css") if os.path.exists("sites/assets/frappe/dist/css") else "NOT FOUND")
print("Frappe JS files:", os.listdir("sites/assets/frappe/dist/js") if os.path.exists("sites/assets/frappe/dist/js") else "NOT FOUND")
EOF
```

---

## 📊 QUICK COMMAND CHEAT SHEET

| Action                  | Command                                                     |
| ----------------------- | ----------------------------------------------------------- |
| **Fix everything**      | `./rebuild-assets.sh`                                       |
| **Just rebuild assets** | `bench build --force`                                       |
| **Clean old files**     | `rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist` |
| **Regenerate mapping**  | See "Manual Steps > Step 4" above                           |
| **Start server**        | `bench start`                                               |
| **Check Redis**         | `redis-cli -p 13000 ping`                                   |
| **Check bench status**  | `bench status`                                              |
| **View logs**           | `tail -f frappe.log`                                        |
| **Clear cache**         | `bench clear-cache`                                         |
| **List all assets**     | `cat sites/assets/assets.json`                              |

---

## 🚀 COMPLETE WORKFLOW

**First Time Fix (Complete Rebuild):**

```bash
cd /home/ghild/vaibhav/Diigice-ERP
rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist
bench build --force
# Run Step 4 python script from above
bench start
```

**Future Quick Fixes:**

```bash
cd /home/ghild/vaibhav/Diigice-ERP
./rebuild-assets.sh
# Done!
```

---

## 📍 COMMON ISSUES & SOLUTIONS

**Issue: "404 CSS/JS files not found"**

```bash
# Run the complete workflow above
```

**Issue: "Cannot connect to redis_cache"**

```bash
# Redis service isn't running - start it
redis-server /home/ghild/vaibhav/Diigice-ERP/config/redis_cache.conf
redis-server /home/ghild/vaibhav/Diigice-ERP/config/redis_queue.conf
```

**Issue: "assets.json corrupted or missing"**

```bash
# Delete it and regenerate
rm sites/assets/assets.json
# Then run Step 4 python script
```

**Issue: "Bench build hangs or fails"**

```bash
# Try with fresh clean
rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist
bench clear-cache
bench build --force
```

---

## 💡 PRO TIPS

1. **Always run from project root**: `cd /home/ghild/vaibhav/Diigice-ERP`
2. **Keep terminal open**: Don't close terminal while `bench start` is running
3. **Check logs**: If issues persist, check `frappe.log` and `database.log`
4. **Use rebuild script**: It's faster and handles edge cases automatically
5. **Team reference**: Share `ASSET_HASH_QUICK_FIX.md` with teammates

---

## 📞 NEED HELP?

Check these files in order:

1. `ASSET_HASH_QUICK_FIX.md` - Quick reference
2. `ASSET_HASH_FIX_GUIDE.md` - Step-by-step guide
3. `ASSET_HASH_TECHNICAL.md` - Deep technical explanation
4. `README_ASSETS.md` - Overview

All files are in: `/home/ghild/vaibhav/Diigice-ERP/`

---

**Last tested**: November 12, 2025 ✅
