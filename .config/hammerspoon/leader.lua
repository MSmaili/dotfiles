local M = {}

-- Menu shape:
--   { [key] = { label = "...", action = fn },   -- leaf
--     [key] = { label = "...", group  = {...} } -- nested
--   }

local function showHUD(menu)
	local leaves, groups = {}, {}
	for k, v in pairs(menu) do
		local line = string.format("%s  %s%s", k, v.label or "", v.group and " →" or "")
		table.insert(v.group and groups or leaves, line)
	end
	table.sort(leaves)
	table.sort(groups)
	for _, g in ipairs(groups) do
		table.insert(leaves, g)
	end
	return hs.alert.show(table.concat(leaves, "\n"), nil, nil, true)
end

function M.create(mods, key, rootMenu, timeout)
	local modal = hs.hotkey.modal.new(mods, key)
	local timer, hud
	local currentMenu = rootMenu
	timeout = timeout or 2

	local function stopTimer()
		if timer then
			timer:stop()
			timer = nil
		end
	end
	local function closeHUD()
		if hud then
			hs.alert.closeSpecific(hud)
			hud = nil
		end
	end
	local function resetTimer()
		stopTimer()
		timer = hs.timer.doAfter(timeout, function()
			modal:exit()
		end)
	end
	local function enterMenu(menu)
		currentMenu = menu
		closeHUD()
		hud = showHUD(menu)
		resetTimer()
	end

	function modal:entered()
		enterMenu(rootMenu)
	end
	function modal:exited()
		stopTimer()
		closeHUD()
		currentMenu = rootMenu
	end

	local function collectKeys(menu, set)
		for k, v in pairs(menu) do
			set[k] = true
			if v.group then
				collectKeys(v.group, set)
			end
		end
		return set
	end

	local function handle(k)
		local entry = currentMenu[k]
		if not entry then
			modal:exit()
			return
		end
		if entry.group then
			enterMenu(entry.group)
		else
			modal:exit()
			entry.action()
		end
	end

	for k in pairs(collectKeys(rootMenu, {})) do
		modal:bind({}, k, function()
			handle(k)
		end)
		modal:bind(mods, k, function()
			handle(k)
		end)
	end
	modal:bind({}, "escape", function()
		modal:exit()
	end)

	return modal
end

-- Run `open ...` or any shell command via hs.task (no shell fork).
function M.cmd(str)
	local args = {}
	for w in str:gmatch("%S+") do
		table.insert(args, w)
	end
	local bin = table.remove(args, 1)
	if not bin:find("/") then
		bin = hs.execute("which " .. bin):gsub("%s+$", "")
	end
	return function()
		hs.task.new(bin, nil, args):start()
	end
end

function M.app(name)
	return function()
		hs.application.launchOrFocus(name)
	end
end

return M
