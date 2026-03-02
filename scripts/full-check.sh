#!/usr/bin/env bash
# Mirrors .github/workflows/ci.yml — keep in sync.
# Run before pushing to catch CI failures locally.
# CI triggers automatically on: push to main, any pull_request, or workflow_dispatch.
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

# Step 4: Architecture validator
echo "[4/4] architecture validator..."
lua scripts/validate_architecture.lua
echo "  PASS"
echo ""

echo "=== All checks passed ==="
