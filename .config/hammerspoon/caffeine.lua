local M = {}

-- Caffeine module, prevent macos to go in sleep mode,
-- extra capability to move mouse every n seconds to right/left

local menu = hs.menubar.new()
M.menu = menu

local JIGGLE_DISTANCE = 60
local JIGGLE_INTERVAL = 60
local IDLE_THRESHOLD = JIGGLE_INTERVAL - 5
local jiggle_timer = nil
local jiggle_dir = 1

local function jiggleOnce()
	if hs.host.idleTime() < IDLE_THRESHOLD then
		return
	end
	local p = hs.mouse.absolutePosition()
	local newPos = { x = p.x + JIGGLE_DISTANCE * jiggle_dir, y = p.y }
	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, newPos):post()
	jiggle_dir = -jiggle_dir
end

local function stopJiggle()
	if jiggle_timer then
		jiggle_timer:stop()
		jiggle_timer = nil
	end
end

local function startJiggle()
	stopJiggle()
	jiggle_timer = hs.timer.doEvery(JIGGLE_INTERVAL, jiggleOnce)
end

local function updateMenu(state)
	if not menu then
		return
	end
	menu:setTitle(state and "☕" or "☾")
	menu:setTooltip(state and "Caffeine: ACTIVE" or "Caffeine: INACTIVE")
end

local function applyState(state)
	hs.caffeinate.set("displayIdle", state)
	if state then
		startJiggle()
	else
		stopJiggle()
	end
	updateMenu(state)
	return state
end

function M.toggle()
	local newState = applyState(not hs.caffeinate.get("displayIdle"))
	hs.alert.show(newState and "Caffeine ON ☕" or "Caffeine OFF ☾")
end

applyState(hs.caffeinate.get("displayIdle"))
if menu then
	menu:setClickCallback(M.toggle)
end

return M
