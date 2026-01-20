#!/usr/bin/env bash
set -euo pipefail

source "$HELPERS_DIR/utils.sh"

echo "🧩 Applying macOS system settings..."

# Ensure running on macOS
[[ "$OSTYPE" == "darwin"* ]] || exit 0

###############################################################################
# Keyboard & Input
###############################################################################

# Disable input source switching with Ctrl+Space (conflicts with tmux)
run_cmd defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '<dict><key>enabled</key><false/></dict>'
run_cmd defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '<dict><key>enabled</key><false/></dict>'

# Key repeat improvements
run_cmd defaults write NSGlobalDomain KeyRepeat -int 2
run_cmd defaults write NSGlobalDomain InitialKeyRepeat -int 15
run_cmd defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

###############################################################################
# Finder
###############################################################################
# Show hidden files by default
# defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar and status bar
run_cmd defaults write com.apple.finder ShowPathbar -bool true
run_cmd defaults write com.apple.finder ShowStatusBar -bool true
# Show all file extensions
run_cmd defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show full POSIX path in Finder title bar
run_cmd defaults write com.apple.finder _FXShowPosixPathInTitle -bool false

# Disable .DS_Store files on network & USB volumes
run_cmd defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
run_cmd defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Set list view as the default view
run_cmd defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Keep folders on top when sorting by name
run_cmd defaults write com.apple.finder _FXSortFoldersFirst -bool true
# Search current folder by default
run_cmd defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

###############################################################################
# Dock
###############################################################################

# Auto-hide Dock and speed up hide/show delay
run_cmd defaults write com.apple.dock autohide -bool true
run_cmd defaults write com.apple.dock autohide-delay -float 0
run_cmd defaults write com.apple.dock autohide-time-modifier -float 0.3

# Minimize windows into app icon
run_cmd defaults write com.apple.dock minimize-to-application -bool false


###############################################################################
# Tracpad
###############################################################################
# Trackpad: enable tap to click for this user and for the login screen
run_cmd defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
run_cmd defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
run_cmd defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Disable "natural" (Lion-style) scrolling
run_cmd defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

###############################################################################
# Apply changes
###############################################################################

run_cmd killall Dock Finder SystemUIServer &>/dev/null || true

echo "✅ macOS settings applied!"
