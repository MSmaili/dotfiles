local M = {}

local HOME = os.getenv("HOME")

local function resolve(path, base_dir)
	path = path:gsub("^~", HOME)
	if path:sub(1, 1) == "/" then
		return path
	end
	if base_dir then
		path = base_dir .. "/" .. path
	else
		path = HOME .. "/.ssh/" .. path
	end
	return path
end

local function parent_dir(path)
	return path:match("^(.*)/[^/]+$")
end

local function extract(line)
	return line:match("^%s*[Ii]nclude%s+(.+)$"), line:match("^%s*[Hh]ost%s+(.+)$")
end

local function add_hosts(spec, list, seen_hosts)
	for h in spec:gmatch("%S+") do
		if h:sub(1, 1) ~= "!" and not h:match("[*?]") and not seen_hosts[h] then
			seen_hosts[h] = true
			list[#list + 1] = { text = h }
		end
	end
end

local function parse(path, list, seen_files, seen_hosts, base_dir)
	path = resolve(path, base_dir)
	if seen_files[path] then
		return
	end
	seen_files[path] = true

	local f = io.open(path, "r")
	if not f then
		return
	end
	local path_dir = parent_dir(path)

	for line in f:lines() do
		local include, host = extract(line)
		if include then
			for spec in include:gmatch("%S+") do
				parse(spec, list, seen_files, seen_hosts, path_dir)
			end
		elseif host then
			add_hosts(host, list, seen_hosts)
		end
	end
	f:close()
end

local chooser = hs.chooser.new(function(c)
	if c then
		hs.task.new("/usr/bin/open", nil, { "-na", "Ghostty", "--args", "-e", "ssh", c.text }):start()
	end
end)

function M.pick()
	local list = {}
	parse("~/.ssh/config", list, {}, {}, nil)
	if #list == 0 then
		return hs.alert.show("No SSH hosts 🤷")
	end
	table.sort(list, function(a, b)
		return a.text:lower() < b.text:lower()
	end)
	chooser:choices(list)
	chooser:show()
end

return M
