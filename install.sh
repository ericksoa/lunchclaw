#!/usr/bin/env bash
# LunchClaw installer — run with: curl -fsSL https://raw.githubusercontent.com/ericksoa/lunchclaw/main/install.sh | bash
#
# 1. Collects LunchClaw-specific config (Telegram, address)
# 2. Installs NemoClaw if needed
# 3. Runs nemoclaw onboard non-interactively with our defaults
# 4. Deploys LunchClaw code into the sandbox
# 5. Starts the bot

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
echo "  LunchClaw uses NemoClaw to create a secure, network-isolated"
echo "  sandbox for ordering food through Telegram."
echo ""

# =========================================================================
# Step 1: Collect LunchClaw-specific config
# =========================================================================
step "LunchClaw configuration"

# Load existing config if re-running
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.env.local" ]; then
    echo "    Found existing config at $INSTALL_DIR/.env.local"
    # shellcheck disable=SC1091
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
# Step 2: Check / install prerequisites
# =========================================================================
step "Checking prerequisites"

command -v git >/dev/null 2>&1 || fail "git not found. Install: https://git-scm.com/"
command -v docker >/dev/null 2>&1 || fail "Docker not found. Install: https://docs.docker.com/get-docker/"

# Install NemoClaw if not present (brings Node.js + OpenShell)
if ! command -v nemoclaw >/dev/null 2>&1; then
    echo ""
    echo -e "    ${YELLOW}NemoClaw not found. Installing...${NC}"
    echo "    This will install NemoClaw, OpenShell, and Node.js if needed."
    echo "    See: https://github.com/NVIDIA/NemoClaw"
    echo ""

    # NemoClaw's own installer handles Node.js, OpenShell, etc.
    curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash

    # Reload PATH
    # shellcheck disable=SC1090
    source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true

    command -v nemoclaw >/dev/null 2>&1 || fail "NemoClaw installed but not found in PATH. Open a new terminal and re-run."
fi

echo "    NemoClaw: $(nemoclaw --version 2>&1)"
echo "    OpenShell: $(openshell --version 2>&1)"
ok

# =========================================================================
# Step 3: Clone repos
# =========================================================================
step "Getting LunchClaw source"

if [ -d "$INSTALL_DIR" ]; then
    echo "    Found existing install at $INSTALL_DIR"
    cd "$INSTALL_DIR"
    git pull --quiet 2>/dev/null || true
else
    echo "    Cloning lunchclaw..."
    git clone --quiet https://github.com/ericksoa/lunchclaw.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

if [ ! -d "$INSTALL_DIR/../hungry-cli" ]; then
    echo "    Cloning hungry-cli..."
    git clone --quiet https://github.com/ericksoa/hungry-cli.git "$INSTALL_DIR/../hungry-cli"
fi

# Save config
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

step "Building lunchclaw bot"
(cd "$INSTALL_DIR/sandbox-app" && npm install --silent 2>&1 && npm run build 2>&1) | tail -1
ok

# =========================================================================
# Step 5: NemoClaw onboard — create the secure sandbox
# =========================================================================
step "Creating NemoClaw sandbox"

if nemoclaw list 2>/dev/null | awk '{print $1}' | grep -qx "$SANDBOX_NAME"; then
    echo "    Sandbox '$SANDBOX_NAME' already exists."
else
    echo "    Running nemoclaw onboard with LunchClaw defaults..."
    echo "    This creates a secure OpenShell sandbox with network isolation."
    echo ""

    # Drive NemoClaw non-interactively with our defaults:
    # - Sandbox name: lunchclaw
    # - Provider: cloud (NVIDIA API)
    # - Telegram token: auto-enables Telegram policy
    # - Policy presets: npm (for package install), telegram
    export NEMOCLAW_NON_INTERACTIVE=1
    export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
    export NEMOCLAW_SANDBOX_NAME="$SANDBOX_NAME"
    export NEMOCLAW_PROVIDER="${NEMOCLAW_PROVIDER:-cloud}"
    export NEMOCLAW_POLICY_PRESETS="npm,telegram"
    export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"

    nemoclaw onboard
fi
ok

# =========================================================================
# Step 6: Apply LunchClaw network policy (adds delivery service access)
# =========================================================================
step "Applying LunchClaw network policy"
echo "    Adding delivery service and Playwright download access..."

# NemoClaw's onboard gives us telegram + npm.
# We add the delivery service endpoints on top.
openshell policy set --policy "$INSTALL_DIR/policies/network.yaml" --wait "$SANDBOX_NAME"
ok

# =========================================================================
# Step 7: Deploy code into sandbox
# =========================================================================

# Ensure SSH config
if ! grep -q "openshell-${SANDBOX_NAME}" ~/.ssh/config 2>/dev/null; then
    openshell sandbox ssh-config "$SANDBOX_NAME" >> ~/.ssh/config
fi
SSH_HOST="openshell-${SANDBOX_NAME}"

step "Deploying hungry-cli to sandbox"
openshell sandbox upload --no-git-ignore "$SANDBOX_NAME" "$INSTALL_DIR/../hungry-cli" /sandbox/hungry-cli
ok

step "Deploying lunchclaw bot to sandbox"
openshell sandbox upload --no-git-ignore "$SANDBOX_NAME" "$INSTALL_DIR/sandbox-app" /sandbox/lunchclaw
ok

step "Uploading workspace files"
openshell sandbox upload "$SANDBOX_NAME" "$INSTALL_DIR/workspace" /sandbox/.openclaw/workspace
ok

# =========================================================================
# Step 8: Install dependencies in sandbox
# =========================================================================
step "Installing dependencies in sandbox"
ssh "$SSH_HOST" 'cd /sandbox/hungry-cli && npm install --omit=dev 2>&1 | tail -1'
ssh "$SSH_HOST" 'cd /sandbox/lunchclaw && npm install --omit=dev 2>&1 | tail -1'
ok

step "Installing browser engine"
ssh "$SSH_HOST" 'cd /sandbox/hungry-cli && node node_modules/playwright/cli.js install chromium 2>&1 | grep -E "downloaded|Failed" || true'
ok

# =========================================================================
# Step 9: Configure sandbox environment
# =========================================================================
step "Configuring sandbox environment"
ssh "$SSH_HOST" "cat > /sandbox/.env << EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_ALLOWED_USER_ID=${TELEGRAM_ALLOWED_USER_ID}
DELIVERY_ADDRESS=${DELIVERY_ADDRESS}
HUNGRY_CLI_PATH=/sandbox/hungry-cli/dist/cli.js
BUDGET_MAX=30
EOF"
ok

# =========================================================================
# Step 10: Delivery service auth (runs locally, uploads session)
# =========================================================================
step "Delivery service authentication"
echo ""
echo "    You need to log into your delivery service once."
echo "    This opens Chrome on YOUR machine, then uploads the"
echo "    session to the secure sandbox."
echo ""

AUTH_DIR="$HOME/.config/hungry/ubereats"
if [ -d "$AUTH_DIR/chrome-profile" ] && [ -f "$AUTH_DIR/auth.json" ]; then
    echo "    Found existing local session."
    read -rp "    Use it? (Y/n): " use_existing
    if [ "${use_existing:-y}" != "n" ] && [ "${use_existing:-y}" != "N" ]; then
        openshell sandbox upload "$SANDBOX_NAME" "$AUTH_DIR" /sandbox/.config/hungry/ubereats
        ok
    else
        echo "    Opening Chrome..."
        (cd "$INSTALL_DIR/../hungry-cli" && node dist/cli.js auth)
        openshell sandbox upload "$SANDBOX_NAME" "$AUTH_DIR" /sandbox/.config/hungry/ubereats
        ok
    fi
else
    echo "    Opening Chrome..."
    (cd "$INSTALL_DIR/../hungry-cli" && node dist/cli.js auth)
    if [ -d "$AUTH_DIR/chrome-profile" ]; then
        openshell sandbox upload "$SANDBOX_NAME" "$AUTH_DIR" /sandbox/.config/hungry/ubereats
        ok
    else
        warn "Auth may not have completed. Run './lunchclaw auth' later."
    fi
fi

# =========================================================================
# Step 11: Start the bot
# =========================================================================
step "Starting LunchClaw"
ssh "$SSH_HOST" 'pkill -f "node.*bot.js" 2>/dev/null || true'
sleep 1
ssh "$SSH_HOST" 'cd /sandbox/lunchclaw && nohup node dist/bot.js >> /sandbox/lunchclaw.log 2>&1 &'
sleep 2
if ssh "$SSH_HOST" 'pgrep -f "node.*bot.js" > /dev/null 2>&1'; then
    ok
else
    fail "Bot failed to start. Check: ssh $SSH_HOST 'tail -20 /sandbox/lunchclaw.log'"
fi

# =========================================================================
# Done
# =========================================================================
echo ""
echo -e "${BOLD}  ==============================${NC}"
echo -e "${BOLD}  LunchClaw is ready!${NC}"
echo -e "${BOLD}  ==============================${NC}"
echo ""
echo "  Message your bot on Telegram: \"hungry, something with chicken\""
echo ""
echo "  Manage your bot:"
echo "    cd $INSTALL_DIR"
echo "    ./lunchclaw status     Check health"
echo "    ./lunchclaw logs       Stream logs"
echo "    ./lunchclaw stop       Stop the bot"
echo "    ./lunchclaw start      Start the bot"
echo "    ./lunchclaw update     Rebuild and redeploy"
echo "    ./lunchclaw auth       Re-authenticate delivery service"
echo "    ./lunchclaw destroy    Remove sandbox (permanent)"
