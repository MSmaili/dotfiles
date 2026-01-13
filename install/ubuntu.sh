#!/usr/bin/env bash
set -e

echo "🐧 Ubuntu setup..."
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/helpers/prompt.sh"

run_cmd sudo apt update
run_cmd sudo apt install -y git curl stow zsh

bash "$BASE_DIR/common.sh"
MISE_ENV=ubuntu mise install
bash "$BASE_DIR/cargo.sh"
