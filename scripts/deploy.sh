#!/usr/bin/env bash
# Production deployment script for LunchClaw.
# Creates a NemoClaw sandbox, uploads code, installs deps, and starts the bot.
#
# Prerequisites:
#   - openshell CLI installed
#   - Docker running
#   - hungry-cli built (../hungry-cli/dist/ exists)
#   - .env file at /sandbox/.env with TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USER_ID, DELIVERY_ADDRESS
#
# Usage:
#   ./scripts/deploy.sh              # Full deploy (create sandbox + upload + start)
#   ./scripts/deploy.sh --update     # Update code only (skip sandbox creation)
#   ./scripts/deploy.sh --start      # Start bot only (skip upload)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HUNGRY_CLI_DIR="$(cd "$PROJECT_DIR/../hungry-cli" && pwd)"
SANDBOX_NAME="lunchclaw-demo"
SSH_HOST="openshell-${SANDBOX_NAME}"

MODE="${1:-full}"

# --- Helpers ---

step() { echo ""; echo "==> $1"; }
ok()   { echo "    OK"; }

check_prereqs() {
    step "Checking prerequisites"

    command -v openshell >/dev/null 2>&1 || { echo "ERROR: openshell not found"; exit 1; }
    command -v ssh >/dev/null 2>&1 || { echo "ERROR: ssh not found"; exit 1; }

    if [ ! -d "$HUNGRY_CLI_DIR/dist" ]; then
        echo "Building hungry-cli..."
        (cd "$HUNGRY_CLI_DIR" && npm run build)
    fi

    if [ ! -d "$PROJECT_DIR/sandbox-app/dist" ]; then
        echo "Building lunchclaw..."
        (cd "$PROJECT_DIR/sandbox-app" && npm run build)
    fi

    ok
}

create_sandbox() {
    step "Creating sandbox: $SANDBOX_NAME"

    if openshell sandbox list 2>/dev/null | grep -q "$SANDBOX_NAME"; then
        echo "    Sandbox already exists, skipping creation."
    else
        openshell sandbox create --name "$SANDBOX_NAME" --from openclaw
    fi

    # Ensure SSH config is set up
    if ! grep -q "openshell-${SANDBOX_NAME}" ~/.ssh/config 2>/dev/null; then
        openshell sandbox ssh-config "$SANDBOX_NAME" >> ~/.ssh/config
        echo "    SSH config added."
    fi

    ok
}

apply_policy() {
    step "Applying network policy"
    openshell policy set --policy "$PROJECT_DIR/policies/network.yaml" --wait "$SANDBOX_NAME"
    ok
}

upload_code() {
    step "Uploading hungry-cli"
    openshell sandbox upload --no-git-ignore "$SANDBOX_NAME" "$HUNGRY_CLI_DIR" /sandbox/hungry-cli
    ok

    step "Uploading lunchclaw bot"
    openshell sandbox upload --no-git-ignore "$SANDBOX_NAME" "$PROJECT_DIR/sandbox-app" /sandbox/lunchclaw
    ok

    step "Uploading workspace files"
    openshell sandbox upload "$SANDBOX_NAME" "$PROJECT_DIR/workspace" /sandbox/.openclaw/workspace
    ok
}

install_deps() {
    step "Installing dependencies in sandbox"
    ssh "$SSH_HOST" 'cd /sandbox/hungry-cli && npm install --omit=dev 2>&1 | tail -1'
    ssh "$SSH_HOST" 'cd /sandbox/lunchclaw && npm install --omit=dev 2>&1 | tail -1'
    ok
}

install_playwright() {
    step "Installing Playwright chromium"
    ssh "$SSH_HOST" 'cd /sandbox/hungry-cli && npx playwright install chromium 2>&1 | tail -3'
    ok
}

verify() {
    step "Verifying installation"
    ssh "$SSH_HOST" 'node /sandbox/hungry-cli/dist/cli.js --version'
    ssh "$SSH_HOST" 'node /sandbox/lunchclaw/dist/bot.js --help 2>&1 || true'
    echo "    hungry-cli: OK"
    echo "    lunchclaw: OK"

    # Check if .env exists
    if ssh "$SSH_HOST" 'test -f /sandbox/.env'; then
        echo "    .env: found"
    else
        echo ""
        echo "    WARNING: /sandbox/.env not found!"
        echo "    Create it with:"
        echo "      ssh $SSH_HOST 'cat > /sandbox/.env << EOF"
        echo "      TELEGRAM_BOT_TOKEN=your-token"
        echo "      TELEGRAM_ALLOWED_USER_ID=your-user-id"
        echo "      DELIVERY_ADDRESS=your-address"
        echo "      HUNGRY_CLI_PATH=/sandbox/hungry-cli/dist/cli.js"
        echo "      EOF'"
    fi
    ok
}

start_bot() {
    step "Starting LunchClaw bot"

    # Stop any existing bot process
    ssh "$SSH_HOST" 'pkill -f "node.*bot.js" 2>/dev/null || true'
    sleep 1

    # Start bot in background with nohup
    ssh "$SSH_HOST" 'cd /sandbox/lunchclaw && nohup node dist/bot.js >> /sandbox/lunchclaw.log 2>&1 &'
    sleep 2

    # Verify it's running
    if ssh "$SSH_HOST" 'pgrep -f "node.*bot.js" > /dev/null 2>&1'; then
        echo "    Bot is running (PID: $(ssh "$SSH_HOST" 'pgrep -f "node.*bot.js"'))"
        echo "    Logs: ssh $SSH_HOST 'tail -f /sandbox/lunchclaw.log'"
    else
        echo "    ERROR: Bot failed to start. Check logs:"
        ssh "$SSH_HOST" 'tail -20 /sandbox/lunchclaw.log 2>/dev/null'
        exit 1
    fi
    ok
}

# --- Main ---

echo "LunchClaw Production Deploy"
echo "============================"
echo "Sandbox: $SANDBOX_NAME"
echo "Mode:    $MODE"

check_prereqs

case "$MODE" in
    full|--full)
        create_sandbox
        apply_policy
        upload_code
        install_deps
        install_playwright
        verify
        start_bot
        ;;
    --update)
        upload_code
        install_deps
        verify
        start_bot
        ;;
    --start)
        start_bot
        ;;
    *)
        echo "Usage: $0 [--full|--update|--start]"
        exit 1
        ;;
esac

echo ""
echo "============================"
echo "LunchClaw deployed!"
echo ""
echo "  View logs:  ssh $SSH_HOST 'tail -f /sandbox/lunchclaw.log'"
echo "  Stop bot:   ssh $SSH_HOST 'pkill -f node.*bot.js'"
echo "  Restart:    $0 --start"
echo "  Update:     $0 --update"
