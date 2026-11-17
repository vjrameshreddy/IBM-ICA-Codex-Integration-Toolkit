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

# ask_approval PROMPT [default_yes=false] [explicit=false]
# explicit=true prompts (software that may predate the setup) are never auto-approved by --yes.
ask_approval() {
    local prompt="$1"
    local default_yes="${2:-false}"
    local explicit="${3:-false}"
    local response=""
    if [ "$ASSUME_YES" = true ]; then
        if [ "$explicit" = true ]; then return 1; fi
        return 0
    fi
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
TEST_DIR="$HOME/codex-ica-test"
NPM_GLOBAL_DIR="$HOME/.npm-global"
ZSHRC_FILE="$HOME/.zshrc"
# Exact line the setup script appends to ~/.zshrc
ZSHRC_PATH_LINE='export PATH="$HOME/.npm-global/bin:$PATH"'

# Prerequisites the setup script can install via Homebrew (keep in sync with setup-codex-ica.sh)
BREW_FORMULAE=(git gh node python)

echo -e "\n${CYAN}[+] Inspecting current Codex installation state...${NC}"

# Check running daemons (exact process names; a substring match would also hit this script)
running_daemons=false
if pgrep -x codex >/dev/null 2>&1 || pgrep -x node_repl >/dev/null 2>&1; then
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

# Check npm user prefix and ~/.zshrc PATH line added by the setup
has_npm_prefix=false
if command -v npm >/dev/null 2>&1 && [ "$(npm config get prefix 2>/dev/null || true)" = "$NPM_GLOBAL_DIR" ]; then
    has_npm_prefix=true
fi
has_zshrc_line=false
if [ -f "$ZSHRC_FILE" ] && grep -qxF "$ZSHRC_PATH_LINE" "$ZSHRC_FILE"; then
    has_zshrc_line=true
fi
if [ "$has_npm_prefix" = true ] || [ "$has_zshrc_line" = true ]; then
    echo -e " ${YELLOW}[INFO]${NC} npm user prefix setup  : prefix=$has_npm_prefix, ~/.zshrc PATH line=$has_zshrc_line"
else
    echo -e " [INFO] npm user prefix setup  : Not present"
fi

# Check prerequisites installed through Homebrew (read-only query)
installed_prereqs=()
if command -v brew >/dev/null 2>&1; then
    for formula in "${BREW_FORMULAE[@]}"; do
        if brew list --versions "$formula" >/dev/null 2>&1; then installed_prereqs+=("$formula"); fi
    done
    if [ ${#installed_prereqs[@]} -gt 0 ]; then
        echo -e " ${YELLOW}[INFO]${NC} Prerequisites (brew)   : ${installed_prereqs[*]}"
    else
        echo -e " [INFO] Prerequisites (brew)   : None installed via Homebrew"
    fi
else
    echo -e " [INFO] Prerequisites (brew)   : Homebrew not available"
fi

# 2. Planned Actions Summary (PREVIEW / DRY-RUN)
echo -e "\n${YELLOW}+---------------------------------------------------------------+${NC}"
echo -e "${YELLOW}|                 UNINSTALL ACTIONS PREVIEW                     |${NC}"
echo -e "${YELLOW}+---------------------------------------------------------------+${NC}"
echo -e " Each item below is confirmed individually before it is removed."

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
    echo -e "${WHITE} 3. Config/State:${NC} Remove $CODEX_DIR (will offer final owner-only backup first)"
else
    echo -e " 3. Config/State: No configuration directory found"
fi

if [ "$has_test_dir" = true ]; then
    echo -e "${WHITE} 4. Test Folder :${NC} Offer to remove test workspace $TEST_DIR"
else
    echo -e " 4. Test Folder : No test workspace found"
fi

if [ "$has_npm_prefix" = true ] || [ "$has_zshrc_line" = true ]; then
    echo -e "${WHITE} 5. npm prefix  :${NC} Offer to revert the npm user prefix and remove the PATH line from ~/.zshrc"
else
    echo -e " 5. npm prefix  : Nothing to revert"
fi

if [ ${#installed_prereqs[@]} -gt 0 ]; then
    echo -e "${WHITE} 6. Prerequisites:${NC} Offer to uninstall via brew (default No, never auto-approved): ${installed_prereqs[*]}"
    echo -e "                    Other software may depend on these tools."
else
    echo -e " 6. Prerequisites: No Homebrew-installed prerequisites found"
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
    if ask_approval "Stop running codex/node_repl processes?" true; then
        echo -e "\n${CYAN}[+] Stopping background daemons...${NC}"
        pkill -x codex 2>/dev/null || true
        pkill -x node_repl 2>/dev/null || true
        echo -e " ${GREEN}[OK]${NC} Terminated background daemons."
    else
        echo -e " [INFO] Left background daemons running."
    fi
fi

# 5. Uninstall Global npm Packages (before Node.js, which provides npm, may be removed)
for pkg in "${installed_packages[@]+"${installed_packages[@]}"}"; do
    if ask_approval "Uninstall global npm package $pkg?" true; then
        echo -e "\n${CYAN}[+] Uninstalling $pkg...${NC}"
        echo -e " Running: npm uninstall -g $pkg"
        if npm uninstall -g "$pkg"; then
            echo -e " ${GREEN}[OK]${NC} Uninstalled $pkg"
        else
            echo -e " ${YELLOW}[WARN]${NC} Could not uninstall $pkg"
        fi
    else
        echo -e " [INFO] Kept $pkg"
    fi
done

# 6. Cleanup ~/.codex
if [ "$KEEP_CONFIG" = false ] && [ "$has_codex_dir" = true ]; then
    if ask_approval "Remove Codex configuration directory $CODEX_DIR (config.toml, model catalog, .env)?" true; then
        echo -e "\n${CYAN}[+] Cleaning up Codex configuration directory ($CODEX_DIR)...${NC}"
        if ask_approval "Create a final timestamped backup of $CODEX_DIR before deleting?" true; then
            timestamp=$(date +"%Y%m%d_%H%M%S")
            bak_dir="${CODEX_DIR}.bak.${timestamp}"
            # Restrictive umask so the backup (which can hold ICA_API_KEY in .env) is never group/world readable.
            ( umask 077; cp -r "$CODEX_DIR" "$bak_dir" )
            chmod -R go-rwx "$bak_dir" 2>/dev/null || true
            chmod 700 "$bak_dir" 2>/dev/null || true
            echo -e " ${GREEN}[OK]${NC} Backup created (owner-only) -> $bak_dir"
        fi
        rm -rf "$CODEX_DIR"
        echo -e " ${GREEN}[OK]${NC} Removed $CODEX_DIR"
    else
        echo -e " [INFO] Kept $CODEX_DIR"
    fi
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

# 8. Revert npm user prefix and ~/.zshrc PATH line (added by the setup script)
if [ "$has_npm_prefix" = true ]; then
    if ask_approval "Revert npm user prefix (npm config delete prefix; was set to $NPM_GLOBAL_DIR)?" true; then
        if npm config delete prefix; then
            echo -e " ${GREEN}[OK]${NC} Removed npm prefix setting (the $NPM_GLOBAL_DIR directory itself was left in place)"
        else
            echo -e " ${YELLOW}[WARN]${NC} Could not remove the npm prefix setting"
        fi
    else
        echo -e " [INFO] Kept npm user prefix"
    fi
fi
if [ "$has_zshrc_line" = true ]; then
    if ask_approval "Remove the npm-global PATH line from $ZSHRC_FILE?" true; then
        zshrc_backup="${ZSHRC_FILE}.bak.$(date +"%Y%m%d_%H%M%S")"
        cp "$ZSHRC_FILE" "$zshrc_backup"
        grep -vxF "$ZSHRC_PATH_LINE" "$ZSHRC_FILE" > "${ZSHRC_FILE}.tmp.$$" || true
        cat "${ZSHRC_FILE}.tmp.$$" > "$ZSHRC_FILE"
        rm -f "${ZSHRC_FILE}.tmp.$$"
        echo -e " ${GREEN}[OK]${NC} Removed PATH line from $ZSHRC_FILE (backup -> $zshrc_backup)"
    else
        echo -e " [INFO] Kept $ZSHRC_FILE unchanged"
    fi
fi

# 9. Prerequisites installed by the setup via Homebrew (explicit interactive confirmation only)
if [ ${#installed_prereqs[@]} -gt 0 ]; then
    echo -e "\n${CYAN}[+] Prerequisites installed via Homebrew...${NC}"
    if [ "$ASSUME_YES" = true ]; then
        echo -e " [INFO] Skipped: prerequisite removal requires interactive confirmation (--yes never approves it)."
    else
        echo -e " ${YELLOW}[WARN]${NC} These tools may have been installed before this setup, and other software may depend on them."
        for formula in "${installed_prereqs[@]}"; do
            if ask_approval "Uninstall $formula via brew?" false true; then
                echo -e " Running: brew uninstall $formula"
                if brew uninstall "$formula"; then
                    echo -e " ${GREEN}[OK]${NC} Uninstalled $formula"
                else
                    echo -e " ${YELLOW}[WARN]${NC} brew could not uninstall $formula"
                fi
            else
                echo -e " [INFO] Kept $formula"
            fi
        done
    fi
fi

echo -e "\n${CYAN}=================================================================${NC}"
echo -e "${WHITE}  Uninstallation Complete!${NC}"
echo -e "${CYAN}  Items you approved were removed; everything else was left untouched.${NC}"
echo -e "${CYAN}=================================================================${NC}"
exit 0
