#!/usr/bin/env bash
set -euo pipefail

source "$HELPERS_DIR/utils.sh"

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
    cd "$DOTFILES_DIR"
    # Backup real files (not symlinks) that would conflict
    conflicts=$(stow -nRt "$HOME" . 2>&1 | grep "existing target" | awk '{print $NF}' || true)
    if [[ -n "$conflicts" ]]; then
        backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        echo "📦 Backing up conflicting files to $backup_dir"
        echo "$conflicts" | while read -r f; do
            mkdir -p "$backup_dir/$(dirname "$f")"
            mv "$HOME/$f" "$backup_dir/$f"
        done
    fi
    run_cmd stow -Rt "$HOME" .
else
    echo "⚠️ stow not installed, skipping linking."
fi

echo "✅ Common setup complete!"
