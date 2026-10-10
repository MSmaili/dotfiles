# Mimi

Native macOS Spaces with yabai-style BSP and overlapping stacks. SIP stays enabled.

GitHub: https://github.com/y3owk1n/mimi

## Install

```sh
brew install --cask y3owk1n/tap/mimi jackielii/tap/skhd-zig
```

1. Link this directory to `~/.config/mimi` using your dotfiles/Stow setup.
   Python 3 must be available on Mimi's service PATH; Space history uses
   `/usr/bin/python3`. Adjust `settings.service_path` for another machine.
2. Grant **Mimi and skhd Accessibility** in System Settings → Privacy & Security.
   If terminal commands are denied, check the terminal's permission too.
3. Create nine native Spaces. Disable automatic Space reordering and enable
   separate Spaces per display in Mission Control. Disable any native
   Option+1–9 shortcuts that conflict with skhd.
4. Stop other window managers and disable their login startup. Do not run
   yabai, AeroSpace, or Dinky alongside Mimi.
5. Load only Mimi from `~/.config/skhd/skhdrc`:

   ```text
   .load "../mimi/skhdrc"
   ```

Validate and enable both services at login:

```sh
mimi config validate
mimi services install
skhd --start-service
/usr/bin/python3 -B ~/.config/mimi/space_history.py sync
```

## Shortcuts

| Shortcut                 | Action                                                    |
| ------------------------ | --------------------------------------------------------- |
| Option+H/J/K/L           | Focus left/down/up/right; cycle windows in a stack        |
| Option+Shift+H/J/K/L     | Swap windows / reorder stack                              |
| Option+1–9               | Switch Space                                              |
| Option+Shift+1–9         | Move window and follow                                    |
| Option+Tab               | Toggle between the last two visited Spaces                |
| Control+Shift+Left/Right | Move window to previous/next Space and follow             |
| Option+B                 | BSP tiling                                                |
| Option+S                 | Stack: windows fill the same area, overlapping exactly    |
| Option+E                 | Toggle split of the focused window: vertical ↔ horizontal |
| Option+T                 | Float and center at half-size; repeat to tile             |
| Option+F                 | Fill current Space; repeat to restore tiling              |
| Option+Shift+P/O         | Move window to next/previous display                      |

Cmd+Tab, Cmd+H, and Ctrl+Left/Right remain native. There are no shortcut modes.
Option+F is zoom within the current Space, not macOS fullscreen; it applies to
tiled windows and exits when another tiled window gains focus.

## Configuration

- `config.toml` — settings, app routing, and borders. Current defaults: 10-point
  gaps, no animations, and a focused-only **1-point white border at 50% opacity**.
- `skhdrc` — shortcuts, loaded through the shared skhd entry point.
- `layout.py` — resident Python layout. BSP is preserved when switching to stack
  and back. Drag-to-swap/resize is not implemented.
- `space_history.py` — Space history from Mimi's hook JSON, without polling. Visit two
  Spaces before using Option+Tab. History is single-display; after manually
  reordering/deleting Spaces, clear `~/.local/state/mimi/space-history.json`.

App routing: terminals → 1, Brave → 2, files/notes → 3, chat → 4, mail → 5,
Keynote → 8. Rules can move existing windows at startup or after rule changes.

## Check and reload

```sh
mimi status
mimi doctor
skhd --status

mimi config reload
skhd --reload
```

Saving `config.toml` also reloads it automatically. After editing the resident
`layout.py`, use `mimi services restart`; restarting resets remembered per-Space
layouts, window order, and ratios. Test Space switching directly if needed with
`mimi action space 2`—a successful doctor check alone does not prove switching.
