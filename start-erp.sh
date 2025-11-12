#!/bin/bash

# Diigice-ERP Start Script with Auto-Cleanup
# This script checks for stale processes and cleans ports before starting

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════╗"
echo "║     Diigice-ERP - Start with Auto-Cleanup              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTS=(8001 13001 11001)

echo -e "${BLUE}ℹ️  Project Root: $PROJECT_ROOT${NC}"
echo ""

# Step 1: Check for running bench instances
echo -e "${YELLOW}1️⃣  Checking for running Bench instances...${NC}"
BENCH_PIDS=$(pgrep -f "bench start" 2>/dev/null || true)
if [ ! -z "$BENCH_PIDS" ]; then
    echo -e "${YELLOW}⚠️  Found running Bench instance(s): $BENCH_PIDS${NC}"
    echo -e "${YELLOW}Stopping them gracefully...${NC}"
    for PID in $BENCH_PIDS; do
        kill -TERM $PID 2>/dev/null || true
    done
    sleep 2
    # Force kill if still running
    if pgrep -f "bench start" > /dev/null 2>&1; then
        echo -e "${YELLOW}Force stopping...${NC}"
        pkill -9 -f "bench start" || true
    fi
fi
echo -e "${GREEN}✅ Check complete${NC}"
echo ""

# Step 2: Check and free ports
echo -e "${YELLOW}2️⃣  Checking ports...${NC}"
for PORT in "${PORTS[@]}"; do
    if lsof -i :$PORT >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port $PORT is in use. Freeing it...${NC}"
        PIDS=$(lsof -t -i :$PORT 2>/dev/null || true)
        for PID in $PIDS; do
            echo -e "${YELLOW}   Killing PID $PID${NC}"
            kill -9 $PID 2>/dev/null || true
        done
        sleep 1
    else
        echo -e "${GREEN}   Port $PORT: FREE${NC}"
    fi
done
echo ""

# Step 3: Verify ports are free
echo -e "${YELLOW}3️⃣  Verifying all ports are free...${NC}"
ALL_CLEAN=true
for PORT in "${PORTS[@]}"; do
    if lsof -i :$PORT >/dev/null 2>&1; then
        echo -e "${RED}   ❌ Port $PORT still in use!${NC}"
        ALL_CLEAN=false
    else
        echo -e "${GREEN}   ✅ Port $PORT FREE${NC}"
    fi
done

if [ "$ALL_CLEAN" = false ]; then
    echo -e "${RED}❌ Failed to free all ports. Waiting...${NC}"
    sleep 5
fi
echo ""

# Step 4: Check for zombie processes
echo -e "${YELLOW}4️⃣  Checking for zombie processes...${NC}"
ZOMBIES=$(ps aux | grep defunct | grep -v grep || true)
if [ ! -z "$ZOMBIES" ]; then
    echo -e "${YELLOW}⚠️  Found zombie processes:${NC}"
    echo "$ZOMBIES"
    echo -e "${YELLOW}Cleaning up...${NC}"
    pkill -9 -f "defunct" 2>/dev/null || true
fi
echo -e "${GREEN}✅ Check complete${NC}"
echo ""

# Step 5: Final status
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All pre-flight checks passed!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Step 6: Start Bench
echo -e "${YELLOW}🚀 Starting Bench...${NC}"
echo -e "${BLUE}Access at: http://127.0.0.1:8001${NC}"
echo ""
cd "$PROJECT_ROOT"
bench start
