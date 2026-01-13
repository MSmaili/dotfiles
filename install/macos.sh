#!/usr/bin/env bash
set -e

echo "🎩 Macos setup..."
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/helpers/brew.sh"

ensure_brew_installed
brew_bundle_install "$BASE_DIR/Brewfile"

bash "$BASE_DIR/../common.sh"
bash "$BASE_DIR/../cargo.sh"

if  ask_yes_no "Set macos_settings?"; then
    bash "$BASE_DIR/macos_settings.sh"
else
    skip_with_message "Skipping default macos_settings."
fi
