local M = {}

M.menu = hs.menubar.new()
M.jiggleTimer = nil

local JIGGLE_DISTANCE = 10
local JIGGLE_INTERVAL = 60

local function updateMenu(state)
	M.menu:setTitle(state and "☕" or "☾")
	M.menu:setTooltip(state and "Caffeine: ACTIVE" or "Caffeine: INACTIVE")
end

function M.toggle()
	local newState = not hs.caffeinate.get("displayIdle")
	hs.caffeinate.set("displayIdle", newState)

	if newState then
		M.jiggleTimer = hs.timer.doEvery(JIGGLE_INTERVAL, function()
			local p = hs.mouse.absolutePosition()
			hs.mouse.absolutePosition({ x = p.x + JIGGLE_DISTANCE, y = p.y })
			hs.timer.doAfter(0.1, function()
				hs.mouse.absolutePosition(p)
			end)
		end)
	elseif M.jiggleTimer then
		M.jiggleTimer:stop()
		M.jiggleTimer = nil
	end

	updateMenu(newState)
	hs.alert.show(newState and "Caffeine ON ☕" or "Caffeine OFF ☾")
end

updateMenu(hs.caffeinate.get("displayIdle"))
M.menu:setClickCallback(M.toggle)

return M
