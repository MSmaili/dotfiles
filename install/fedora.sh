#!/usr/bin/env bash
set -e

echo "🎩 Fedora setup..."

run_cmd sudo dnf install -y git curl stow zsh unzip

export MISE_ENV=ubuntu

bash "$INSTALL_DIR/common.sh"
