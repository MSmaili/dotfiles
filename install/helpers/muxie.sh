#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/prompt.sh"

install_muxie() {
    if has go; then
        echo "📦 Installing muxie..."
        run_cmd go install github.com/MSmaili/muxie@latest
        echo "✅ muxie installed."
    else
        echo "⚠️ Go not found, skipping muxie installation."
    fi
}
