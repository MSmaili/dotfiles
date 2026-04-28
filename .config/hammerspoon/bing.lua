local M = {}

-- Dailywallpaper download and set desktop from bing
-- Bing market codes.
-- https://learn.microsoft.com/en-us/bing/search-apis/bing-web-search/reference/market-codes
local REGIONS = {
	US = "en-US", -- United States
	GB = "en-GB", -- United Kingdom
	CA = "en-CA", -- Canada
	AU = "en-AU", -- Australia
	JP = "ja-JP", -- Japan
	DE = "de-DE", -- Germany
	FR = "fr-FR", -- France
	CN = "zh-CN", -- China
	BR = "pt-BR", -- Brazil
	IN = "en-IN", -- India
}

local THROTTLE_SECONDS = 6 * 3600
local REFETCH_SECONDS = 12 * 3600
local DIR = os.getenv("HOME") .. "/Pictures/BingWallpapers"
local last_fetch_key = "bing.last_fetch"
local timer = nil

local current = hs.settings.get("bing.current") or {}
current.title = current.title or ""
current.copyright = current.copyright or ""
current.region = REGIONS[current.region] and current.region or "US"

local function set_current(data)
	current = data
	hs.settings.set("bing.current", current)
end

local function show_info()
	if current.title == "" then
		return hs.alert.show("No wallpaper info yet")
	end
	hs.notify
		.new({
			title = "🖼️  " .. current.title,
			subTitle = "[" .. current.region .. "]",
			informativeText = current.copyright,
			withdrawAfter = 0,
		})
		:send()
end

local function set_desktop(path)
	local url = "file://" .. path
	for _, screen in ipairs(hs.screen.allScreens()) do
		screen:desktopImageURL(url)
	end
end

local function mark_fetch_success()
	hs.settings.set(last_fetch_key, os.time())
end

local function report_failure(message, manual)
	print("bing: " .. message)
	if manual then
		hs.alert.show(message)
	end
end

local function finish_fetch(current_data, manual, changed)
	set_current(current_data)
	mark_fetch_success()
	if changed then
		show_info()
	elseif manual then
		hs.alert.show("Bing wallpaper refreshed")
	end
end

local function parse_metadata(body, mkt)
	local data = body and hs.json.decode(body)
	local img = data and data.images and data.images[1]
	if not img then
		return nil
	end
	local date = img.enddate and img.enddate:match("^(%d%d%d%d%d%d%d%d)$")
	if not date then
		return nil
	end
	return {
		url = "https://www.bing.com" .. img.urlbase .. "_UHD.jpg",
		path = DIR .. "/" .. mkt .. "_" .. date .. ".jpg",
		title = img.title or "",
		copyright = img.copyright or "",
	}
end

local function save(path, bytes)
	hs.fs.mkdir(DIR)
	local f = io.open(path, "wb")
	if not f then
		return false
	end
	f:write(bytes)
	f:close()
	return true
end

local function download(meta, notify)
	hs.http.asyncGet(meta.url, nil, function(s, bytes)
		if s ~= 200 or not save(meta.path, bytes) then
			report_failure("Bing download failed", notify.manual)
			return
		end
		set_desktop(meta.path)
		finish_fetch(notify.current_data, notify.manual, notify.changed)
	end)
end

local function should_skip()
	local last = hs.settings.get(last_fetch_key) or 0
	return os.time() - last < THROTTLE_SECONDS
end

local function fetch(manual)
	local mkt = REGIONS[current.region]
	local api = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=" .. mkt
	hs.http.asyncGet(api, nil, function(status, body)
		if status ~= 200 then
			report_failure("Bing API failed", manual)
			return
		end
		local meta = parse_metadata(body, mkt)
		if not meta then
			report_failure("Bing metadata parse failed", manual)
			return
		end
		local next_current = { title = meta.title, copyright = meta.copyright, region = current.region }
		local changed = meta.title ~= current.title
		if hs.fs.attributes(meta.path) then
			set_desktop(meta.path)
			finish_fetch(next_current, manual, changed)
		else
			download(meta, { current_data = next_current, manual = manual, changed = changed })
		end
	end)
end

function M.start()
	if timer then
		timer:stop()
	end
	if not should_skip() then
		fetch()
	end
	timer = hs.timer.doEvery(REFETCH_SECONDS, fetch)
end

function M.stop()
	if not timer then
		return
	end
	timer:stop()
	timer = nil
end

function M.setRegion(code)
	if REGIONS[code] then
		set_current({ title = current.title, copyright = current.copyright, region = code })
		fetch()
	end
end

local chooser
local function createChooser()
	return hs.chooser.new(function(c)
		if c then
			M.setRegion(c.text)
		end
	end)
end

function M.pickRegion()
	if not chooser then
		chooser = createChooser()
		local list = {}
		for code, mkt in pairs(REGIONS) do
			table.insert(list, { text = code, subText = mkt })
		end
		table.sort(list, function(a, b)
			return a.text < b.text
		end)
		chooser:choices(list)
	end
	chooser:show()
end

M.refresh = function()
	fetch(true)
end
M.info = show_info

return M
