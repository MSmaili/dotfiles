#!/usr/bin/env bash
set -euo pipefail

# Set HELPERS_DIR if not already set (for standalone execution)
HELPERS_DIR="${HELPERS_DIR:-$(cd "$(dirname "$0")" && pwd)}"

source "$HELPERS_DIR/utils.sh"

setup_ssh() (
	echo "🔐 Setting up SSH config..."

	if ! ask_yes_no "Import work SSH config from 1Password?"; then
		skip_with_message "Skipping work SSH config import."
		return 0
	fi

	if ! has op; then
		echo "⚠ 1Password CLI not installed. Install with: brew install --cask 1password-cli"
		return 1
	fi

	if ! op account list &>/dev/null; then
		echo "⚠ 1Password not signed in. Run 'eval \$(op signin)' first"
		return 1
	fi

	echo "Fetching SSH work config from 1Password..."
	if ${DRY_RUN:-false}; then
		echo "[DRY RUN] Would write the SSH_WORK_CONFIG document to ~/.ssh/config.work"
		return 0
	fi

	mkdir -p -m 700 "$HOME/.ssh" || return 1

	local tmp
	tmp=$(mktemp "$HOME/.ssh/config.work.XXXXXX") || return 1
	trap 'rm -f -- "$tmp"' EXIT
	trap 'exit 1' HUP INT TERM

	if op document get "SSH_WORK_CONFIG" >"$tmp" 2>/dev/null &&
		[[ ! -d "$HOME/.ssh/config.work" ]] &&
		mv -f -- "$tmp" "$HOME/.ssh/config.work"; then
		echo "✓ SSH work config imported from 1Password"
	else
		echo "⚠ Could not import SSH work config; existing config preserved"
		return 1
	fi
)

setup_ssh
