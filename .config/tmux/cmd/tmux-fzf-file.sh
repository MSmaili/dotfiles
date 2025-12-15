#!/usr/bin/env bash
set -u

# Run fzf in popup
file=$(fzf --height=100% \
        --ansi \
        --layout=reverse \
        --border=sharp \
        --padding=0 \
        --preview  \
        --margin=0 \
        --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}' \
        --preview-window=right:60%:hidden \
    ) || exit 0

# Put result in tmux buffer
tmux set-buffer -- "$file"

# Paste buffer into the pane that opened the popup
tmux paste-buffer
