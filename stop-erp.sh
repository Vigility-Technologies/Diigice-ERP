#!/bin/bash

# Diigice-ERP Stop Script
# This script stops Bench gracefully and verifies cleanup

echo "╔════════════════════════════════════════════════════════╗"
echo "║     Diigice-ERP - Stop & Cleanup                       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PORTS=(8001 13001 11001)

# Step 1: Graceful stop
echo -e "${YELLOW}1️⃣  Stopping Bench gracefully...${NC}"
if pgrep -f "bench" > /dev/null; then
    pkill -TERM -f "bench start" 2>/dev/null || true
    echo -e "${YELLOW}   Waiting for graceful shutdown (3 seconds)...${NC}"
    sleep 3
else
    echo -e "${GREEN}   Bench is not running${NC}"
fi
echo ""

# Step 2: Force stop if still running
echo -e "${YELLOW}2️⃣  Force stopping any remaining processes...${NC}"
if pgrep -f "bench" > /dev/null; then
    echo -e "${YELLOW}⚠️  Bench still running, force stopping...${NC}"
    pkill -9 -f "bench" 2>/dev/null || true
    sleep 1
fi

# Also stop redis explicitly
if pgrep redis-server > /dev/null; then
    echo -e "${YELLOW}Stopping Redis...${NC}"
    pkill -9 redis-server 2>/dev/null || true
    sleep 1
fi
echo -e "${GREEN}✅ Processes stopped${NC}"
echo ""

# Step 3: Verify ports are free
echo -e "${YELLOW}3️⃣  Verifying ports are free...${NC}"
for PORT in "${PORTS[@]}"; do
    if lsof -i :$PORT >/dev/null 2>&1; then
        echo -e "${RED}   ❌ Port $PORT still IN USE${NC}"
        # Try to force free it
        PIDS=$(lsof -t -i :$PORT 2>/dev/null || true)
        for PID in $PIDS; do
            echo -e "${YELLOW}      Force killing PID $PID${NC}"
            kill -9 $PID 2>/dev/null || true
        done
    else
        echo -e "${GREEN}   ✅ Port $PORT FREE${NC}"
    fi
done
sleep 1
echo ""

# Step 4: Final verification
echo -e "${YELLOW}4️⃣  Final verification...${NC}"
BENCH_RUNNING=$(pgrep -f "bench" | wc -l)
if [ $BENCH_RUNNING -eq 0 ]; then
    echo -e "${GREEN}✅ No Bench processes running${NC}"
else
    echo -e "${RED}❌ Still $BENCH_RUNNING Bench processes running${NC}"
fi
echo ""

# Step 5: Status report
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Bench stopped successfully!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Port Status:${NC}"
for PORT in "${PORTS[@]}"; do
    STATUS=$(lsof -i :$PORT >/dev/null 2>&1 && echo -e "${RED}❌ IN USE${NC}" || echo -e "${GREEN}✅ FREE${NC}")
    echo -e "  Port $PORT: $STATUS"
done
echo ""
echo -e "${YELLOW}You can now safely start Bench again with:${NC}"
echo -e "${GREEN}  $SCRIPT_DIR/start-erp.sh${NC}"
echo ""
