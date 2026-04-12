#!/usr/bin/env bash
set -euo pipefail

HELPERS_DIR="${HELPERS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "$HELPERS_DIR/utils.sh"

VAULTS_REPO_DIR="${VAULTS_REPO_DIR:-$HOME/.vaults}"
VAULTS_REPO_URL="${VAULTS_REPO_URL:-git@github.com:msmaili/.vaults.git}"
VAULT_KEYS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/smaili/vaults"

OP_PUBLIC_DOC="${SMAILI_VAULTS_PUBLIC_DOC:-SMAILI_VAULTS_PUBLIC_KEY}"
OP_PRIVATE_DOC="${SMAILI_VAULTS_PRIVATE_DOC:-SMAILI_VAULTS_PRIVATE_KEY}"

ensure_vault_repo() {
    echo "📚 Setting up vault repository..."

    if [[ ! -d "$VAULTS_REPO_DIR/.git" ]]; then
        run_cmd git clone "$VAULTS_REPO_URL" "$VAULTS_REPO_DIR"
    else
        run_cmd git -C "$VAULTS_REPO_DIR" pull --rebase
    fi
}

hydrate_keys_from_1password() {
    if ! has op; then
        return 1
    fi

    if ! op account list &>/dev/null; then
        return 1
    fi

    local public_key
    local private_key

    public_key="$(op document get "$OP_PUBLIC_DOC" 2>/dev/null || true)"
    private_key="$(op document get "$OP_PRIVATE_DOC" 2>/dev/null || true)"

    if [[ -z "$public_key" || -z "$private_key" ]]; then
        return 1
    fi

    run_cmd mkdir -p "$VAULT_KEYS_DIR"
    printf "%s\n" "$public_key" >"$VAULT_KEYS_DIR/public_key.txt"
    printf "%s\n" "$private_key" >"$VAULT_KEYS_DIR/private_key.txt"
    run_cmd chmod 600 "$VAULT_KEYS_DIR/public_key.txt" "$VAULT_KEYS_DIR/private_key.txt"

    echo "✓ Vault keys synced from 1Password"
    return 0
}

ensure_vault_keys() {
    echo "🔐 Ensuring vault key material..."

    if hydrate_keys_from_1password; then
        return 0
    fi

    if [[ -f "$VAULT_KEYS_DIR/public_key.txt" && -f "$VAULT_KEYS_DIR/private_key.txt" ]]; then
        echo "✓ Using local fallback key files from $VAULT_KEYS_DIR"
        return 0
    fi

    echo "⚠ Could not load keys from 1Password and fallback files are missing"
    echo "Expected files:"
    echo "  $VAULT_KEYS_DIR/public_key.txt"
    echo "  $VAULT_KEYS_DIR/private_key.txt"
    return 1
}

setup_vault_hooks_and_pull() {
    echo "🧩 Configuring vault hooks and decrypting notes..."
    run_cmd make -C "$VAULTS_REPO_DIR" hooks
    run_cmd make -C "$VAULTS_REPO_DIR" pull
}

main() {
    if ! ask_yes_no "Setup/update encrypted vault at $VAULTS_REPO_DIR?" "Y"; then
        skip_with_message "Skipping vault setup."
        return 0
    fi

    ensure_vault_repo
    ensure_vault_keys
    setup_vault_hooks_and_pull

    echo "✅ Vault setup complete"
}

main
