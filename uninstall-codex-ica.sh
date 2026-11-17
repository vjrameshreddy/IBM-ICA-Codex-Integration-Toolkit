#!/usr/bin/env bash
# ==============================================================================
# IBM ICA + Codex Automated Uninstaller & Cleanup Tool
# Platform: macOS / Linux (Bash / Zsh)
# ==============================================================================

set -euo pipefail

# Color palette
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

DRY_RUN=false
ASSUME_YES=false
KEEP_CONFIG=false
KEEP_API_KEY=false

for arg in "$@"; do
    case "$arg" in
        --dry-run|--preview) DRY_RUN=true ;;
        --yes|-y) ASSUME_YES=true ;;
        --keep-config) KEEP_CONFIG=true ;;
        --keep-api-key) KEEP_API_KEY=true ;;
        *) ;;
    esac
done

ask_approval() {
    local prompt="$1"
    local default_yes="${2:-false}"
    if [ "$ASSUME_YES" = true ]; then return 0; fi
    local opts="[y/N]"
    if [ "$default_yes" = true ]; then opts="[Y/n]"; fi
    read -r -p "$prompt $opts " response || true
    if [ -z "$response" ]; then
        [ "$default_yes" = true ] && return 0 || return 1
    fi
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

echo -e "\n${CYAN}=================================================================${NC}"
echo -e "${WHITE}  IBM ICA + Codex Automated Uninstaller & Cleanup Tool${NC}"
echo -e "${CYAN}  macOS / Linux Edition with Safe Cleanup & Confirmation${NC}"
echo -e "${CYAN}=================================================================${NC}"

CODEX_DIR="$HOME/.codex"
TEST_DIR="$HOME/IBM ICA-Codex-Integration-Toolkit"

echo -e "\n${CYAN}[+] Inspecting current Codex installation state...${NC}"

# Check running daemons
running_daemons=false
if pgrep -f "codex|node_repl" >/dev/null 2>&1; then
    running_daemons=true
    echo -e " ${YELLOW}[INFO]${NC} Running Daemons        : Active processes detected (codex/node_repl)"
else
    echo -e " [INFO] Running Daemons        : None detected"
fi

# Check npm packages
installed_packages=()
if command -v codex >/dev/null 2>&1; then installed_packages+=("@openai/codex"); fi
if command -v codex-security >/dev/null 2>&1; then installed_packages+=("@openai/codex-security"); fi

if [ ${#installed_packages[@]} -gt 0 ]; then
    echo -e " ${YELLOW}[INFO]${NC} Global npm Packages    : ${installed_packages[*]}"
else
    echo -e " [INFO] Global npm Packages    : None detected"
fi

# Check ~/.codex directory
has_codex_dir=false
if [ -d "$CODEX_DIR" ]; then
    has_codex_dir=true
    echo -e " ${YELLOW}[INFO]${NC} Configuration Directory: $CODEX_DIR (Exists)"
else
    echo -e " [INFO] Configuration Directory: $CODEX_DIR (Not present)"
fi

# Check test workspace
has_test_dir=false
if [ -d "$TEST_DIR" ]; then
    has_test_dir=true
    echo -e " ${YELLOW}[INFO]${NC} Test Workspace Folder  : $TEST_DIR (Exists)"
else
    echo -e " [INFO] Test Workspace Folder  : $TEST_DIR (Not present)"
fi

# 2. Planned Actions Summary (PREVIEW / DRY-RUN)
echo -e "\n${YELLOW}+---------------------------------------------------------------+${NC}"
echo -e "${YELLOW}|                 UNINSTALL ACTIONS PREVIEW                     |${NC}"
echo -e "${YELLOW}+---------------------------------------------------------------+${NC}"

if [ "$running_daemons" = true ]; then
    echo -e "${WHITE} 1. Daemons     :${NC} Terminate active codex and node_repl background processes"
else
    echo -e " 1. Daemons     : No running daemons to terminate"
fi

if [ ${#installed_packages[@]} -gt 0 ]; then
    echo -e "${WHITE} 2. npm Packages:${NC} Uninstall global npm package(s): ${installed_packages[*]}"
else
    echo -e " 2. npm Packages: No global npm packages to uninstall"
fi

if [ "$KEEP_CONFIG" = true ]; then
    echo -e " 3. Config/State: Keep $CODEX_DIR (--keep-config specified)"
elif [ "$has_codex_dir" = true ]; then
    echo -e "${WHITE} 3. Config/State:${NC} Remove $CODEX_DIR (will offer final backup first)"
else
    echo -e " 3. Config/State: No configuration directory found"
fi

if [ "$has_test_dir" = true ]; then
    echo -e "${WHITE} 4. Test Folder :${NC} Offer to remove test workspace $TEST_DIR"
else
    echo -e " 4. Test Folder : No test workspace found"
fi
echo -e "${YELLOW}+---------------------------------------------------------------+${NC}\n"

if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}[DRY-RUN] No changes were made to your system. To execute uninstallation, run without --dry-run.${NC}"
    exit 0
fi

# 3. Explicit User Confirmation (Defaults to No)
if ! ask_approval "Are you sure you want to proceed with uninstallation and cleanup?" false; then
    echo -e "\n${YELLOW}[WARN] Uninstallation cancelled by user. No files or settings were modified.${NC}"
    exit 0
fi

# 4. Stop Daemons
if [ "$running_daemons" = true ]; then
    echo -e "\n${CYAN}[+] Stopping background daemons...${NC}"
    pkill -f "codex|node_repl" 2>/dev/null || true
    echo -e " ${GREEN}[OK]${NC} Terminated background daemons."
fi

# 5. Uninstall Global npm Packages
if [ ${#installed_packages[@]} -gt 0 ]; then
    echo -e "\n${CYAN}[+] Uninstalling global npm packages...${NC}"
    for pkg in "${installed_packages[@]}"; do
        echo -e " Running: npm uninstall -g $pkg"
        npm uninstall -g "$pkg" || echo -e " ${YELLOW}[WARN]${NC} Could not uninstall $pkg"
        echo -e " ${GREEN}[OK]${NC} Uninstalled $pkg"
    done
fi

# 6. Cleanup ~/.codex
if [ "$KEEP_CONFIG" = false ] && [ "$has_codex_dir" = true ]; then
    echo -e "\n${CYAN}[+] Cleaning up Codex configuration directory ($CODEX_DIR)...${NC}"
    if ask_approval "Create a final timestamped backup of $CODEX_DIR before deleting?" true; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        bak_dir="${CODEX_DIR}.bak.${timestamp}"
        cp -r "$CODEX_DIR" "$bak_dir"
        chmod 700 "$bak_dir" 2>/dev/null || true
        echo -e " ${GREEN}[OK]${NC} Backup created -> $bak_dir"
    fi
    rm -rf "$CODEX_DIR"
    echo -e " ${GREEN}[OK]${NC} Removed $CODEX_DIR"
fi

# 7. Cleanup Test Workspace
if [ "$has_test_dir" = true ]; then
    if ask_approval "Remove test workspace directory ($TEST_DIR)?" false; then
        rm -rf "$TEST_DIR"
        echo -e " ${GREEN}[OK]${NC} Removed test workspace: $TEST_DIR"
    else
        echo -e " [INFO] Preserved test workspace directory: $TEST_DIR"
    fi
fi

echo -e "\n${CYAN}=================================================================${NC}"
echo -e "${WHITE}  Uninstallation Complete!${NC}"
echo -e "${CYAN}  Your system is clean and ready for a fresh setup.${NC}"
echo -e "${CYAN}=================================================================${NC}"
exit 0
