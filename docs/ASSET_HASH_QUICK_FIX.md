# Quick Reference: Asset Hash Mismatch Fix

## 🔴 Problem Recognition

You see **404 errors** in browser console:

```
GET /assets/frappe/dist/css/website.bundle.XXXXX.css HTTP/1.1" 404
GET /assets/erpnext/dist/js/erpnext.bundle.YYYYY.js HTTP/1.1" 404
```

CSS is broken or JavaScript not loading? → This is your issue!

---

## ⚡ Quick Fix (30 seconds)

### Option 1: Using the Auto Script (EASIEST)

```bash
cd /home/ghild/vaibhav/Diigice-ERP
./rebuild-assets.sh
# This does everything automatically!
```

### Option 2: Manual Quick Fix

```bash
# 1. Stop server
Ctrl+C

# 2. Run this one command
python3 << 'EOF'
import os, json
assets = {}
for root, dirs, files in os.walk('sites/assets'):
    for f in files:
        if f.endswith(('.js', '.css')) and not f.endswith('.map') and '-rtl' not in f:
            name = f.rsplit('.', 1)[0] + '.' + f.rsplit('.', 1)[1]
            assets[name] = f'/assets/{os.path.relpath(os.path.join(root, f), "sites/assets")}'
with open('sites/assets/assets.json', 'w') as f:
    json.dump(assets, f, indent=4, sort_keys=True)
print("✅ Done!")
EOF

# 3. Start server
bench start
```

---

## 📋 Step-by-Step Manual Fix

### Step 1: Check What's Actually There

```bash
ls sites/assets/frappe/dist/css/ | grep -v map | head -5
# Output example:
# desk.bundle.6ZHVT5SU.css    ← Note the hash!
# report.bundle.27GACZ6X.css
```

### Step 2: Verify assets.json is Wrong

```bash
grep "desk.bundle" sites/assets/assets.json
# If hash doesn't match ↑ above, it's wrong!
```

### Step 3: Regenerate It

```bash
# Remove old one
rm sites/assets/assets.json

# Run rebuild script OR manual Python script above
./rebuild-assets.sh
```

### Step 4: Start and Test

```bash
bench start
# Open: http://127.0.0.1:8001
# Check browser console → No 404s? ✅ Fixed!
```

---

## 🛠️ Common Commands

| What                         | Command                                                                 |
| ---------------------------- | ----------------------------------------------------------------------- |
| **List actual CSS files**    | `ls sites/assets/frappe/dist/css/`                                      |
| **List actual JS files**     | `ls sites/assets/frappe/dist/js/`                                       |
| **View current assets.json** | `cat sites/assets/assets.json \| head -20`                              |
| **Run auto-fix**             | `./rebuild-assets.sh`                                                   |
| **Stop server**              | `Ctrl+C` or `pkill -f "bench start"`                                    |
| **Start server**             | `bench start`                                                           |
| **Hard refresh browser**     | `Ctrl+F5`                                                               |
| **Check file exists**        | `curl -I http://127.0.0.1:8001/assets/frappe/dist/css/desk.bundle*.css` |

---

## ⚠️ If It Still Doesn't Work

### 1. Hard Refresh Browser

- Windows/Linux: `Ctrl+F5`
- Mac: `Cmd+Shift+R`
- Clear entire browser cache

### 2. Verify Server is Serving Files

```bash
curl -v http://127.0.0.1:8001/assets/frappe/dist/css/desk.bundle.6ZHVT5SU.css
# Should return 200, not 404
```

### 3. Check File Permissions

```bash
chmod 755 sites/assets/frappe/dist/css/
chmod 644 sites/assets/frappe/dist/css/*.css
```

### 4. Nuclear Option

```bash
bench stop
rm -rf sites/assets/frappe/dist sites/assets/erpnext/dist
rm sites/assets/assets.json
bench build --force
# Wait for "DONE  Total Build Time"
./rebuild-assets.sh
bench start
```

---

## 🎯 What's Happening

```
Browser requests:     assets.json says:              But file is actually:
────────────────      ─────────────────              ──────────────────────
desk.bundle.css   →   desk.bundle.ZNEBQ3KO.css  →  desk.bundle.6ZHVT5SU.css
                      ✅ CORRECT                    ❌ WRONG HASH
                      File exists                   File doesn't exist → 404!
```

After fix:

```
desk.bundle.css   →   desk.bundle.6ZHVT5SU.css  →  desk.bundle.6ZHVT5SU.css
                      ✅ CORRECT                    ✅ MATCHES → 200 OK!
```

---

## 🔐 Prevention

Add this to your development workflow:

1. **After Git Pull/Merge**:

   ```bash
   ./rebuild-assets.sh
   ```

2. **After Switching Branches**:

   ```bash
   ./rebuild-assets.sh
   ```

3. **After Any CSS/JS Changes**:

   ```bash
   bench build --force && ./rebuild-assets.sh
   ```

4. **If Build Seems Stuck**:
   - Wait at least 2 minutes
   - Look for: `DONE  Total Build Time: XX.XXs`
   - If no message, check Redis is running: `redis-cli ping`

---

## 📚 More Details

For complete documentation, see: `ASSET_HASH_FIX_GUIDE.md`

For troubleshooting advanced issues: Read the full guide

---

**Last Updated**: November 12, 2025
**For**: Diigice-ERP Development Team
