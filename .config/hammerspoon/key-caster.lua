local M = {}

-- Key Caster: overlay at the bottom of the screen showing the last keystroke
-- or modifier combo. Plain letters within SEQ_WINDOW chain into a word.
-- the initial logic was taken from, but then simplified to my needs: https://github.com/windvalley/dot-hammerspoon/blob/main/key_caster.lua

-- Config ---------------------------------------------------------------------

local config = {
	font = { name = "Menlo Bold", size = 44 },
	text_color = { hex = "#F8FAFC", alpha = 1 },
	bg_color = { hex = "#111827", alpha = 0.78 },
	duration = 1.2, -- seconds to show overlay
	padding_x = 24,
	padding_y = 12,
	corner_radius = 14,
	min_width = 108,
	offset_y = 100, -- distance from bottom of screen
}

local SEQ_WINDOW = 0.4 -- seconds to keep concatenating letters
local MAX_SEQ_LEN = 24 -- cap sequence to avoid overflowing the screen

local modifier_order = { ctrl = 1, alt = 2, cmd = 3, shift = 4, fn = 5 }
local modifier_symbols = { ctrl = "⌃", alt = "⌥", cmd = "⌘", shift = "⇧", fn = "fn" }
local modifier_aliases = {
	command = "cmd",
	cmd = "cmd",
	rightcommand = "cmd",
	rightcmd = "cmd",
	option = "alt",
	alt = "alt",
	rightoption = "alt",
	rightalt = "alt",
	control = "ctrl",
	ctrl = "ctrl",
	rightcontrol = "ctrl",
	rightctrl = "ctrl",
	shift = "shift",
	rightshift = "shift",
	fn = "fn",
}
local special_keys = {
	space = "󱁐",
	tab = "Tab",
	["return"] = "Return",
	enter = "Enter",
	padenter = "Enter",
	delete = "Delete",
	forwarddelete = "Fwd Del",
	escape = "Esc",
	home = "Home",
	["end"] = "End",
	pageup = "Page Up",
	pagedown = "Page Down",
	up = "↑",
	down = "↓",
	left = "←",
	right = "→",
}

-- State ----------------------------------------------------------------------

local canvas, measure_canvas, hide_timer, tap
local seq_text, seq_time

-- Measurement / rendering ---------------------------------------------------

local function styled_text(text)
	return hs.styledtext.new(text, {
		font = { name = config.font.name, size = config.font.size },
		color = config.text_color,
	})
end

local function measure(text)
	local st = styled_text(text)
	local size = measure_canvas and measure_canvas:minimumTextSize(st)
	if size then
		return math.ceil(size.w), math.ceil(size.h), st
	end
	-- Fallback estimate (only hit if measure_canvas hasn't been created yet).
	return math.ceil(#text * config.font.size * 0.65), math.ceil(config.font.size * 1.35), st
end

local function screen_frame()
	local win = hs.window.focusedWindow()
	local scr = win and win:screen() or hs.screen.mainScreen()
	return scr and scr:frame()
end

local function schedule_hide()
	if hide_timer then
		hide_timer:stop()
	end
	hide_timer = hs.timer.doAfter(config.duration, function()
		if canvas then
			canvas:hide()
		end
		hide_timer = nil
	end)
end

local function show_overlay(text)
	if not text then
		return
	end
	local sf = screen_frame()
	if not sf then
		return
	end

	local tw, th, st = measure(text)
	local w = math.max(config.min_width, tw + config.padding_x * 2)
	local h = th + config.padding_y * 2
	local frame = {
		x = math.floor(sf.x + (sf.w - w) / 2),
		y = math.floor(sf.y + sf.h - h - config.offset_y),
		w = math.ceil(w),
		h = math.ceil(h),
	}

	local els = {
		{
			type = "rectangle",
			action = "fill",
			frame = { x = 0, y = 0, w = w, h = h },
			roundedRectRadii = { xRadius = config.corner_radius, yRadius = config.corner_radius },
			fillColor = config.bg_color,
		},
		{
			type = "text",
			text = st,
			frame = { x = config.padding_x, y = config.padding_y, w = tw, h = th },
		},
	}

	if not canvas then
		canvas = hs.canvas.new(frame)
		canvas:level(hs.canvas.windowLevels.overlay)
	else
		canvas:frame(frame)
	end
	canvas:replaceElements(els):show()
	schedule_hide()
end

-- Event formatting -----------------------------------------------------------

local function sorted_modifiers(flags)
	local mods = {}
	for name in pairs(modifier_symbols) do
		if flags[name] then
			mods[#mods + 1] = name
		end
	end
	table.sort(mods, function(a, b)
		return modifier_order[a] < modifier_order[b]
	end)
	return mods
end

local function format_combo(flags, key_name)
	local parts = {}
	for _, m in ipairs(sorted_modifiers(flags)) do
		parts[#parts + 1] = modifier_symbols[m]
	end
	if key_name then
		local lower = key_name:lower()
		local label = special_keys[lower]
			or (#lower == 1 and lower:upper())
			or (lower:match("^f%d+$") and lower:upper())
			or (lower:sub(1, 1):upper() .. lower:sub(2))
		parts[#parts + 1] = label
	end
	return #parts > 0 and table.concat(parts, " ") or nil
end

local function is_plain_letter(flags, key_name)
	if not key_name or #key_name ~= 1 or not key_name:match("%a") then
		return false
	end
	return not (flags.cmd or flags.ctrl or flags.alt or flags.fn)
end

-- Event handling -------------------------------------------------------------

local function append_to_sequence(letter)
	local now = hs.timer.secondsSinceEpoch()
	if seq_text and seq_time and (now - seq_time) <= SEQ_WINDOW then
		seq_text = seq_text .. letter
	else
		seq_text = letter
	end
	seq_time = now
	if #seq_text > MAX_SEQ_LEN then
		seq_text = seq_text:sub(-MAX_SEQ_LEN)
	end
end

local function reset_sequence()
	seq_text, seq_time = nil, nil
end

local function on_event(event)
	local etype = event:getType()

	if etype == hs.eventtap.event.types.keyDown then
		local flags = event:getFlags()
		local code = event:getKeyCode()
		local key_name = hs.keycodes.map[code] or tostring(code)

		if is_plain_letter(flags, key_name) then
			append_to_sequence(key_name:upper())
			show_overlay(seq_text)
		else
			reset_sequence()
			show_overlay(format_combo(flags, key_name))
		end
	elseif etype == hs.eventtap.event.types.flagsChanged then
		reset_sequence()
		local flags = event:getFlags()
		local raw = hs.keycodes.map[event:getKeyCode()] or ""
		local canonical = modifier_aliases[raw:lower()]
		if canonical and flags[canonical] then
			show_overlay(format_combo(flags, nil))
		end
	end

	return false
end

-- Public ---------------------------------------------------------------------

function M.start()
	if tap then
		return
	end
	measure_canvas = hs.canvas.new({ x = 0, y = 0, w = 8, h = 8 })
	tap = hs.eventtap.new({
		hs.eventtap.event.types.keyDown,
		hs.eventtap.event.types.flagsChanged,
	}, on_event)
	tap:start()
	hs.alert.show("Key Caster ON")
end

function M.stop()
	if not tap then
		return
	end
	tap:stop()
	tap = nil
	reset_sequence()
	if hide_timer then
		hide_timer:stop()
		hide_timer = nil
	end
	if canvas then
		canvas:delete()
		canvas = nil
	end
	if measure_canvas then
		measure_canvas:delete()
		measure_canvas = nil
	end
	hs.alert.show("Key Caster OFF")
end

function M.toggle()
	if tap then
		M.stop()
	else
		M.start()
	end
end

return M
