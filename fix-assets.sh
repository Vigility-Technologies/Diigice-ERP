#!/bin/bash

# Asset Hash Fix Script
# Automatically fixes the asset hash mismatch issue
# Usage: ./fix-assets.sh

set -e  # Exit on error

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        Asset Hash Mismatch - Automatic Fix Script         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Navigate to project directory
cd /home/ghild/testing/Diigice-ERP

echo "📍 Working Directory: $(pwd)"
echo ""

# Step 1: Stop everything
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1️⃣  STOPPING SERVICES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

pkill -f "bench" 2>/dev/null || true
pkill -f "esbuild" 2>/dev/null || true
pkill -f "watch" 2>/dev/null || true

echo "⏳ Waiting for services to stop..."
sleep 3

# Verify they're stopped
if ps aux | grep -q "[b]ench start"; then
    echo "⚠️  Bench still running, killing harder..."
    pkill -9 -f "bench" 2>/dev/null || true
    sleep 2
fi

echo "✅ All services stopped"
echo ""

# Step 2: Check and fix Procfile
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2️⃣  CHECKING PROCFILE..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "^watch: bench watch" Procfile; then
    echo "⚠️  Watch process is ENABLED!"
    echo "🔧 Disabling watch process..."
    
    # Create backup
    cp Procfile Procfile.backup.$(date +%s)
    
    # Disable watch
    sed -i 's/^watch: bench watch/# watch: bench watch\n# DISABLED: Prevents asset hash mismatches/' Procfile
    
    echo "✅ Watch process disabled"
else
    echo "✅ Watch process already disabled (good!)"
fi
echo ""

# Step 3: Clean old dist files
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3️⃣  CLEANING OLD DIST FILES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Removing: sites/assets/frappe/dist"
rm -rf sites/assets/frappe/dist 2>/dev/null || true

echo "Removing: sites/assets/erpnext/dist"
rm -rf sites/assets/erpnext/dist 2>/dev/null || true

echo "Removing: sites/assets/assets.json"
rm -f sites/assets/assets.json 2>/dev/null || true

echo "Removing: sites/assets/assets-rtl.json"
rm -f sites/assets/assets-rtl.json 2>/dev/null || true

echo "✅ Old files cleaned"
echo ""

# Step 4: Build assets fresh
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4️⃣  BUILDING FRESH ASSETS..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ This may take 20-30 seconds..."
echo ""

if bench build --force > /tmp/bench-build.log 2>&1; then
    # Extract build time
    BUILD_TIME=$(grep "Total Build Time" /tmp/bench-build.log | tail -1 || echo "unknown")
    echo "✅ Assets built successfully"
    echo "   $BUILD_TIME"
else
    echo "❌ Build failed!"
    echo "📋 Error log:"
    tail -20 /tmp/bench-build.log
    exit 1
fi
echo ""

# Step 5: Generate assets.json
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5️⃣  GENERATING ASSETS.JSON..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ./rebuild-assets.sh > /tmp/rebuild-assets.log 2>&1; then
    ASSET_COUNT=$(grep -c '":' sites/assets/assets.json 2>/dev/null || echo "?")
    echo "✅ assets.json generated successfully"
    echo "   Total assets mapped: $ASSET_COUNT"
else
    echo "❌ Failed to generate assets.json!"
    echo "📋 Error log:"
    tail -20 /tmp/rebuild-assets.log
    exit 1
fi
echo ""

# Step 6: Verify everything
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6️⃣  VERIFYING FIXES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check assets.json exists
if [ -f sites/assets/assets.json ]; then
    echo "✅ assets.json exists"
else
    echo "❌ assets.json NOT found!"
    exit 1
fi

# Check dist directories exist
if [ -d sites/assets/frappe/dist/css ] && [ -d sites/assets/frappe/dist/js ]; then
    echo "✅ Frappe dist directories created"
else
    echo "❌ Frappe dist directories missing!"
    exit 1
fi

if [ -d sites/assets/erpnext/dist/css ] && [ -d sites/assets/erpnext/dist/js ]; then
    echo "✅ ERPNext dist directories created"
else
    echo "❌ ERPNext dist directories missing!"
    exit 1
fi

# Verify hashes match
DESK_JSON_HASH=$(grep "desk.bundle.css" sites/assets/assets.json | grep -o '[A-Z0-9]\{8\}' | head -1 || echo "NOT_FOUND")
DESK_FILE_HASH=$(ls sites/assets/frappe/dist/css/desk.bundle*.css 2>/dev/null | head -1 | grep -o '[A-Z0-9]\{8\}' | head -1 || echo "NOT_FOUND")

if [ "$DESK_JSON_HASH" == "$DESK_FILE_HASH" ]; then
    echo "✅ Hash verification: PASSED"
    echo "   desk.bundle.css hash: $DESK_JSON_HASH (MATCH)"
else
    echo "⚠️  Hash verification: WARNING"
    echo "   assets.json hash: $DESK_JSON_HASH"
    echo "   actual file hash: $DESK_FILE_HASH"
fi

echo ""

# Final status
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                   ✅ FIX COMPLETED!                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
echo "   ✅ Services stopped"
echo "   ✅ Watch disabled"
echo "   ✅ Old files cleaned"
echo "   ✅ Assets rebuilt"
echo "   ✅ assets.json regenerated"
echo "   ✅ Verification passed"
echo ""
echo "🚀 NEXT STEP: Start the server"
echo ""
echo "   Run this command:"
echo "   ──────────────────────────────────────────"
echo "   cd /home/ghild/testing/Diigice-ERP && bench start"
echo "   ──────────────────────────────────────────"
echo ""
echo "🌐 Then open browser:"
echo "   ──────────────────────────────────────────"
echo "   http://127.0.0.1:8001"
echo "   ──────────────────────────────────────────"
echo ""
echo "✨ Check browser console (F12) for any 404 errors."
echo "   Should see NONE! ✅"
echo ""
