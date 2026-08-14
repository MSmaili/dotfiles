#!/usr/bin/env bash
set -euo pipefail

echo "🎩 Fedora setup..."

run_cmd sudo dnf install -y git curl stow zsh unzip

bash "$INSTALL_DIR/common.sh"
