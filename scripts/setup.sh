#!/usr/bin/env bash
# Setup script for LunchClaw — provisions a NemoClaw sandbox
# with Uber Eats access, Telegram messaging, and Playwright.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🦀 LunchClaw Setup"
echo "==================="
echo ""

# --- Step 1: Check prerequisites ---
echo "[1/6] Checking prerequisites..."

command -v nemoclaw >/dev/null 2>&1 || {
    echo "ERROR: nemoclaw CLI not found. Install NemoClaw first:"
    echo "  https://github.com/NVIDIA/NemoClaw"
    exit 1
}

command -v openshell >/dev/null 2>&1 || {
    echo "ERROR: openshell CLI not found. Install OpenShell first."
    exit 1
}

# --- Step 2: Create/onboard the sandbox ---
echo "[2/6] Creating LunchClaw sandbox..."

# Check if sandbox already exists
if openshell sandbox list 2>/dev/null | grep -q "lunchclaw"; then
    echo "  Sandbox 'lunchclaw' already exists. Skipping creation."
else
    nemoclaw onboard --name lunchclaw
fi

# --- Step 3: Upload workspace files ---
echo "[3/6] Uploading workspace files..."

for file in SOUL.md IDENTITY.md USER.md AGENTS.md; do
    if [ -f "$PROJECT_DIR/workspace/$file" ]; then
        openshell sandbox upload lunchclaw \
            "$PROJECT_DIR/workspace/$file" \
            "/sandbox/.openclaw/workspace/$file"
        echo "  Uploaded $file"
    fi
done

# --- Step 4: Apply Uber Eats network policy ---
echo "[4/6] Applying Uber Eats network policy..."

openshell policy set lunchclaw --add "$PROJECT_DIR/policies/ubereats.yaml"
echo "  Uber Eats access enabled."

# --- Step 5: Install Playwright inside sandbox ---
echo "[5/6] Installing Playwright in sandbox..."

openshell sandbox exec lunchclaw -- bash -c '
    npm install -g playwright 2>/dev/null || true
    npx playwright install chromium 2>/dev/null
    echo "  Playwright + Chromium installed."
'

# --- Step 6: Verify Telegram policy ---
echo "[6/6] Verifying Telegram access..."

# Telegram is in the base NemoClaw policy, just confirm it's active
if openshell policy get lunchclaw 2>/dev/null | grep -q "telegram"; then
    echo "  Telegram access confirmed (from base policy)."
else
    echo "  WARNING: Telegram not in active policy. You may need to add it."
fi

echo ""
echo "==================="
echo "LunchClaw is ready!"
echo ""
echo "Next steps:"
echo "  1. Edit workspace/USER.md with your delivery address"
echo "  2. Set up a Telegram bot via @BotFather and note the token"
echo "  3. Log into Uber Eats inside the sandbox:"
echo "     openshell sandbox exec lunchclaw -- npx playwright open https://www.ubereats.com"
echo "  4. Start LunchClaw:"
echo "     openshell sandbox exec lunchclaw -- node /sandbox/lunchclaw/bot.js"
