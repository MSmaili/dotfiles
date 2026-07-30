# Awake.spoon

Awake keeps macOS awake. It stops the display sleep and the idle sleep. It can
also move the cursor a short distance every minute, so that apps that measure
idle time see you as active. Awake adds a toggle to the menubar. The icon is ☕
when Awake is active, and ☾ when it is not.

Awake moves the cursor only when the computer is idle. For this reason, it does
not interfere with your own cursor movement.

## Install

1. Copy `Awake.spoon` into your Hammerspoon Spoons folder.
2. Add these lines to your `init.lua`. They load the Spoon and bind a hotkey:

   ```lua
   hs.loadSpoon("Awake")
   spoon.Awake:bindHotkeys({
   	toggle = { { "ctrl", "alt", "shift" }, "c" },
   })
   ```

`hs.loadSpoon` calls `:init()` for you. This creates the menubar item and reads
the current sleep state.

## API

- `spoon.Awake:start()` — start Awake. This stops idle sleep and moves the cursor.
- `spoon.Awake:stop()` — stop Awake
- `spoon.Awake.toggle()` — toggle Awake. You can use this as a plain function.
- `spoon.Awake:bindHotkeys(mapping)` — bind the `toggle`, `start`, and `stop` hotkeys

## Configuration

Set these fields to change the cursor movement:

- `spoon.Awake.jiggleDistance` — the distance in pixels for each move (default `60`)
- `spoon.Awake.jiggleInterval` — the time in seconds between moves (default `60`)
