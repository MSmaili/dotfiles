hs = hs
local meh = { "ctrl", "alt", "shift" }

hs.alert.defaultStyle.radius = 6
hs.alert.show("Config reloaded")

local GridMouse = require("gridmouse")
local Leader = require("leader")
local Caffeine = require("caffeine")
local PlainPaste = require("plainpaste")

hs.hotkey.bind(meh, "o", GridMouse.start)
hs.hotkey.bind(meh, "v", PlainPaste.paste)

Leader.create(meh, "space", {
	r = { label = "Reload", action = hs.reload },
	c = { label = "Caffeine", action = Caffeine.toggle },

	o = {
		label = "Open",
		group = {
			g = { label = "Ghostty", action = Leader.app("Ghostty") },
			b = { label = "Brave", action = Leader.app("Brave Browser") },
			t = { label = "Teams", action = Leader.app("Microsoft Teams") },
			c = {
				label = "ChatGPT",
				action = Leader.cmd(
					"osascript " .. os.getenv("HOME") .. "/.config/leaderkey/brave.scpt https://chatgpt.com"
				),
			},
			m = { label = "Thunderbird", action = Leader.app("Thunderbird") },
			f = { label = "Finder", action = Leader.app("Finder") },
			o = { label = "Outlook", action = Leader.app("Microsoft Outlook") },
		},
	},

	s = {
		label = "Screenshot",
		group = {
			a = { label = "Area", action = Leader.cmd("open shottr://grab/area") },
			o = { label = "OCR", action = Leader.cmd("open shottr://ocr") },
			w = { label = "Window", action = Leader.cmd("open shottr://grab/window") },
			f = { label = "Fullscreen", action = Leader.cmd("open shottr://grab/fullscreen") },
			s = { label = "Scrolling", action = Leader.cmd("open shottr://grab/scrolling") },
		},
	},

	p = {
		label = "Color picker",
		group = {
			b = { label = "Background", action = Leader.cmd("open pika://pick/background/hex") },
			f = { label = "Foreground", action = Leader.cmd("open pika://pick/foreground/hex") },
		},
	},

	w = {
		label = "Window (Aerospace)",
		group = {
			h = { label = "Join left", action = Leader.cmd("/opt/homebrew/bin/aerospace join-with left") },
			j = { label = "Join down", action = Leader.cmd("/opt/homebrew/bin/aerospace join-with down") },
			k = { label = "Join up", action = Leader.cmd("/opt/homebrew/bin/aerospace join-with up") },
			l = { label = "Join right", action = Leader.cmd("/opt/homebrew/bin/aerospace join-with right") },
		},
	},

	f = {
		label = "Finder",
		group = {
			o = { label = "Open", action = Leader.app("Finder") },
			d = { label = "Downloads", action = Leader.cmd("open " .. os.getenv("HOME") .. "/Downloads") },
			m = { label = "data", action = Leader.cmd("open " .. os.getenv("HOME") .. "/data") },
		},
	},
}, 2.5)
