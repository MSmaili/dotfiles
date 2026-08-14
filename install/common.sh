#!/usr/bin/env bash
set -euo pipefail

source "$HELPERS_DIR/utils.sh"
source "$HELPERS_DIR/pi-agent.sh"

run_cmd mkdir -p ~/.config/zsh ~/.config/tmux

install_zsh
install_tmux_plugins

if ask_yes_no "Install/update mise?"; then
    install_mise
else
    skip_with_message "Skipping Mise installation."
fi

if ask_yes_no "Install/update SonarLint?"; then
    source "$HELPERS_DIR/sonarlint.sh"
    install_sonarlint
else
    skip_with_message "Skipping SonarLint installation."
fi

if has stow; then
    echo "🔗 Linking dotfiles..."
    prepare_pi_agent
    run_cmd stow \
        --dir="$DOTFILES_DIR" \
        --target="$HOME" \
        --restow \
        --verbose \
        .
else
    echo "⚠️ stow not installed, skipping linking."
fi

echo "✅ Common setup complete!"
