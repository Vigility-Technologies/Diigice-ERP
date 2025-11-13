# Technical Deep Dive: Asset Hash System

## 📌 Overview

The ERPNext/Frappe framework uses a **hash-based asset versioning system** to ensure:

1. Users always get the latest assets (cache busting)
2. Old files are cleaned up automatically
3. Browser caches are invalidated when content changes

---

## 🔧 How It Works

### 1. Build Process

When you run `bench build`, the esbuild compiler:

```
┌─────────────────────────────────────────────────────────────┐
│ bench build                                                  │
├─────────────────────────────────────────────────────────────┤
│ 1. Reads source files from:                                 │
│    - apps/frappe/frappe/public/js/                          │
│    - apps/frappe/frappe/public/scss/                        │
│    - apps/erpnext/erpnext/public/js/                        │
│    - apps/erpnext/erpnext/public/scss/                      │
│                                                              │
│ 2. Processes them through esbuild:                          │
│    - Minifies code                                          │
│    - Concatenates modules                                   │
│    - Generates sourcemaps                                   │
│                                                              │
│ 3. Generates UNIQUE HASH for each file:                     │
│    - Based on file content                                  │
│    - Example: "22CZNFEN"                                    │
│                                                              │
│ 4. Outputs to dist/ with hash in filename:                  │
│    - desk.bundle.6ZHVT5SU.js                                │
│    - website.bundle.22CZNFEN.css                            │
│    - erpnext.bundle.RZHWBP2I.css                            │
│                                                              │
│ 5. Updates assets.json mapping:                             │
│    {                                                         │
│      "desk.bundle.js": "/assets/.../desk.bundle.6ZHV.js"    │
│    }                                                         │
└─────────────────────────────────────────────────────────────┘
```

### 2. Asset Mapping (assets.json)

```json
{
  "desk.bundle.js": "/assets/frappe/dist/js/desk.bundle.6ZHVT5SU.js",
  //  ↑ Logical name          ↑ Actual file path with unique hash

  "website.bundle.css": "/assets/frappe/dist/css/website.bundle.22CZNFEN.css",
  "erpnext.bundle.css": "/assets/erpnext/dist/css/erpnext.bundle.RZHWBP2I.css"
}
```

### 3. Runtime Resolution

When the browser loads a page:

```
┌──────────────────────────────────────────────────────────┐
│ Page Load                                                │
├──────────────────────────────────────────────────────────┤
│ 1. HTML includes:                                        │
│    <link rel="stylesheet" href="/assets/desk.bundle.css" │
│                                                          │
│ 2. Server looks up in assets.json:                       │
│    desk.bundle.css → /assets/.../desk.bundle.6ZHVT.css  │
│                                                          │
│ 3. Server redirects browser to actual file:             │
│    /assets/frappe/dist/css/desk.bundle.6ZHVT5SU.css     │
│                                                          │
│ 4. Browser downloads the file                           │
│                                                          │
│ Result:                                                  │
│   ✅ If file exists → 200 OK                            │
│   ❌ If file doesn't exist → 404 NOT FOUND              │
└──────────────────────────────────────────────────────────┘
```

---

## ❌ When Things Go Wrong

### The Mismatch Scenario

```
Timeline:
─────────────────────────────────────────────────────────────────

T1: Build #1 (Old)
    Generates:  website.bundle.KPMH5STP.css
    Updates:    assets.json → website.bundle.css → KPMH5STP

T2: Build #2 (New) - Build interrupted or Redis unavailable
    Generates:  website.bundle.22CZNFEN.css
    BUT does NOT update assets.json!
    assets.json still says: website.bundle.css → KPMH5STP

T3: Server starts
    Browser requests: /assets/website.bundle.css
    assets.json points to: KPMH5STP (OLD)
    Actual file: 22CZNFEN (NEW)
    Result: ❌ 404 NOT FOUND!
```

### Root Causes

1. **Redis Connection Failed** during build

   ```
   WARN Cannot connect to redis_cache to update assets_json
   ```

2. **Build Process Interrupted** (Ctrl+C)

   ```
   Build started but didn't complete
   New files generated, assets.json not updated
   ```

3. **Git Operations** (merge, rebase)

   ```
   Old assets.json file from previous branch
   Conflicts with newly built files
   ```

4. **Manual File Manipulation**
   ```
   Deleted some dist files but not others
   Inconsistent state between dist/ and assets.json
   ```

---

## ✅ The Solution

### Understanding the Fix

The fix scans all actual files and regenerates the mapping:

```python
assets = {}

# Scan frappe/dist/js/
for file in os.listdir("sites/assets/frappe/dist/js/"):
    # file: "desk.bundle.6ZHVT5SU.js"
    # Extract name: "desk.bundle.js"
    # Extract hash: "6ZHVT5SU"
    # Create mapping: "desk.bundle.js" → "/assets/.../desk.bundle.6ZHVT5SU.js"
    assets["desk.bundle.js"] = f"/assets/frappe/dist/js/{file}"

# Same for CSS, erpnext, etc...

# Write corrected mapping
with open("sites/assets/assets.json", "w") as f:
    json.dump(assets, f)

# Result: assets.json now matches actual files! ✅
```

---

## 🔄 Hash Generation Details

### Why Hashes?

Hashes are deterministic based on **file content**:

```
Content: desk.bundle.js = "console.log('hello')"
Hash: MD5/SHA1 = "6ZHVT5SU"

If content changes:
Content: desk.bundle.js = "console.log('hello world')"  ← 1 byte changed
Hash: MD5/SHA1 = "B6FRELQE"  ← Completely different hash!
```

### Benefits

| Issue                                 | Solution                                  |
| ------------------------------------- | ----------------------------------------- |
| Browser caches old file               | New hash = new URL = browser re-downloads |
| Multiple versions of same app running | Each version has its own hashes           |
| Stale CDN caches                      | Hash in URL invalidates CDN cache         |
| Development vs Production             | Different builds = different hashes       |

### Example Timeline

```
Day 1: Deploy version 1
  desk.bundle.js → 6ZHVT5SU (browser caches this)
  HTML: <script src="/assets/desk.bundle.js"></script>

Day 2: Deploy version 2 (with bug fix)
  desk.bundle.js → B6FRELQE (different hash!)
  HTML: <script src="/assets/desk.bundle.js"></script>

What happens:
  URL stays same: /assets/desk.bundle.js
  But server maps it to: /assets/.../desk.bundle.B6FRELQE.js
  Browser sees new URL path → Downloads new version
  Old v1 cached at: /assets/.../desk.bundle.6ZHVT.js (unused, can be deleted)
```

---

## 📊 File Structure

```
sites/assets/
├── assets.json                          ← THE MAPPING FILE
├── frappe/
│   ├── dist/
│   │   ├── js/
│   │   │   ├── desk.bundle.6ZHVT5SU.js              ← Actual file 1
│   │   │   ├── desk.bundle.6ZHVT5SU.js.map         ← Sourcemap
│   │   │   ├── form.bundle.WPKBKO7Q.js              ← Actual file 2
│   │   │   └── ...more files...
│   │   ├── css/
│   │   │   ├── desk.bundle.ZNEBQ3KO.css             ← Actual CSS
│   │   │   ├── website.bundle.22CZNFEN.css          ← Actual CSS
│   │   │   └── ...more files...
│   │   └── css-rtl/                                 ← RTL variants
│   └── ...other assets...
└── erpnext/
    ├── dist/
    │   ├── js/
    │   ├── css/
    │   └── css-rtl/
    └── ...
```

### assets.json Content

```json
{
    "build_events.bundle.js": "/assets/frappe/dist/js/build_events.bundle.F47Z5BDW.js",
    "calendar.bundle.js": "/assets/frappe/dist/js/calendar.bundle.CUFNYKMX.js",
    "desk.bundle.css": "/assets/frappe/dist/css/desk.bundle.ZNEBQ3KO.css",
    "desk.bundle.js": "/assets/frappe/dist/js/desk.bundle.B6FRELQE.js",
    "email.bundle.css": "/assets/frappe/dist/css/email.bundle.I6B7VCC5.css",
    "erpnext.bundle.css": "/assets/erpnext/dist/css/erpnext.bundle.RCNMIB3I.css",
    ...more mappings...
}
```

---

## 🔍 Debugging Steps

### 1. Find Mismatch

```bash
# List actual files
ACTUAL=$(ls sites/assets/frappe/dist/css/ | grep "^desk" | head -1)
echo "Actual: $ACTUAL"

# Check what assets.json says
MAPPED=$(grep "desk.bundle.css" sites/assets/assets.json)
echo "Mapped: $MAPPED"

# Compare hashes
# If different → Problem found!
```

### 2. Verify Fix Works

```bash
# After running rebuild script, check mapping matches reality
python3 << 'EOF'
import os, json

with open("sites/assets/assets.json") as f:
    assets = json.load(f)

# Sample a few files
for name, path in list(assets.items())[:5]:
    filename = path.split("/")[-1]
    actual_path = f"sites/assets/{path.replace('/assets/', '')}"
    exists = os.path.exists(actual_path)
    status = "✅" if exists else "❌"
    print(f"{status} {name} → {filename}")
EOF
```

---

## 📈 Performance Impact

### Build Time

- Without rebuild: ~15-20 seconds
- With rebuild: +2-3 seconds (negligible)

### Memory

- assets.json size: ~2-5 KB
- Scanned files: ~40-50 assets
- Python memory: <1 MB

### Server Performance

- Lookup time: <1ms per request (dict lookup)
- No performance impact at runtime

---

## 🎓 Key Takeaways

1. **Hashes are Content-Based**: Change content → change hash
2. **Mapping Must Match Reality**: assets.json must point to files that actually exist
3. **Automation is Better**: Let script generate mapping, don't edit manually
4. **Cache Busting Works**: New hash = browser downloads new version
5. **Mismatch = 404s**: Old mapping + new files = 404 errors
6. **Quick Fix**: Scan dist/ and regenerate assets.json

---

## 🚀 Best Practices

### Do

✅ Run rebuild script after every build  
✅ Check for "DONE" message in build output  
✅ Verify redis is running before building  
✅ Use the automated script, not manual edits  
✅ Commit assets.json changes to git

### Don't

❌ Manually edit assets.json hashes  
❌ Delete dist files without updating mapping  
❌ Build when redis is down  
❌ Use old assets.json after checkout  
❌ Ignore 404 errors in browser console

---

**Last Updated**: November 12, 2025
**For**: Diigice-ERP Development Team
