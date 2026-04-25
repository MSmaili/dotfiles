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

local current = hs.settings.get("bing.current") or { title = "", copyright = "", region = "US" }

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
			print("bing: download failed, status=" .. tostring(s))
			return
		end
		set_desktop(meta.path)
		if notify then
			show_info()
		end
	end)
end

local function should_skip()
	local last = hs.settings.get("bing.last_fetch") or 0
	return os.time() - last < THROTTLE_SECONDS
end

local function fetch(manual)
	hs.settings.set("bing.last_fetch", os.time())
	local mkt = REGIONS[current.region]
	local api = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=" .. mkt
	hs.http.asyncGet(api, nil, function(status, body)
		if status ~= 200 then
			print("bing: api failed, status=" .. tostring(status))
			return
		end
		local meta = parse_metadata(body, mkt)
		if not meta then
			print("bing: parse failed")
			return
		end
		local changed = meta.title ~= current.title
		set_current({ title = meta.title, copyright = meta.copyright, region = current.region })
		if hs.fs.attributes(meta.path) then
			set_desktop(meta.path)
			if changed then
				show_info()
			elseif manual then
				hs.alert.show("Bing wallpaper refetched")
			end
		else
			download(meta, changed)
		end
	end)
end

function M.start()
	if M.timer then
		M.timer:stop()
	end
	if not should_skip() then
		fetch()
	end
	M.timer = hs.timer.doEvery(REFETCH_SECONDS, fetch)
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
