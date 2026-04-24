local M = {}

-- Caffeine module, prevent macos to go in sleep mode,
-- extra capability to move mouse every n seconds to right/left

M.menu = hs.menubar.new()

local JIGGLE_DISTANCE = 60
local JIGGLE_INTERVAL = 60
local IDLE_THRESHOLD = JIGGLE_INTERVAL - 5
local jiggleTimer = nil
local jiggleDir = 1

local function jiggleOnce()
	if hs.host.idleTime() < IDLE_THRESHOLD then
		return
	end
	local p = hs.mouse.absolutePosition()
	local newPos = { x = p.x + JIGGLE_DISTANCE * jiggleDir, y = p.y }
	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, newPos):post()
	jiggleDir = -jiggleDir
end

local function stopJiggle()
	if jiggleTimer then
		jiggleTimer:stop()
		jiggleTimer = nil
	end
end

local function startJiggle()
	stopJiggle()
	jiggleTimer = hs.timer.doEvery(JIGGLE_INTERVAL, jiggleOnce)
end

local function updateMenu(state)
	M.menu:setTitle(state and "☕" or "☾")
	M.menu:setTooltip(state and "Caffeine: ACTIVE" or "Caffeine: INACTIVE")
end

function M.toggle()
	local newState = not hs.caffeinate.get("displayIdle")
	hs.caffeinate.set("displayIdle", newState)

	if newState then
		startJiggle()
	else
		stopJiggle()
	end

	updateMenu(newState)
	hs.alert.show(newState and "Caffeine ON ☕" or "Caffeine OFF ☾")
end

updateMenu(hs.caffeinate.get("displayIdle"))
M.menu:setClickCallback(M.toggle)

return M
