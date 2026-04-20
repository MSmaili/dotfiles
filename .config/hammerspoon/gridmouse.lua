local M = {}

M.canvas = nil
M.listener = nil
M.state = "idle"
M.rootFrame = nil
M.currentFrame = nil

M.config = {
	coarse = {
		keys = {
			q = { 0, 0 },
			w = { 1, 0 },
			e = { 2, 0 },
			r = { 3, 0 },
			t = { 4, 0 },
			y = { 5, 0 },
			u = { 6, 0 },
			i = { 7, 0 },
			o = { 8, 0 },
			p = { 9, 0 },
			a = { 0, 1 },
			s = { 1, 1 },
			d = { 2, 1 },
			f = { 3, 1 },
			g = { 4, 1 },
			h = { 5, 1 },
			j = { 6, 1 },
			k = { 7, 1 },
			l = { 8, 1 },
			[";"] = { 9, 1 },
			z = { 0, 2 },
			x = { 1, 2 },
			c = { 2, 2 },
			v = { 3, 2 },
			b = { 4, 2 },
			n = { 5, 2 },
			m = { 6, 2 },
			[","] = { 7, 2 },
			["."] = { 8, 2 },
			["/"] = { 9, 2 },
		},
		cols = 10,
		rows = 3,
	},
	refine = {
		keys = {
			q = { 0, 0 },
			w = { 1, 0 },
			e = { 2, 0 },
			a = { 0, 1 },
			s = { 1, 1 },
			d = { 2, 1 },
			z = { 0, 2 },
			x = { 1, 2 },
			c = { 2, 2 },
			r = { 0, 3 },
			f = { 1, 3 },
			v = { 2, 3 },
		},
		cols = 3,
		rows = 4,
		autoConfirmThreshold = 40,
	},
	ui = {
		overlayAlpha = 0.18,
		strokeAlpha = 0.8,
		strokeWidth = 2,
		textAlpha = 0.95,
		headerAlpha = 0.95,
		minText = 18,
		scale = 0.22,
	},
}

local function ensureCanvas()
	if M.canvas then
		return
	end
	M.canvas = hs.canvas.new({ x = 0, y = 0, w = 0, h = 0 })
	M.canvas:level("overlay")
	M.canvas:behavior({ "canJoinAllSpaces", "fullScreenAuxiliary" })
	M.canvas:clickActivating(false)
end

local function center(f)
	return { x = f.x + f.w / 2, y = f.y + f.h / 2 }
end

local function subFrame(f, pos, cols, rows)
	local w, h = f.w / cols, f.h / rows
	return { x = f.x + pos[1] * w, y = f.y + pos[2] * h, w = w, h = h }
end

local function smallEnough(f)
	local t = M.config.refine.autoConfirmThreshold
	return f.w < t or f.h < t
end

local function drawGrid(frame, grid, title)
	ensureCanvas()
	local ui = M.config.ui
	local cellW, cellH = frame.w / grid.cols, frame.h / grid.rows

	M.canvas:frame(frame)

	local els = {
		{
			type = "rectangle",
			action = "fill",
			fillColor = { white = 0, alpha = ui.overlayAlpha },
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		},
	}

	local size = math.max(ui.minText, math.floor(cellH * ui.scale))
	for key, pos in pairs(grid.keys) do
		local x, y = pos[1] * cellW, pos[2] * cellH
		table.insert(els, {
			type = "rectangle",
			action = "stroke",
			strokeColor = { white = 1, alpha = ui.strokeAlpha },
			strokeWidth = ui.strokeWidth,
			frame = { x = x, y = y, w = cellW, h = cellH },
		})
		table.insert(els, {
			type = "text",
			text = key:upper(),
			textSize = size,
			textColor = { white = 1, alpha = ui.textAlpha },
			textAlignment = "center",
			frame = { x = x, y = y + (cellH - size) / 2 + 2, w = cellW, h = size },
		})
	end

	table.insert(els, {
		type = "text",
		text = title,
		textSize = 20,
		textColor = { white = 1, alpha = ui.headerAlpha },
		textAlignment = "center",
		frame = { x = 20, y = 10, w = frame.w - 40, h = 28 },
	})

	M.canvas:replaceElements(els):show()
end

function M.stop()
	M.state = "idle"
	M.rootFrame = nil
	M.currentFrame = nil
	if M.listener then
		M.listener:stop()
		M.listener = nil
	end
	if M.canvas then
		M.canvas:hide()
	end
end

function M.confirm(click)
	local p = center(M.currentFrame)
	hs.mouse.absolutePosition(p)
	if click then
		hs.timer.doAfter(0.02, function()
			hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, p):post()
			hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, p):post()
		end)
	end
	hs.timer.doAfter(0.04, M.stop)
end

function M.handleKey(key)
	if key == "escape" then
		M.stop()
		return true
	end

	if M.state == "coarse" then
		local pos = M.config.coarse.keys[key]
		if pos then
			M.currentFrame = subFrame(M.rootFrame, pos, M.config.coarse.cols, M.config.coarse.rows)
			M.state = "refine"
			drawGrid(M.currentFrame, M.config.refine, "Refine")
			return true
		end
	end

	if M.state == "refine" then
		if key == "space" or key == "return" or key == "padenter" then
			M.confirm(true)
			return true
		end
		if key == "tab" then
			M.confirm(false)
			return true
		end
		local pos = M.config.refine.keys[key]
		if pos then
			M.currentFrame = subFrame(M.currentFrame, pos, M.config.refine.cols, M.config.refine.rows)
			if smallEnough(M.currentFrame) then
				M.confirm(true)
			else
				drawGrid(M.currentFrame, M.config.refine, "Refine")
			end
			return true
		end
	end

	return false
end

function M.start()
	M.stop()
	local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
	M.rootFrame = screen:fullFrame()
	M.currentFrame = M.rootFrame
	M.state = "coarse"
	drawGrid(M.rootFrame, M.config.coarse, "Coarse")

	M.listener = hs.eventtap
		.new({ hs.eventtap.event.types.keyDown }, function(e)
			if M.state == "idle" then
				return false
			end
			local key = hs.keycodes.map[e:getKeyCode()]
			return key and M.handleKey(key) or false
		end)
		:start()
end

return M
