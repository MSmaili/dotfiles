#!/usr/bin/env bash
set -euo pipefail

# Global paths - exported for all scripts
export DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
export INSTALL_DIR="$DOTFILES_DIR/install"
export HELPERS_DIR="$INSTALL_DIR/helpers"

# Parse flags
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
export DRY_RUN

if $DRY_RUN; then
    echo "🔍 DRY RUN MODE - No changes will be made"
fi

echo "🚀 Setting up dotfiles..."

source "$HELPERS_DIR/utils.sh"

OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
    DISTRO="macos"
elif [[ "$OS" == "Linux" ]]; then
    if command -v apt &>/dev/null; then
        DISTRO="ubuntu"
    elif command -v dnf &>/dev/null; then
        DISTRO="fedora"
    else
        echo "❌ Unsupported Linux distribution"
        echo "Supported: Ubuntu (apt), Fedora (dnf)"
        exit 1
    fi
else
    echo "❌ Unsupported OS"
    exit 1
fi

if [[ -f "$INSTALL_DIR/$DISTRO.sh" ]]; then
    source "$INSTALL_DIR/$DISTRO.sh"
fi

if has bat; then
    echo "Clearing bat cache..."
    run_cmd bat cache --clear
fi

echo "✅ All done!"
