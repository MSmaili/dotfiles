# Leader.spoon

Leader shows a leader-key menu in a heads-up display (HUD). It works like
[which-key](https://github.com/folke/which-key.nvim). You press a leader hotkey,
and then you press keys to move through a menu of groups and actions. The menu
closes after a timeout, or when you press an unknown key.

## Install

1. Copy `Leader.spoon` into your Hammerspoon Spoons folder.
2. Add your menu to your `init.lua`. This example creates a small menu:

   ```lua
   hs.loadSpoon("Leader")

   spoon.Leader.create({ "ctrl", "alt", "shift" }, "space", {
   	r = { label = "Reload", action = hs.reload },
   	o = {
   		label = "Open",
   		group = {
   			g = { label = "Ghostty", action = spoon.Leader.app("Ghostty") },
   			b = { label = "Brave", action = spoon.Leader.open("https://brave.com", "Brave Browser") },
   		},
   	},
   }, 2.5)
   ```

## Menu format

Each key is one of two types:

- An action: `{ label = "Reload", action = function() ... end }`
- A group: `{ label = "Open", group = { ... } }`. A group can contain more
  groups.

Leader marks a group with a `→` and dims it. Leader shows an action in the
normal color. Leader lists the actions first, and then the groups in
alphabetical order.

## Action helpers

- `spoon.Leader.app(name)` — start an app, or focus it
- `spoon.Leader.open(target[, app])` — open a URL or a path, with an optional app
- `spoon.Leader.task(bin, args)` — run a program with arguments

## Style

To change the colors, fonts, and sizes, set the fields of `spoon.Leader.style`.
Set them after you load the Spoon.
