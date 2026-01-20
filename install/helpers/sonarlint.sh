#!/usr/bin/env bash
set -eu

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
    release_data=$(curl -fsSL "$release_url")
    
    local asset download_url asset_name
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
        echo "Failed to find SonarLint release" >&2
        rm -rf "$tmp"
        return 1
    fi

    # Get SHA256 from release body
    local expected_sha
    expected_sha=$(echo "$release_data" | jq -r --arg name "$asset_name" '.body | split("\n") | .[] | select(contains($name)) | split("\n")[1] | gsub("sha256:"; "") | gsub(" "; "")')

    echo "📦 Downloading SonarLint ($asset_name)..."
    curl -fsSL "$download_url" -o "$tmp/sonarlint.vsix"

    # Verify checksum if available
    if [[ -n "$expected_sha" && "$expected_sha" != "null" ]]; then
        echo "🔐 Verifying checksum..."
        local actual_sha
        actual_sha=$(shasum -a 256 "$tmp/sonarlint.vsix" | awk '{print $1}')
        if [[ "$actual_sha" != "$expected_sha" ]]; then
            echo "Checksum mismatch!" >&2
            rm -rf "$tmp"
            return 1
        fi
        echo "✓ Checksum verified"
    fi

    # Verify valid zip
    if ! unzip -t "$tmp/sonarlint.vsix" &>/dev/null; then
        echo "Downloaded file is not a valid VSIX" >&2
        rm -rf "$tmp"
        return 1
    fi

    mkdir -p "$base" "$bin"
    rm -rf "$base/current"
    unzip -q "$tmp/sonarlint.vsix" -d "$base/current"

    # Create wrapper script
    cat > "$bin/sonarlint-language-server" << 'EOF'
#!/usr/bin/env sh
exec java -jar "$HOME/.local/opt/sonarlint/current/extension/server/sonarlint-ls.jar" "$@"
EOF
    chmod +x "$bin/sonarlint-language-server"

    rm -rf "$tmp"
    echo "✅ SonarLint Language Server installed."
}
