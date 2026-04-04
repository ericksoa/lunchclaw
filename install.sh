#!/usr/bin/env bash
# LunchClaw installer — run with: curl -fsSL https://raw.githubusercontent.com/ericksoa/lunchclaw/main/install.sh | bash
#
# Installs NemoClaw (if needed), clones the repo, and launches the setup wizard.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# --- Check basic prereqs ---
for cmd in git docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}ERROR: $cmd not found.${NC}"
        case "$cmd" in
            docker) echo "  Install Docker: https://docs.docker.com/get-docker/" ;;
            git)    echo "  Install git: https://git-scm.com/" ;;
        esac
        exit 1
    fi
done

# --- Install NemoClaw if needed (brings Node.js + OpenShell) ---
if ! command -v openshell >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
    echo -e "${YELLOW}  NemoClaw not found. Installing...${NC}"
    echo ""
    echo "  NemoClaw will install Node.js and OpenShell automatically."
    echo "  See: https://github.com/NVIDIA/NemoClaw"
    echo ""
    curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
    echo ""

    # Reload PATH in case NemoClaw updated it
    # shellcheck disable=SC1090
    source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true

    if ! command -v openshell >/dev/null 2>&1; then
        echo -e "${RED}ERROR: NemoClaw installed but openshell not found in PATH.${NC}"
        echo "  Try opening a new terminal and running this installer again."
        exit 1
    fi
    echo -e "  ${GREEN}NemoClaw installed.${NC}"
else
    echo -e "  ${GREEN}NemoClaw found: $(openshell --version 2>&1)${NC}"
fi

echo ""

# --- Clone repos ---
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
