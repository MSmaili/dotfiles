#!/usr/bin/env bash
# Register Vicinae script commands.
#
# Vicinae scans ~/.local/share/vicinae/scripts/ by default. Rather than
# adding a new symlink for each script by hand, this helper auto-links
# every executable in ~/.config/scripts/ that carries a `@vicinae.`
# directive in its header, plus the shared `assets/` folder that holds
# their icons.
#
# Idempotent: safe to run repeatedly. Skips silently if Vicinae is not
# installed on the current host.

# Resolve our own location from BASH_SOURCE, not $0: this file is *sourced*,
# so $0 is the calling shell (e.g. "bash") and dirname would give the caller's
# cwd — which made the documented `source install/helpers/vicinae.sh` fail to
# find utils.sh, then no-op while still exiting 0.
HELPERS_DIR="${HELPERS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck disable=SC1091
source "$HELPERS_DIR/utils.sh"

link_vicinae_scripts() {
    if ! has vicinae; then
        skip_with_message "Vicinae not installed, skipping script registration."
        return 0
    fi

    local scripts_src="$HOME/.config/scripts"
    local vicinae_dir="$HOME/.local/share/vicinae/scripts"

    if [[ ! -d "$scripts_src" ]]; then
        skip_with_message "$scripts_src does not exist yet, skipping Vicinae linking."
        return 0
    fi

    echo "🔗 Registering Vicinae script commands from $scripts_src..."
    run_cmd mkdir -p "$vicinae_dir"

    # Shared assets folder (icons for all scripts). One symlink covers
    # every current and future icon dropped into ~/.config/scripts/assets.
    if [[ -d "$scripts_src/assets" ]]; then
        # `ln -sfn` would create assets/assets if the destination is a real
        # directory rather than a symlink, so handle that case explicitly.
        if [[ -d "$vicinae_dir/assets" && ! -L "$vicinae_dir/assets" ]]; then
            skip_with_message "$vicinae_dir/assets is a real directory, leaving it alone."
        else
            run_cmd ln -sfn "$scripts_src/assets" "$vicinae_dir/assets"
        fi
    fi

    # Drop symlinks pointing at scripts that no longer exist (renamed or
    # deleted). Only dangling symlinks are touched; real files and live
    # links placed here by hand are left alone.
    local stale
    for stale in "$vicinae_dir"/*; do
        if [[ -L "$stale" && ! -e "$stale" ]]; then
            echo "   Removing stale link: $(basename "$stale")"
            run_cmd rm -f "$stale"
        fi
    done

    # Link every executable script whose header contains a `@vicinae.`
    # directive. Non-Vicinae scripts (ksnap, marpp, etc.) are left alone.
    local linked=0
    local script
    for script in "$scripts_src"/*; do
        [[ -f "$script" && -x "$script" ]] || continue
        if head -n 20 "$script" 2>/dev/null | grep -q '@vicinae\.'; then
            run_cmd ln -sfn "$script" "$vicinae_dir/$(basename "$script")"
            linked=$((linked + 1))
        fi
    done

    if (( linked > 0 )); then
        echo "✅ Linked $linked Vicinae script(s)."
        echo "   Run 'Reload Script Directories' in Vicinae (or 'vicinae server --replace') to pick them up."
    else
        skip_with_message "No scripts with @vicinae.* directives found."
    fi
}
