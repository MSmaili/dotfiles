#!/usr/bin/env bash
set -e

echo "🍎 macOS setup..."

ensure_brew_installed
brew_bundle_install

bash "$INSTALL_DIR/common.sh"

if ask_yes_no "Set macOS settings?"; then
    bash "$HELPERS_DIR/macos_settings.sh"
else
    skip_with_message "Skipping macOS settings."
fi
