#!/bin/bash

# Asset Hash Mismatch Fix - Automated Script
# Usage: ./rebuild-assets.sh
# This script rebuilds assets and regenerates assets.json automatically

set -e  # Exit on any error

echo "╔════════════════════════════════════════════════════════╗"
echo "║       Asset Hash Mismatch - Complete Fix Script        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$PROJECT_ROOT/sites/assets"

echo -e "${BLUE}ℹ️  Project Root: $PROJECT_ROOT${NC}"
echo ""

# Step 1: Stop the server
echo -e "${YELLOW}🛑 Step 1: Stopping bench server...${NC}"
pkill -f "bench start" || echo "  (No bench process running)"
sleep 2
echo -e "${GREEN}✅ Bench stopped${NC}"
echo ""

# Step 2: Clean dist folders
echo -e "${YELLOW}🗑️  Step 2: Cleaning dist folders...${NC}"
rm -rf "$ASSETS_DIR/frappe/dist"
rm -rf "$ASSETS_DIR/erpnext/dist"
echo -e "${GREEN}✅ Dist folders cleaned${NC}"
echo ""

# Step 3: Build assets
echo -e "${YELLOW}🔨 Step 3: Building assets (this may take 1-2 minutes)...${NC}"
cd "$PROJECT_ROOT"
bench build --force
echo -e "${GREEN}✅ Assets built successfully${NC}"
echo ""

# Step 4: Generate assets.json
echo -e "${YELLOW}🔄 Step 4: Generating assets.json...${NC}"

python3 << 'PYTHON_END'
import os
import json
import sys

try:
    assets = {}
    
    # Get all frappe JS files
    frappe_js = os.path.join(os.environ.get('PROJECT_ROOT', '.'), 'sites/assets/frappe/dist/js')
    if os.path.exists(frappe_js):
        for f in os.listdir(frappe_js):
            if f.endswith('.js') and not f.endswith('.map'):
                name = f.replace('.js', '').rsplit('.', 1)[0] + '.js'
                assets[name] = f"/assets/frappe/dist/js/{f}"
    
    # Get all frappe CSS files
    frappe_css = os.path.join(os.environ.get('PROJECT_ROOT', '.'), 'sites/assets/frappe/dist/css')
    if os.path.exists(frappe_css):
        for f in os.listdir(frappe_css):
            if f.endswith('.css') and not f.endswith('.map') and '-rtl' not in f:
                name = f.replace('.css', '').rsplit('.', 1)[0] + '.css'
                assets[name] = f"/assets/frappe/dist/css/{f}"
    
    # Get all erpnext JS files
    erpnext_js = os.path.join(os.environ.get('PROJECT_ROOT', '.'), 'sites/assets/erpnext/dist/js')
    if os.path.exists(erpnext_js):
        for f in os.listdir(erpnext_js):
            if f.endswith('.js') and not f.endswith('.map'):
                name = f.replace('.js', '').rsplit('.', 1)[0] + '.js'
                assets[name] = f"/assets/erpnext/dist/js/{f}"
    
    # Get all erpnext CSS files
    erpnext_css = os.path.join(os.environ.get('PROJECT_ROOT', '.'), 'sites/assets/erpnext/dist/css')
    if os.path.exists(erpnext_css):
        for f in os.listdir(erpnext_css):
            if f.endswith('.css') and not f.endswith('.map') and '-rtl' not in f:
                name = f.replace('.css', '').rsplit('.', 1)[0] + '.css'
                assets[name] = f"/assets/erpnext/dist/css/{f}"
    
    # Write the JSON file
    assets_json_path = os.path.join(os.environ.get('PROJECT_ROOT', '.'), 'sites/assets/assets.json')
    with open(assets_json_path, 'w') as f:
        json.dump(assets, f, indent=4, sort_keys=True)
    
    print(f"Total assets mapped: {len(assets)}")
    sys.exit(0)
    
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
PYTHON_END

# Check if Python script succeeded
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ assets.json regenerated successfully${NC}"
else
    echo -e "${RED}❌ Failed to regenerate assets.json${NC}"
    exit 1
fi
echo ""

# Step 5: Verify the fix
echo -e "${YELLOW}🔍 Step 5: Verifying the fix...${NC}"

# Check if assets.json exists and has content
if [ -f "$ASSETS_DIR/assets.json" ]; then
    COUNT=$(grep -c "\"" "$ASSETS_DIR/assets.json" || echo "0")
    if [ "$COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ assets.json verified (contains asset mappings)${NC}"
    else
        echo -e "${RED}❌ assets.json is empty${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ assets.json file not found${NC}"
    exit 1
fi
echo ""

# Step 6: Ready to start
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All fixes applied successfully!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}🚀 Starting bench server...${NC}"
echo "   (You can now run: ${GREEN}bench start${NC})"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "   ✓ Server stopped"
echo "   ✓ Dist folders cleaned"
echo "   ✓ Assets rebuilt"
echo "   ✓ assets.json regenerated"
echo "   ✓ Ready to use!"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "   1. Run: ${GREEN}cd $PROJECT_ROOT && bench start${NC}"
echo "   2. Open browser: ${GREEN}http://127.0.0.1:8001${NC}"
echo "   3. Check browser console for any 404 errors"
echo ""
echo -e "${BLUE}If you still see 404s:${NC}"
echo "   - Hard refresh: Ctrl+F5 (or Cmd+Shift+R on Mac)"
echo "   - Clear browser cache"
echo "   - Check: ${GREEN}curl -I http://127.0.0.1:8001/assets/frappe/dist/css/desk.bundle*.css${NC}"
echo ""
