#!/usr/bin/env bash
set -euo pipefail

# Remove the staging directory. Called explicitly on every exit path.
# An EXIT trap is wrong here: this file is sourced, so the trap would fire at
# shell exit rather than at function return, and it would also replace any
# trap the calling script had already set.
_sonarlint_cleanup() {
    [[ -n "${1:-}" ]] && rm -rf "$1"
    return 0
}

# Report the reason, clean up, and fail.
_sonarlint_fail() {
    local tmp="$1"
    shift
    echo "$*" >&2
    _sonarlint_cleanup "$tmp"
    return 1
}

install_sonarlint() {
    if [[ -x "$HOME/.local/bin/sonarlint-language-server" ]]; then
        echo "✓ SonarLint already installed"
        return 0
    fi

    local base="$HOME/.local/opt/sonarlint"
    local bin="$HOME/.local/bin"
    local tmp
    tmp="$(mktemp -d)"

    echo "📦 Fetching latest SonarLint version..."

    # Detect platform
    local os arch platform=""
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os-$arch" in
        darwin-arm64) platform="darwin-arm64" ;;
        darwin-x86_64) platform="darwin-x64" ;;
        linux-x86_64) platform="linux-x64" ;;
    esac

    # Get latest release from GitHub
    local release_url="https://api.github.com/repos/SonarSource/sonarlint-vscode/releases/latest"
    local release_data
    if ! release_data="$(curl -fsSL "$release_url")"; then
        _sonarlint_fail "$tmp" "Failed to query the SonarLint release API"
        return 1
    fi

    local asset="" download_url asset_name
    if [[ -n "$platform" ]]; then
        asset=$(echo "$release_data" | jq -r ".assets[] | select(.name | contains(\"$platform\")) | {url: .browser_download_url, name: .name}")
    fi

    # Fallback to universal
    if [[ -z "$asset" || "$asset" == "null" ]]; then
        asset=$(echo "$release_data" | jq -r '.assets[] | select(.name | test("^sonarlint-vscode-[0-9].*\\.vsix$")) | {url: .browser_download_url, name: .name}')
    fi

    download_url=$(echo "$asset" | jq -r '.url')
    asset_name=$(echo "$asset" | jq -r '.name')

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        _sonarlint_fail "$tmp" "Failed to find SonarLint release"
        return 1
    fi

    # Get SHA256 from release body
    local expected_sha
    expected_sha=$(echo "$release_data" | jq -r --arg name "$asset_name" '.body | split("\n") | .[] | select(contains($name)) | split("\n")[1] | gsub("sha256:"; "") | gsub(" "; "")')

    echo "📦 Downloading SonarLint ($asset_name)..."
    if ! curl -fsSL "$download_url" -o "$tmp/sonarlint.vsix"; then
        _sonarlint_fail "$tmp" "Failed to download $asset_name"
        return 1
    fi

    # Verify checksum if available
    if [[ -n "$expected_sha" && "$expected_sha" != "null" ]]; then
        echo "🔐 Verifying checksum..."
        local actual_sha
        actual_sha=$(shasum -a 256 "$tmp/sonarlint.vsix" | awk '{print $1}')
        if [[ "$actual_sha" != "$expected_sha" ]]; then
            _sonarlint_fail "$tmp" "Checksum mismatch!"
            return 1
        fi
        echo "✓ Checksum verified"
    fi

    # Verify valid zip
    if ! unzip -t "$tmp/sonarlint.vsix" &>/dev/null; then
        _sonarlint_fail "$tmp" "Downloaded file is not a valid VSIX"
        return 1
    fi

    mkdir -p "$base" "$bin"
    rm -rf "$base/current"
    if ! unzip -q "$tmp/sonarlint.vsix" -d "$base/current"; then
        _sonarlint_fail "$tmp" "Failed to extract $asset_name"
        return 1
    fi

    # Create wrapper script
    cat > "$bin/sonarlint-language-server" << 'EOF'
#!/usr/bin/env sh
exec java -jar "$HOME/.local/opt/sonarlint/current/extension/server/sonarlint-ls.jar" "$@"
EOF
    chmod +x "$bin/sonarlint-language-server"

    _sonarlint_cleanup "$tmp"
    echo "✅ SonarLint Language Server installed."
}
