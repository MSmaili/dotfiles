local M = {}

-- Clean Mode: full-screen dark overlay that swallows keyboard input so you
-- can wipe the keyboard/trackpad.
--
-- Exit by holding Escape for `hold_seconds`.
--
local config = {
	hold_seconds = 3.0, -- how long to hold Escape to exit
	bg_color = { red = 0.03, green = 0.03, blue = 0.05, alpha = 0.96 },
	title_color = { hex = "#F8FAFC", alpha = 1 },
	subtitle_color = { hex = "#94A3B8", alpha = 1 },
	timer_color = { hex = "#64748B", alpha = 1 },
	ring_track_color = { hex = "#1E293B", alpha = 1 },
	ring_progress_color = { hex = "#60A5FA", alpha = 1 },
	ring_fill = { hex = "#0F172A", alpha = 1 },
	title_font = { name = "SF Pro Display Bold", size = 72 },
	subtitle_font = { name = "SF Pro Text", size = 20 },
	key_font = { name = "SF Pro Text Bold", size = 22 },
	timer_font = { name = "SF Mono", size = 14 },
	ring_radius = 90, -- pixels
	ring_width = 6,
	title = "CLEANING MODE",
	progress_fps = 30, -- redraw rate while holding Escape
}

-- Cached references (avoid repeated table lookups in hot paths). -------------

local now = hs.timer.secondsSinceEpoch
local event_types = hs.eventtap.event.types
local event_properties = hs.eventtap.event.properties
local escape_keycode = hs.keycodes.map.escape

-- Element indexes — only list the ones we mutate after creation.
local IDX_PROGRESS_ARC = 6
local IDX_ELAPSED = 8

-- Reusable styled-text attribute table for the elapsed counter. Text is
-- replaced per update; the rest is stable, so we avoid re-allocating it.
local elapsed_style = {
	font = config.timer_font,
	color = config.timer_color,
	paragraphStyle = { alignment = "center" },
}

-- State ----------------------------------------------------------------------

local active = false
local canvases = {} -- list of hs.canvas
local key_tap = nil
local screen_watcher = nil

local hold_start_at = nil
local tick_timer = nil
local started_at = nil
local last_elapsed_second = -1

-- Helpers --------------------------------------------------------------------

local function format_elapsed(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Drawing --------------------------------------------------------------------

-- Build the full element list for a canvas. Elements are stable in both count
-- and order so we can later mutate individual elements by index via
-- elementAttribute, avoiding full-canvas rebuilds on every tick.
local function build_elements(frame)
	local cx = frame.w / 2
	local cy = frame.h / 2
	local r = config.ring_radius
	local rw = config.ring_width
	local ring_radius = r - rw / 2

	local hs_text = config.hold_seconds == math.floor(config.hold_seconds) and string.format("%ds", config.hold_seconds)
		or string.format("%.1fs", config.hold_seconds)
	local subtitle_text = "Hold  Esc  for  " .. hs_text .. "  to exit"

	return {
		-- [1] Full-screen dim background
		{
			type = "rectangle",
			action = "fill",
			fillColor = config.bg_color,
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		},

		-- [2] Title
		{
			type = "text",
			text = hs.styledtext.new(config.title, {
				font = config.title_font,
				color = config.title_color,
				paragraphStyle = { alignment = "center" },
				kern = 6,
			}),
			frame = { x = 0, y = cy - r - 140, w = frame.w, h = 90 },
		},

		-- [3] Subtitle
		{
			type = "text",
			text = hs.styledtext.new(subtitle_text, {
				font = config.subtitle_font,
				color = config.subtitle_color,
				paragraphStyle = { alignment = "center" },
			}),
			frame = { x = 0, y = cy - r - 50, w = frame.w, h = 28 },
		},

		-- [4] Ring inner fill
		{
			type = "circle",
			action = "fill",
			fillColor = config.ring_fill,
			center = { x = cx, y = cy },
			radius = ring_radius,
		},

		-- [5] Ring track (full circle outline)
		{
			type = "circle",
			action = "stroke",
			strokeColor = config.ring_track_color,
			strokeWidth = rw,
			center = { x = cx, y = cy },
			radius = ring_radius,
		},

		-- [6] Progress arc (IDX_PROGRESS_ARC). Hidden by default (endAngle ==
		-- startAngle -> nothing drawn). Mutated in-place each tick.
		{
			type = "arc",
			action = "stroke",
			strokeColor = config.ring_progress_color,
			strokeWidth = rw,
			strokeCapStyle = "round",
			center = { x = cx, y = cy },
			radius = ring_radius,
			startAngle = 0,
			endAngle = 0,
		},

		-- [7] Key label inside the ring
		{
			type = "text",
			text = hs.styledtext.new("ESC", {
				font = config.key_font,
				color = config.subtitle_color,
				paragraphStyle = { alignment = "center" },
				kern = 4,
			}),
			frame = { x = cx - r, y = cy - 14, w = r * 2, h = 28 },
		},

		-- [8] Elapsed counter (IDX_ELAPSED). Mutated ~once per second.
		{
			type = "text",
			text = hs.styledtext.new("", elapsed_style),
			frame = { x = 0, y = cy + r + 40, w = frame.w, h = 20 },
		},
	}
end

-- Fast path: mutate only the progress arc on each canvas.
local function update_progress_arcs()
	local end_angle = 0
	if hold_start_at then
		local p = (now() - hold_start_at) / config.hold_seconds
		end_angle = 360 * math.min(1, math.max(0, p))
	end
	for i = 1, #canvases do
		canvases[i]:elementAttribute(IDX_PROGRESS_ARC, "endAngle", end_angle)
	end
end

-- Slower path: mutate only the elapsed-time text. Called at most once per
-- wall-clock second (debounced via `last_elapsed_second`).
local function update_elapsed_text(force)
	if not started_at then
		return
	end
	local whole = math.floor(now() - started_at)
	if not force and whole == last_elapsed_second then
		return
	end
	last_elapsed_second = whole
	local styled = hs.styledtext.new("Cleaning for " .. format_elapsed(whole), elapsed_style)
	for i = 1, #canvases do
		canvases[i]:elementAttribute(IDX_ELAPSED, "text", styled)
	end
end

-- Hold logic -----------------------------------------------------------------

local function ensure_tick_timer()
	if tick_timer then
		return
	end
	tick_timer = hs.timer.doEvery(1 / config.progress_fps, function()
		if not active then
			return
		end
		update_progress_arcs()
		update_elapsed_text(false)
		if hold_start_at and (now() - hold_start_at) >= config.hold_seconds then
			M.stop()
		end
	end)
end

local function stop_tick_timer()
	if tick_timer then
		tick_timer:stop()
		tick_timer = nil
	end
end

local function begin_hold()
	if not active or hold_start_at then
		return
	end
	hold_start_at = now()
end

local function cancel_hold()
	if not hold_start_at then
		return
	end
	hold_start_at = nil
	update_progress_arcs() -- reset arc to 0 immediately
end

-- Event tap ------------------------------------------------------------------

local function on_key_event(event)
	local t = event:getType()
	if t == event_types.keyDown then
		if event:getKeyCode() == escape_keycode then
			-- Ignore auto-repeats so the hold timer starts exactly once.
			if event:getProperty(event_properties.keyboardEventAutorepeat) == 0 then
				begin_hold()
			end
		else
			-- Any other key cancels a pending escape-hold.
			cancel_hold()
		end
	elseif t == event_types.keyUp then
		if event:getKeyCode() == escape_keycode then
			cancel_hold()
		end
	end

	-- Swallow every key event (keyDown, keyUp, flagsChanged, systemDefined).
	return true
end

-- Canvas lifecycle -----------------------------------------------------------

local function destroy_canvases()
	for i = 1, #canvases do
		canvases[i]:delete()
	end
	canvases = {}
end

local function create_canvases()
	destroy_canvases()
	for _, screen in ipairs(hs.screen.allScreens()) do
		local full = screen:fullFrame()
		local c = hs.canvas.new(full)
		c:level(hs.canvas.windowLevels.screenSaver)
		c:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
		-- Setting any mouseCallback flips the canvas out of "ignoresMouseEvents"
		-- mode, which is what actually makes it block clicks from reaching the
		-- apps below. We don't care about the clicks themselves, so it's a no-op.
		c:clickActivating(false) -- don't raise Hammerspoon when clicked
		c:mouseCallback(function() end)
		c:replaceElements(build_elements(full))
		c:show()
		canvases[#canvases + 1] = c
	end
	-- Paint initial state (0 progress, "00:00" elapsed).
	update_progress_arcs()
	last_elapsed_second = -1
	update_elapsed_text(true)
end

-- Public ---------------------------------------------------------------------

function M.start()
	if active then
		return
	end
	if not hs.accessibilityState(true) then
		hs.alert.show("Clean Mode: Accessibility permission required")
		return
	end

	active = true
	started_at = now()
	last_elapsed_second = -1

	create_canvases()

	-- Rebuild canvases when displays are added/removed.
	screen_watcher = hs.screen.watcher.new(function()
		if active then
			create_canvases()
		end
	end)
	screen_watcher:start()

	key_tap = hs.eventtap.new({
		event_types.keyDown,
		event_types.keyUp,
		event_types.flagsChanged,
		event_types.systemDefined,
	}, on_key_event)
	key_tap:start()

	ensure_tick_timer()

	hs.alert.show("Cleaning mode ON — hold Esc to exit")
end

function M.stop()
	if not active then
		return
	end
	active = false
	started_at = nil
	hold_start_at = nil

	stop_tick_timer()

	if key_tap then
		key_tap:stop()
		key_tap = nil
	end
	if screen_watcher then
		screen_watcher:stop()
		screen_watcher = nil
	end

	destroy_canvases()

	hs.alert.show("Cleaning mode OFF")
end

function M.toggle()
	if active then
		M.stop()
	else
		M.start()
	end
end

return M
