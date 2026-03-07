#!/usr/bin/env bash
set -e

# Set HELPERS_DIR if not already set (for standalone execution)
HELPERS_DIR="${HELPERS_DIR:-$(cd "$(dirname "$0")" && pwd)}"

source "$HELPERS_DIR/utils.sh"

setup_ssh() {
    echo "🔐 Setting up SSH config..."

    if ask_yes_no "Import work SSH config from 1Password?"; then
        if has op; then
            if op account list &> /dev/null 2>&1; then
                echo "Fetching SSH work config from 1Password..."
                if op document get "SSH_WORK_CONFIG" > ~/.ssh/config.work 2>/dev/null; then
                    run_cmd chmod 600 ~/.ssh/config.work
                    echo "✓ SSH work config imported from 1Password"
                else
                    echo "⚠ Could not fetch SSH work config from 1Password"
                fi
            else
                echo "⚠ 1Password not signed in. Run 'op signin' first"
            fi
        else
            echo "⚠ 1Password CLI not installed. Install with: brew install --cask 1password-cli"
        fi
    else
        skip_with_message "Skipping work SSH config import."
    fi
}

setup_ssh
