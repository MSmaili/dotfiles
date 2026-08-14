# CleanMode.spoon

CleanMode covers every display with a dark full-screen overlay and blocks
keyboard, mouse, and trackpad input so you can safely clean your devices.

To leave cleaning mode, hold **Escape** for three seconds. A progress ring shows
the remaining hold time.

## Features

- Covers every connected display
- Blocks keyboard and pointer input
- Rebuilds the overlay when displays are added or removed
- Requires a deliberate Escape hold to exit
- Refuses to start while macOS Secure Input prevents keyboard capture
- Shows the current cleaning duration

## Install

1. Copy `CleanMode.spoon` into your Hammerspoon Spoons folder.
2. Load it and bind a hotkey in `init.lua`:

   ```lua
   hs.loadSpoon("CleanMode")
   spoon.CleanMode:bindHotkeys({
     toggle = { { "ctrl", "alt", "shift" }, "n" },
   })
   ```

Hammerspoon needs Accessibility permission to block keyboard input. CleanMode
will not start while macOS Secure Input is active because Hammerspoon would be
unable to detect the Escape hold used to exit.

## API

- `spoon.CleanMode.start()` — enter cleaning mode
- `spoon.CleanMode.stop()` — leave cleaning mode
- `spoon.CleanMode.toggle()` — toggle cleaning mode
- `spoon.CleanMode:isActive()` — report whether cleaning mode is active
- `spoon.CleanMode:bindHotkeys(mapping)` — bind `toggle`, `start`, and `stop`

The start, stop, and toggle methods can also be used as bare callback functions.

## Configuration

Change fields in `spoon.CleanMode.config` after loading the Spoon and before
starting it. For example:

```lua
hs.loadSpoon("CleanMode")
spoon.CleanMode.config.hold_seconds = 4
spoon.CleanMode.config.title = "TIME TO CLEAN"
```

The config table also exposes the overlay colors, fonts, ring dimensions, and
progress animation frame rate.

## License

MIT — see the repository license.
