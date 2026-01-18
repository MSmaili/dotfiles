#!/usr/bin/env bash

session="${1#❯ }"

# If session does not exist → exit silently
tmux has-session -t "$session" 2>/dev/null || exit 0

echo -e "\033[1mSession:\033[0m $session"
echo

echo -e "\033[1mWindows:\033[0m"
tmux list-windows -t "$session" -F "  - #{window_name} (#{window_panes} panes)"
echo

# Active window + pane
active_window=$(tmux display-message -p -t "$session" "#{window_name}")
active_pane=$(tmux display-message -p -t "$session" "#{pane_id}")   # ← MISSING
pane_path=$(tmux display-message -p -t "$active_pane" "#{pane_current_path}")

echo -e "\033[1mCurrent window:\033[0m $active_window"
echo -e "\033[1mPath:\033[0m     $pane_path"
echo
echo "----------------------------------------------"
echo ""

# Preview last 200 lines of active pane WITH COLORS
tmux capture-pane -p -e -t "$active_pane" -J -S -200

