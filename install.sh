#!/usr/bin/env bash
# LunchClaw installer
# Run: curl -fsSL https://raw.githubusercontent.com/ericksoa/lunchclaw/main/install.sh | bash
#
# What this does:
#   1. Collects Telegram token, user ID, delivery address
#   2. Installs NemoClaw v0.0.6+ if needed
#   3. Runs nemoclaw onboard (creates gateway + sandbox)
#   4. Builds custom base image with Playwright system libs
#   5. Merges delivery service + Playwright CDN into network policy
#   6. Uploads hungry-cli + workspace + auth session to sandbox
#   7. Installs Chromium inside sandbox
#   8. Sets lunchclaw as default sandbox
#   9. Starts the Telegram bridge

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SANDBOX_NAME="lunchclaw"
INSTALL_DIR="${LUNCHCLAW_DIR:-$HOME/lunchclaw}"

step()  { echo -e "\n${BOLD}==> $1${NC}"; }
ok()    { echo -e "    ${GREEN}OK${NC}"; }
warn()  { echo -e "    ${YELLOW}$1${NC}"; }
fail()  { echo -e "    ${RED}$1${NC}"; exit 1; }

# =========================================================================
# Banner
# =========================================================================
echo -e "${BOLD}"
echo "  LunchClaw Installer"
echo "  ==================="
echo -e "${NC}"
echo "  A healthy food ordering bot for Telegram."
echo ""
echo "  Powered by:"
echo "    NVIDIA NemoClaw  https://github.com/NVIDIA/NemoClaw"
echo "    NVIDIA OpenShell https://github.com/NVIDIA/OpenShell"
echo ""

# =========================================================================
# Step 1: Collect config
# =========================================================================
step "LunchClaw configuration"

if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.env.local" ]; then
    echo "    Found existing config at $INSTALL_DIR/.env.local"
    source "$INSTALL_DIR/.env.local"
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo ""
    echo "    Step 1 of 3: Get a Telegram bot token"
    echo ""
    echo "    a) Install Telegram if you don't have it: https://telegram.org"
    echo "    b) Open Telegram and search for @BotFather (or go to https://t.me/BotFather)"
    echo "    c) Send /newbot to @BotFather"
    echo "    d) Choose a name for your bot (e.g., 'My LunchClaw')"
    echo "    e) Choose a username (must end in 'bot', e.g., 'mylunchclaw_bot')"
    echo "    f) @BotFather will reply with a token like: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
    echo ""
    read -rp "    Paste your bot token here: " TELEGRAM_BOT_TOKEN
fi

if [ -z "${TELEGRAM_ALLOWED_USER_ID:-}" ]; then
    echo ""
    echo "    Step 2 of 3: Get your Telegram user ID"
    echo ""
    echo "    a) In Telegram, search for @userinfobot (or go to https://t.me/userinfobot)"
    echo "    b) Send any message to @userinfobot"
    echo "    c) It will reply with your user ID (a number like 123456789)"
    echo ""
    read -rp "    Paste your user ID here: " TELEGRAM_ALLOWED_USER_ID
fi

if [ -z "${DELIVERY_ADDRESS:-}" ]; then
    echo ""
    echo "    Step 3 of 3: Delivery address"
    echo ""
    read -rp "    Enter your delivery address: " DELIVERY_ADDRESS
fi
ok

# =========================================================================
# Step 2: Prerequisites
# =========================================================================
step "Checking prerequisites"

command -v git >/dev/null 2>&1 || fail "git not found. Install: https://git-scm.com/"
command -v docker >/dev/null 2>&1 || fail "Docker not found. Install: https://docs.docker.com/get-docker/"

if ! command -v nemoclaw >/dev/null 2>&1; then
    echo -e "    ${YELLOW}NemoClaw not found. Installing...${NC}"
    curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
    source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true
    command -v nemoclaw >/dev/null 2>&1 || fail "NemoClaw installed but not in PATH. Open a new terminal and re-run."
fi
echo "    NemoClaw: $(nemoclaw --version 2>&1)"
ok

# =========================================================================
# Step 3: Clone repos
# =========================================================================
step "Getting source code"

if [ -d "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git fetch --quiet origin 2>/dev/null
    git reset --hard origin/main --quiet 2>/dev/null
else
    rm -rf "$INSTALL_DIR" 2>/dev/null
    git clone --quiet https://github.com/ericksoa/lunchclaw.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

if [ -d "$INSTALL_DIR/../hungry-cli" ] && [ -d "$INSTALL_DIR/../hungry-cli/.git" ]; then
    (cd "$INSTALL_DIR/../hungry-cli" && git fetch --quiet origin 2>/dev/null && git reset --hard origin/main --quiet 2>/dev/null)
else
    git clone --quiet https://github.com/ericksoa/hungry-cli.git "$INSTALL_DIR/../hungry-cli"
fi

# Save config (quoted values for addresses with spaces)
cat > "$INSTALL_DIR/.env.local" << EOF
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_ALLOWED_USER_ID="${TELEGRAM_ALLOWED_USER_ID}"
DELIVERY_ADDRESS="${DELIVERY_ADDRESS}"
EOF
chmod 600 "$INSTALL_DIR/.env.local"
ok

# =========================================================================
# Step 4: Build locally
# =========================================================================
step "Building hungry-cli"
(cd "$INSTALL_DIR/../hungry-cli" && npm install --silent 2>&1 && npm run build 2>&1) | tail -1
ok

# =========================================================================
# Step 5: Build custom base image with Playwright libs
# =========================================================================
step "Building sandbox base image"
echo "    Adding Playwright system libraries to NemoClaw base image..."
docker build -t lunchclaw-base:latest -f "$INSTALL_DIR/Dockerfile" "$INSTALL_DIR" 2>&1 | tail -1
docker tag lunchclaw-base:latest ghcr.io/nvidia/nemoclaw/sandbox-base:latest
ok

# =========================================================================
# Step 6: NemoClaw onboard
# =========================================================================
step "Creating NemoClaw sandbox"

# Add custom policy presets for delivery service + Playwright CDN
# These go into NemoClaw's blueprint directory so they're applied during
# sandbox creation — not after, which avoids reprovisioning.
PRESET_DIR="$HOME/.nemoclaw/source/nemoclaw-blueprint/policies/presets"
if [ -d "$PRESET_DIR" ]; then
    cat > "$PRESET_DIR/delivery-service.yaml" << 'PRESET'
preset:
  name: delivery-service
  description: "Food delivery service access for hungry-cli"
network_policies:
  delivery_service:
    name: delivery_service
    endpoints:
      - host: www.ubereats.com
        port: 443
        access: full
      - host: "*.ubereats.com"
        port: 443
        access: full
      - host: "*.uber.com"
        port: 443
        access: full
      - host: "*.ubercdn.com"
        port: 443
        access: full
      - host: "*.cloudfront.net"
        port: 443
        access: full
    binaries:
      - { path: /usr/local/bin/node }
      - { path: /sandbox/.cache/ms-playwright/chromium-*/chrome-linux/chrome }
      - { path: /sandbox/.cache/ms-playwright/chromium_headless_shell-*/chrome-linux/headless_shell }
PRESET

    cat > "$PRESET_DIR/playwright-cdn.yaml" << 'PRESET'
preset:
  name: playwright-cdn
  description: "Playwright browser engine download access"
network_policies:
  playwright_cdn:
    name: playwright_cdn
    endpoints:
      - host: cdn.playwright.dev
        port: 443
        access: full
      - host: playwright.download.prss.microsoft.com
        port: 443
        access: full
    binaries:
      - { path: /usr/local/bin/node }
PRESET
    echo "    Custom policy presets installed."
fi

echo "    Running nemoclaw onboard..."
NEMOCLAW_NON_INTERACTIVE=1 \
NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1 \
NEMOCLAW_SANDBOX_NAME="$SANDBOX_NAME" \
NEMOCLAW_RECREATE_SANDBOX=1 \
NEMOCLAW_PROVIDER=cloud \
NEMOCLAW_POLICY_PRESETS="npm,telegram,delivery-service,playwright-cdn" \
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
nemoclaw onboard 2>&1
ok

# =========================================================================
# Step 7: Set lunchclaw as default sandbox
# =========================================================================
step "Setting default sandbox"
python3 -c "
import json
path = '$HOME/.nemoclaw/sandboxes.json'
with open(path) as f:
    d = json.load(f)
d['defaultSandbox'] = '$SANDBOX_NAME'
with open(path, 'w') as f:
    json.dump(d, f, indent=2)
print('    Default sandbox: $SANDBOX_NAME')
"
ok

# No post-onboard policy change needed — custom presets were applied during onboard.
# This avoids sandbox reprovisioning which caused instability.
set +e
set +o pipefail

# =========================================================================
# Step 9: Upload code to sandbox
# =========================================================================
step "Deploying to sandbox"

# Clean old SSH config entries then add fresh one
sed -i '' "/Host openshell-${SANDBOX_NAME}/,/^$/d" ~/.ssh/config 2>/dev/null
openshell sandbox ssh-config "$SANDBOX_NAME" >> ~/.ssh/config 2>/dev/null

SSH_HOST="openshell-${SANDBOX_NAME}"

# Wait for sandbox to be ready
echo "    Waiting for sandbox..."
for i in $(seq 1 24); do
    if ssh -n "$SSH_HOST" 'echo ok' >/dev/null 2>&1; then
        echo "    Sandbox is ready."
        break
    fi
    sleep 5
done

echo "    Uploading hungry-cli..."
openshell sandbox upload --no-git-ignore "$SANDBOX_NAME" "$INSTALL_DIR/../hungry-cli" /sandbox/hungry-cli 2>&1
echo "    Uploading workspace files..."
openshell sandbox upload "$SANDBOX_NAME" "$INSTALL_DIR/workspace" /sandbox/.openclaw/workspace 2>&1
echo "    Installing dependencies..."
ssh -n "$SSH_HOST" 'cd /sandbox/hungry-cli && npm install --omit=dev 2>&1'

ok

# =========================================================================
# Step 10: Install Chromium in sandbox
# =========================================================================
step "Installing browser engine in sandbox"
set +e
ssh -n "$SSH_HOST" 'cd /sandbox/hungry-cli && node node_modules/playwright/cli.js install chromium 2>&1'
set -e
ok

# =========================================================================
# Step 11: Auth (locally with bundled Chromium, then upload to sandbox)
# =========================================================================
step "Delivery service authentication"
echo ""
echo "    This opens a Chromium browser on your machine to log in."
echo "    Log in to your delivery service and set your delivery address."
echo "    Then press Enter in the terminal."
echo ""

AUTH_DIR="/tmp/hungry-sandbox-auth"

if [ -d "$AUTH_DIR/ubereats/chrome-profile" ] && [ -f "$AUTH_DIR/ubereats/auth.json" ]; then
    echo "    Found existing auth session."
    read -rp "    Use it? (Y/n): " use_existing
    if [ "${use_existing:-y}" = "n" ] || [ "${use_existing:-y}" = "N" ]; then
        rm -rf "$AUTH_DIR"
    fi
fi

if [ ! -d "$AUTH_DIR/ubereats/chrome-profile" ]; then
    (cd "$INSTALL_DIR/../hungry-cli" && HUNGRY_USE_BUNDLED=1 HUNGRY_DATA_DIR="$AUTH_DIR" node dist/cli.js auth)
fi

if [ -d "$AUTH_DIR/ubereats" ]; then
    openshell sandbox upload "$SANDBOX_NAME" "$AUTH_DIR/ubereats" /sandbox/.config/hungry/ubereats 2>&1
    echo "    Auth session uploaded to sandbox."
else
    warn "Auth may not have completed. Run auth manually later."
fi
ok

# =========================================================================
# Step 12: Start Telegram bridge
# =========================================================================
step "Starting Telegram bridge"

# Kill any existing bridge
pkill -f "telegram-bridge" 2>/dev/null || true
sleep 1

# Start bridge directly with correct env vars
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
NVIDIA_API_KEY="${NVIDIA_API_KEY:-}" \
SANDBOX_NAME="$SANDBOX_NAME" \
nohup node ~/.nemoclaw/source/scripts/telegram-bridge.js >> /tmp/lunchclaw-bridge.log 2>&1 &
BRIDGE_PID=$!

sleep 3
if kill -0 $BRIDGE_PID 2>/dev/null; then
    echo "    Bridge running (PID $BRIDGE_PID)"
    ok
else
    tail -5 /tmp/lunchclaw-bridge.log 2>/dev/null
    fail "Bridge failed to start. Check /tmp/lunchclaw-bridge.log"
fi

# =========================================================================
# Done
# =========================================================================
echo ""
echo -e "${BOLD}  ==============================${NC}"
echo -e "${BOLD}  LunchClaw is ready!${NC}"
echo -e "${BOLD}  ==============================${NC}"
echo ""
echo "  Message your bot on Telegram: \"I'm hungry, feed me\""
echo ""
echo "  Bridge log:    tail -f /tmp/lunchclaw-bridge.log"
echo "  Sandbox logs:  nemoclaw $SANDBOX_NAME logs --follow"
echo "  Stop bridge:   pkill -f telegram-bridge"
echo "  Restart:       TELEGRAM_BOT_TOKEN=... SANDBOX_NAME=$SANDBOX_NAME node ~/.nemoclaw/source/scripts/telegram-bridge.js"
