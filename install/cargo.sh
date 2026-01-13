#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v cargo >/dev/null || exit 1
command -v cargo-binstall >/dev/null || cargo install cargo-binstall

cargo binstall -y $(cat "$BASE_DIR/helpers/cargo-tools")
