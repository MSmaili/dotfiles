#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/helpers/zsh.sh"
source "$BASE_DIR/helpers/tmux.sh"
source "$BASE_DIR/helpers/mise.sh"
source "$BASE_DIR/helpers/muxie.sh"

run_cmd mkdir -p ~/.config/zsh ~/.config/tmux

install_zsh
install_tmux_plugins
if ask_yes_no "Install/update mise?"; then
    install_mise_languages
    install_muxie
else
    skip_with_message "Skipping Mise installation."
fi

if has stow; then
    echo "🔗 Linking dotfiles..."
    cd "$BASE_DIR/.."
    run_cmd stow -vSt "$HOME" .
else
    echo "⚠️ stow not installed, skipping linking."
fi

echo "✅ Common setup complete!"
