hs = hs
local meh = { "ctrl", "alt", "shift" }

hs.alert.defaultStyle.radius = 6
hs.alert.show("Config reloaded")

local GridMouse = require("gridmouse")
local Leader = require("leader")
local Caffeine = require("caffeine")
local KeyCaster = require("key-caster")
local Mic = require("mic")
local SSH = require("ssh")

hs.hotkey.bind(meh, "g", GridMouse.start)

Leader.create(meh, "space", {
	r = { label = "Reload", action = hs.reload },
	o = {
		label = "Open",
		group = {
			g = { label = "Ghostty", action = Leader.app("Ghostty") },
			b = { label = "Brave", action = Leader.app("Brave Browser") },
			t = { label = "Teams", action = Leader.app("Microsoft Teams") },
			m = {
				label = "Mail",
				action = function()
					hs.application.launchOrFocus(
						hs.application.pathForBundleID("com.microsoft.Outlook") and "Microsoft Outlook" or "Thunderbird"
					)
				end,
			},
			f = { label = "Finder", action = Leader.app("Finder") },
			o = { label = "Obsidian", action = Leader.app("Obsidian") },
			d = { label = "Discord", action = Leader.app("Discord") },
		},
	},
	g = {
		label = "Go to",
		group = {
			d = { label = "Downloads", action = Leader.open(os.getenv("HOME") .. "/Downloads") },
			["."] = {
				label = "dotfiles",
				action = Leader.task(
					"/usr/bin/open",
					{ "-na", "Ghostty", "--args", "--working-directory=" .. os.getenv("HOME") .. "/dotfiles" }
				),
			},
			v = { label = "Vault", action = Leader.open(os.getenv("HOME") .. "/.vaults") },
			m = { label = "Data", action = Leader.open(os.getenv("HOME") .. "/data") },
			h = { label = "Home", action = Leader.open(os.getenv("HOME")) },
			c = { label = "ChatGPT", action = Leader.open("https://chatgpt.com", "Brave Browser") },
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
			r = {
				label = "Record (macOS)",
				action = function()
					hs.eventtap.keyStroke({ "shift", "cmd" }, "5", 0)
				end,
			},
		},
	},
	p = {
		label = "Pick",
		group = {
			e = {
				label = "Emoji",
				action = function()
					hs.eventtap.keyStroke({ "ctrl", "cmd" }, "space", 0)
				end,
			},
			p = {
				label = "1Password",
				action = function()
					hs.eventtap.keyStroke({ "shift", "cmd" }, "space", 0)
				end,
			},
			b = { label = "Color (bg)", action = Leader.open("pika://pick/background/hex") },
			f = { label = "Color (fg)", action = Leader.open("pika://pick/foreground/hex") },
			s = { label = "SSH host", action = SSH.pick },
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
	t = {
		label = "Toggle",
		group = {
			m = { label = "Mic mute", action = Mic.toggle },
			k = { label = "Key Caster", action = KeyCaster.toggle },
			c = { label = "Caffeine", action = Caffeine.toggle },
		},
	},
	q = {
		label = "Quit / Session",
		group = {
			l = {
				label = "Lock screen",
				action = function()
					hs.caffeinate.lockScreen()
				end,
			},
			s = {
				label = "Sleep display",
				action = function()
					hs.caffeinate.systemSleep()
				end,
			},
			o = {
				label = "Log out",
				action = function()
					hs.caffeinate.logOut()
				end,
			},
			e = {
				label = "Empty trash",
				action = function()
					hs.osascript.applescript('tell application "Finder" to empty trash')
				end,
			},
		},
	},
}, 2.5)
