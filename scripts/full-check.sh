#!/usr/bin/env bash
set -euo pipefail

echo "=== FactoryGame Full Check ==="
echo ""

# Step 1: Lint
echo "[1/4] selene lint..."
selene src/ main.lua conf.lua
echo "  PASS"
echo ""

# Step 2: Format check (no auto-fix, just verify)
echo "[2/4] stylua format check..."
stylua --check src/ main.lua conf.lua
echo "  PASS"
echo ""

# Step 3: Tests
echo "[3/4] busted tests..."
busted
echo "  PASS"
echo ""

# Step 4: Architecture validator (added by Plan 03)
echo "[4/4] architecture validator..."
if [ -f "scripts/validate_architecture.lua" ]; then
    lua scripts/validate_architecture.lua
    echo "  PASS"
else
    echo "  SKIP (validator not yet created)"
fi
echo ""

echo "=== All checks passed ==="
