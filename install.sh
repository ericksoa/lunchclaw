#!/usr/bin/env bash
# LunchClaw installer — run with: curl -fsSL https://raw.githubusercontent.com/ericksoa/lunchclaw/main/install.sh | bash
#
# Clones the repo, checks prerequisites, and launches the setup wizard.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}"
echo "  LunchClaw Installer"
echo "  ==================="
echo -e "${NC}"

# Check prerequisites
for cmd in git node npm docker openshell; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}ERROR: $cmd not found.${NC}"
        case "$cmd" in
            openshell) echo "  Install NemoClaw first: curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash" ;;
            docker)    echo "  Install Docker: https://docs.docker.com/get-docker/" ;;
            node|npm)  echo "  Install Node.js 22+: https://nodejs.org/" ;;
            git)       echo "  Install git: https://git-scm.com/" ;;
        esac
        exit 1
    fi
done

# Clone repos
INSTALL_DIR="${LUNCHCLAW_DIR:-$HOME/lunchclaw}"

if [ -d "$INSTALL_DIR" ]; then
    echo "  Found existing install at $INSTALL_DIR"
    cd "$INSTALL_DIR"
    git pull --quiet
else
    echo "  Cloning lunchclaw..."
    git clone --quiet https://github.com/ericksoa/lunchclaw.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

if [ ! -d "$INSTALL_DIR/../hungry-cli" ]; then
    echo "  Cloning hungry-cli..."
    git clone --quiet https://github.com/ericksoa/hungry-cli.git "$INSTALL_DIR/../hungry-cli"
fi

echo -e "  ${GREEN}Installed to $INSTALL_DIR${NC}"
echo ""

# Launch setup wizard
exec "$INSTALL_DIR/lunchclaw" setup
