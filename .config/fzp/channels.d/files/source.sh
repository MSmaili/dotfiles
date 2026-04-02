#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${FZP_SCOPE_FILE:-}" && -f "${FZP_SCOPE_FILE}" ]]; then
  if command -v devicon-lookup >/dev/null 2>&1; then
    sort -u "$FZP_SCOPE_FILE" | \
      devicon-lookup | \
      awk '{ icon=$1; $1=""; sub(/^ /, ""); print icon"\t"$0 }'
    exit 0
  fi

  sort -u "$FZP_SCOPE_FILE" | awk '{ print "  \t"$0 }'
  exit 0
fi

if command -v devicon-lookup >/dev/null 2>&1; then
  fd --type f --hidden --follow --exclude .git | \
    devicon-lookup | \
    awk '{ icon=$1; $1=""; sub(/^ /, ""); print icon"\t"$0 }'
  exit 0
fi

fd --type f --hidden --follow --exclude .git | awk '{ print "  \t"$0 }'
