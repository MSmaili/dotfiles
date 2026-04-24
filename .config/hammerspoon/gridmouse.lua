local M = {}

-- Single 10x10 grid. Two home-row keys to jump to a cell, then ikjl to nudge,
-- space/enter to click (shift for right-click), d to double-click,
-- esc/backspace to exit.

-- Config ---------------------------------------------------------------------

local KEYS = { "a", "s", "d", "f", "g", "h", "j", "k", "l", ";" }
local COLS, ROWS = #KEYS, #KEYS
local NUDGE = 20
local CLICK_GAP_US = 20000 -- 20ms between mouseDown and mouseUp

local NUDGE_KEYS = {
	j = { -NUDGE, 0 },
	l = { NUDGE, 0 },
	i = { 0, -NUDGE },
	k = { 0, NUDGE },
}

-- Click keys: each entry is { right = bool, double = bool }.
-- For right click, hold shift with any single-click key.
local CLICK_KEYS = {
	space = { right = false, double = false },
	["return"] = { right = false, double = false },
	d = { right = false, double = true },
}

local UI = {
	overlay_alpha = 0.25,
	stroke_alpha = 0.5,
	label_alpha = 0.95,
	min_font = 12,
	font_scale = 0.28,
}

local key_index = {}
for i, k in ipairs(KEYS) do
	key_index[k] = i - 1
end

-- State ----------------------------------------------------------------------

local canvas, tap
local state = "idle" -- idle | grid | nudge
local screen_frame
local first_key = nil

local function is_shift()
	return hs.eventtap.checkKeyboardModifiers().shift == true
end

local function cleanup()
	state = "idle"
	first_key = nil
	if tap then
		tap:stop()
		tap = nil
	end
	if canvas then
		canvas:hide()
	end
end

-- Mouse actions --------------------------------------------------------------

local function click_at(p, right, double)
	local down = right and hs.eventtap.event.types.rightMouseDown or hs.eventtap.event.types.leftMouseDown
	local up = right and hs.eventtap.event.types.rightMouseUp or hs.eventtap.event.types.leftMouseUp
	local clickStateProp = hs.eventtap.event.properties.mouseEventClickState
	cleanup()
	hs.timer.doAfter(0.01, function()
		hs.mouse.absolutePosition(p)
		hs.eventtap.event.newMouseEvent(down, p):post()
		hs.eventtap.event.newMouseEvent(up, p):post()
		if double then
			hs.timer.usleep(CLICK_GAP_US)
			hs.eventtap.event.newMouseEvent(down, p):setProperty(clickStateProp, 2):post()
			hs.eventtap.event.newMouseEvent(up, p):setProperty(clickStateProp, 2):post()
		end
	end)
end

local function nudge(dx, dy)
	local p = hs.mouse.absolutePosition()
	local newPos = { x = p.x + dx, y = p.y + dy }
	hs.mouse.absolutePosition(newPos)
	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, newPos):post()
end

local function jump_to_cell(col, row)
	local cw = screen_frame.w / COLS
	local ch = screen_frame.h / ROWS
	hs.mouse.absolutePosition({
		x = screen_frame.x + col * cw + cw / 2,
		y = screen_frame.y + row * ch + ch / 2,
	})
	state = "nudge"
	canvas:hide()
end

-- Rendering ------------------------------------------------------------------

local function ensure_canvas()
	if not canvas then
		canvas = hs.canvas.new({ x = 0, y = 0, w = 0, h = 0 })
		canvas:level("overlay")
		canvas:behavior({ "canJoinAllSpaces", "fullScreenAuxiliary" })
		canvas:clickActivating(false)
	end
end

local function draw_grid()
	ensure_canvas()
	canvas:frame(screen_frame)
	local sf = screen_frame
	local cw, ch = sf.w / COLS, sf.h / ROWS
	local font_size = math.max(UI.min_font, math.floor(math.min(cw, ch) * UI.font_scale))
	local els = {
		{
			type = "rectangle",
			action = "fill",
			fillColor = { white = 0, alpha = UI.overlay_alpha },
			frame = { x = 0, y = 0, w = sf.w, h = sf.h },
		},
	}

	for col = 0, COLS - 1 do
		for row = 0, ROWS - 1 do
			local x, y = col * cw, row * ch
			els[#els + 1] = {
				type = "rectangle",
				action = "stroke",
				strokeColor = { white = 1, alpha = UI.stroke_alpha },
				strokeWidth = 1,
				frame = { x = x, y = y, w = cw, h = ch },
			}
			local c1, c2 = KEYS[col + 1], KEYS[row + 1]
			if first_key == nil or first_key == c1 then
				els[#els + 1] = {
					type = "text",
					text = (c1 .. c2):upper(),
					textSize = font_size,
					textColor = { white = 1, alpha = UI.label_alpha },
					textAlignment = "center",
					frame = { x = x, y = y + (ch - font_size) / 2, w = cw, h = font_size + 4 },
				}
			end
		end
	end

	canvas:replaceElements(els):show()
end

-- Key handlers ---------------------------------------------------------------

local function handle_grid_key(key)
	if key == "delete" and first_key then
		first_key = nil
		draw_grid()
		return
	end
	local idx = key_index[key]
	if idx == nil then
		return
	end
	if not first_key then
		first_key = key
		draw_grid()
	else
		jump_to_cell(key_index[first_key], idx)
	end
end

local function handle_nudge_key(key)
	local click = CLICK_KEYS[key]
	if click then
		click_at(hs.mouse.absolutePosition(), click.right or is_shift(), click.double)
		return
	end
	local delta = NUDGE_KEYS[key]
	if delta then
		nudge(delta[1], delta[2])
	end
end

local function handle_key(event)
	local key = hs.keycodes.map[event:getKeyCode()]
	if not key then
		return true
	end

	if key == "escape" or (key == "delete" and state == "nudge") then
		cleanup()
	elseif state == "grid" then
		handle_grid_key(key)
	elseif state == "nudge" then
		handle_nudge_key(key)
	end

	return true
end

-- Public ---------------------------------------------------------------------

function M.start()
	cleanup()
	local scr = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
	screen_frame = scr:fullFrame()
	state = "grid"
	draw_grid()

	tap = hs.eventtap
		.new({ hs.eventtap.event.types.keyDown }, function(event)
			if state == "idle" then
				return false
			end
			return handle_key(event)
		end)
		:start()
end

function M.stop()
	cleanup()
end

return M
