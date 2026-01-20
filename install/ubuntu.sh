#!/usr/bin/env bash
set -e

echo "🐧 Ubuntu setup..."

run_cmd sudo apt update
run_cmd sudo apt install -y git curl stow zsh unzip

export MISE_ENV=ubuntu

bash "$INSTALL_DIR/common.sh"
