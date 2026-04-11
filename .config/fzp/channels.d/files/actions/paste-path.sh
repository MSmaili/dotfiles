#!/usr/bin/env bash
set -euo pipefail

path="${1:-}"
[[ -n "$path" ]] || exit 0

if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
	target="${FZP_TMUX_TARGET:-}"

	if [[ -z "$target" ]]; then
		target="$(tmux show -gv @fzp_target 2>/dev/null || true)"
	fi

	if [[ "$target" == "#"*"{"*"}"* ]]; then
		target=""
	fi

	if [[ -n "$target" ]] && tmux display-message -p -t "$target" '#{pane_id}' >/dev/null 2>&1; then
		tmux send-keys -t "$target" -l -- "$path" && exit 0
	fi

	tmux set-buffer -- "$path"
	tmux display-message "fzp: target pane not found, copied to tmux buffer"
	exit 0
fi

if command -v pbcopy >/dev/null 2>&1; then
	printf '%s' "$path" | pbcopy
fi

printf '%s\n' "$path"
