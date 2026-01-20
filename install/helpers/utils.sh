#!/usr/bin/env bash
# Utility functions for dotfiles installation
# Requires: DOTFILES_DIR, INSTALL_DIR, HELPERS_DIR exported from install.sh

#----------------------------------
# Core utilities
#----------------------------------
run_cmd() {
    if ${DRY_RUN:-false}; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

has() { command -v "$1" &>/dev/null; }

ask_yes_no() {
    local message="$1"
    local default="${2:-N}"

    if ${DRY_RUN:-false}; then
        echo "[DRY RUN] Would prompt: $message"
        return 0
    fi

    if [[ "$default" == "Y" ]]; then
        read -p "$message (Y/n): " -n 1 -r
    else
        read -p "$message (y/N): " -n 1 -r
    fi
    echo

    if [[ "$default" == "Y" ]]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

skip_with_message() {
    echo "⏭️ $1"
}

#----------------------------------
# Homebrew (macOS)
#----------------------------------
ensure_brew_installed() {
    if ! has brew; then
        echo "📦 Installing Homebrew..."
        if ! ask_yes_no "Continue?"; then
            skip_with_message "Skipping Homebrew installation."
            return 0
        fi
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
}

brew_bundle_install() {
    if has brew; then
        echo "📋 Installing packages from Brewfile..."
        run_cmd brew bundle --file="$HELPERS_DIR/Brewfile"
    else
        skip_with_message "Skipping Brewfile (Homebrew not available)."
    fi
}

#----------------------------------
# Zsh
#----------------------------------
install_zsh() {
    echo "🐚 Setting up Zsh..."

    if ! has zsh; then
        echo "Zsh is not installed. Please install it first."
        return 1
    fi

    local zsh_path
    zsh_path=$(which zsh)

    if [[ "$SHELL" == "$zsh_path" ]]; then
        echo "✓ Zsh is already your default shell."
        return 0
    fi

    if ! grep -q "^$zsh_path$" /etc/shells; then
        echo "$zsh_path" | run_cmd sudo tee -a /etc/shells >/dev/null
    fi

    run_cmd chsh -s "$zsh_path"
    echo "✅ Zsh set as default shell."
}

#----------------------------------
# Tmux
#----------------------------------
install_tmux_plugins() {
    local tpm_dir="$HOME/.config/tmux/plugins/tpm"
    if [[ ! -d "$tpm_dir" ]]; then
        echo "🔧 Installing Tmux Plugin Manager..."
        run_cmd git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    fi
}

#----------------------------------
# Mise
#----------------------------------
install_mise() {
    if ! has mise; then
        echo "📦 Installing mise..."
        run_cmd curl -fsSL https://mise.run | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Activate mise
    eval "$(mise activate bash)"

    # Trust config if exists
    if [[ -f "$HOME/.config/mise/config.toml" ]]; then
        mise trust "$HOME/.config/mise/config.toml" &>/dev/null || true
    fi

    echo "📦 Installing tools from mise config..."
    run_cmd mise install

    echo "✅ mise installation complete."
}
