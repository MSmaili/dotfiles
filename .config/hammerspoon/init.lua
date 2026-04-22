hs = hs
local meh = { "ctrl", "alt", "shift" }

hs.alert.defaultStyle.radius = 6
hs.alert.show("Config reloaded")

local GridMouse = require("gridmouse")
local Leader = require("leader")
local Caffeine = require("caffeine")

hs.hotkey.bind(meh, "o", GridMouse.start)

Leader.create(meh, "space", {
	r = { label = "Reload", action = hs.reload },
	c = { label = "Caffeine", action = Caffeine.toggle },

	o = {
		label = "Open",
		group = {
			g = { label = "Ghostty", action = Leader.app("Ghostty") },
			b = { label = "Brave", action = Leader.app("Brave Browser") },
			t = { label = "Teams", action = Leader.app("Microsoft Teams") },
			c = { label = "ChatGPT", action = Leader.open("https://chatgpt.com", "Brave Browser") },
			m = { label = "Thunderbird", action = Leader.app("Thunderbird") },
			f = { label = "Finder", action = Leader.app("Finder") },
			o = { label = "Outlook", action = Leader.app("Microsoft Outlook") },
		},
	},

	s = {
		label = "Screenshot",
		group = {
			a = { label = "Area", action = Leader.open("shottr://grab/area") },
			o = { label = "OCR", action = Leader.open("shottr://ocr") },
			w = { label = "Window", action = Leader.open("shottr://grab/window") },
			f = { label = "Fullscreen", action = Leader.open("shottr://grab/fullscreen") },
			s = { label = "Scrolling", action = Leader.open("shottr://grab/scrolling") },
		},
	},

	p = {
		label = "Color picker",
		group = {
			b = { label = "Background", action = Leader.open("pika://pick/background/hex") },
			f = { label = "Foreground", action = Leader.open("pika://pick/foreground/hex") },
		},
	},

	w = {
		label = "Window (Aerospace)",
		group = {
			h = { label = "Join left", action = Leader.task("/opt/homebrew/bin/aerospace", { "join-with", "left" }) },
			j = { label = "Join down", action = Leader.task("/opt/homebrew/bin/aerospace", { "join-with", "down" }) },
			k = { label = "Join up", action = Leader.task("/opt/homebrew/bin/aerospace", { "join-with", "up" }) },
			l = { label = "Join right", action = Leader.task("/opt/homebrew/bin/aerospace", { "join-with", "right" }) },
		},
	},

	f = {
		label = "Finder",
		group = {
			o = { label = "Open", action = Leader.app("Finder") },
			d = { label = "Downloads", action = Leader.open(os.getenv("HOME") .. "/Downloads") },
			m = { label = "data", action = Leader.open(os.getenv("HOME") .. "/data") },
		},
	},
}, 2.5)
