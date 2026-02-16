#!/usr/bin/env bash
set -u

file=$(fd --type f --hidden --exclude .git |
    fzf --height=100% \
        --layout=reverse \
        --border=sharp \
        --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}' \
        --preview-window=right:60%:hidden \
        --bind 'alt-p:toggle-preview' \
    ) || exit 0

tmux set-buffer -- "$file"
tmux paste-buffer
