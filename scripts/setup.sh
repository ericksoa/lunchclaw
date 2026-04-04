#!/usr/bin/env bash
# Setup script for LunchClaw — provisions a NemoClaw sandbox
# with delivery service access, Telegram messaging, and hungry-cli.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HUNGRY_CLI_DIR="$(cd "$PROJECT_DIR/../hungry-cli" && pwd)"

echo "LunchClaw Setup"
echo "==================="
echo ""

# --- Step 1: Check prerequisites ---
echo "[1/8] Checking prerequisites..."

command -v nemoclaw >/dev/null 2>&1 || {
    echo "ERROR: nemoclaw CLI not found. Install NemoClaw first:"
    echo "  https://github.com/NVIDIA/NemoClaw"
    exit 1
}

command -v openshell >/dev/null 2>&1 || {
    echo "ERROR: openshell CLI not found. Install OpenShell first."
    exit 1
}

if [ ! -d "$HUNGRY_CLI_DIR" ]; then
    echo "ERROR: hungry-cli not found at $HUNGRY_CLI_DIR"
    echo "  Clone it alongside this repo: git clone <hungry-cli-repo> ../hungry-cli"
    exit 1
fi

# --- Step 2: Create/onboard the sandbox ---
echo "[2/8] Creating LunchClaw sandbox..."

if openshell sandbox list 2>/dev/null | grep -q "lunchclaw"; then
    echo "  Sandbox 'lunchclaw' already exists. Skipping creation."
else
    nemoclaw onboard --name lunchclaw
fi

# --- Step 3: Upload workspace files ---
echo "[3/8] Uploading workspace files..."

for file in SOUL.md IDENTITY.md USER.md AGENTS.md; do
    if [ -f "$PROJECT_DIR/workspace/$file" ]; then
        openshell sandbox upload lunchclaw \
            "$PROJECT_DIR/workspace/$file" \
            "/sandbox/.openclaw/workspace/$file"
        echo "  Uploaded $file"
    fi
done

# --- Step 4: Upload hungry-cli ---
echo "[4/8] Uploading hungry-cli to sandbox..."

# Build hungry-cli locally first
(cd "$HUNGRY_CLI_DIR" && npm run build)

openshell sandbox upload lunchclaw \
    "$HUNGRY_CLI_DIR" \
    "/sandbox/hungry-cli" \
    --exclude node_modules --exclude .git

# Install dependencies inside sandbox
openshell sandbox exec lunchclaw -- bash -c '
    cd /sandbox/hungry-cli
    npm install --production 2>/dev/null
    echo "  hungry-cli dependencies installed."
'

# --- Step 5: Upload lunchclaw bot ---
echo "[5/8] Uploading LunchClaw bot to sandbox..."

openshell sandbox upload lunchclaw \
    "$PROJECT_DIR/sandbox-app" \
    "/sandbox/lunchclaw" \
    --exclude node_modules --exclude dist

openshell sandbox exec lunchclaw -- bash -c '
    cd /sandbox/lunchclaw
    npm install --production 2>/dev/null
    npm run build 2>/dev/null
    echo "  LunchClaw bot installed."
'

# --- Step 6: Install Playwright inside sandbox ---
echo "[6/8] Installing Playwright in sandbox..."

openshell sandbox exec lunchclaw -- bash -c '
    cd /sandbox/hungry-cli
    npx playwright install chromium 2>/dev/null
    echo "  Playwright + Chromium installed."
'

# --- Step 7: Apply network policy ---
echo "[7/8] Applying network policies..."

openshell policy set lunchclaw --add "$PROJECT_DIR/policies/network.yaml"
echo "  Network policies applied."

# --- Step 8: Verify Telegram access ---
echo "[8/8] Verifying Telegram access..."

if openshell policy get lunchclaw 2>/dev/null | grep -q "telegram"; then
    echo "  Telegram access confirmed."
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
echo "  3. Set environment variables inside the sandbox:"
echo "     openshell sandbox exec lunchclaw -- bash -c '"
echo "       echo \"TELEGRAM_BOT_TOKEN=your-token\" >> /sandbox/.env"
echo "       echo \"TELEGRAM_ALLOWED_USER_ID=your-id\" >> /sandbox/.env"
echo "       echo \"DELIVERY_ADDRESS=your-address\" >> /sandbox/.env"
echo "     '"
echo "  4. Log into your delivery service (one-time):"
echo "     openshell sandbox exec lunchclaw -- node /sandbox/hungry-cli/dist/cli.js auth"
echo "  5. Start LunchClaw:"
echo "     openshell sandbox exec lunchclaw -- node /sandbox/lunchclaw/dist/bot.js"
