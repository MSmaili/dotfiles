# GridMouse.spoon

GridMouse controls the mouse from the keyboard. It places the cursor anywhere on
the screen, so you do not use the trackpad. You then move the cursor and click
it with the home row keys.

## How it works

1. Press the hotkey. A 10×10 grid covers the screen.
2. Press two home-row keys (`asdfghjkl;`). This selects a grid cell.
3. A 2×5 sub-grid appears in that cell. Press one key to move into it.
4. GridMouse now enters the free-move stage (see below).

## Free move

After you select a sub-cell, GridMouse enters the free-move stage. The overlay
disappears, and the cursor is under your control. Use these keys:

- `i` `k` `j` `l` — move the cursor (up, down, left, right)
- `space` or `return` — left click. Hold `shift` for a right click.
- `d` — double click
- `esc` or `delete` — exit

To skip this stage, set `freeMove` to `false`. Then GridMouse clicks as soon as
you select a sub-cell. See Configuration.

## Install

1. Copy `GridMouse.spoon` into your Spoons folder. The default folder is
   `~/.hammerspoon/Spoons/`.
2. Add these lines to your `init.lua`. They load the Spoon and bind a hotkey:

   ```lua
   hs.loadSpoon("GridMouse")
   spoon.GridMouse:bindHotkeys({
   	start = { { "ctrl", "alt", "shift" }, "g" },
   })
   ```

3. Reload your Hammerspoon configuration.

## Permissions

GridMouse reads the keyboard and moves the mouse. Give Hammerspoon Accessibility
permission in System Settings. Without this permission, the grid does not
appear.

## API

- `spoon.GridMouse:start()` — show the grid and start control
- `spoon.GridMouse:stop()` — remove the grid and stop control
- `spoon.GridMouse:bindHotkeys(mapping)` — bind the `start` and `stop` hotkeys

## Configuration

Set these fields to change the behavior:

- `spoon.GridMouse.freeMove` — the free-move stage is on when this is `true`
  (the default). Set it to `false` to click as soon as you select a sub-cell.
- `spoon.GridMouse.movementKeys` — the keys that move the cursor in the
  free-move stage. This is a table with `up`, `down`, `left`, and `right`
  fields. The default is `i`/`k`/`j`/`l`.

For vim-style movement keys:

```lua
spoon.GridMouse.movementKeys = { up = "k", down = "j", left = "h", right = "l" }
```
