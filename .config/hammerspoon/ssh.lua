local M = {}

local HOME = os.getenv("HOME")

local function resolve(path)
	path = path:gsub("^~", HOME)
	if path:sub(1, 1) ~= "/" then
		path = HOME .. "/.ssh/" .. path
	end
	return path
end

local function extract(line)
	return line:match("^%s*[Ii]nclude%s+(.+)$"), line:match("^%s*[Hh]ost%s+(.+)$")
end

local function add_hosts(spec, list)
	if spec:match("[*?]") then
		return
	end
	for h in spec:gmatch("%S+") do
		table.insert(list, { text = h })
	end
end

local function parse(path, list, seen)
	path = resolve(path)
	if seen[path] then
		return
	end
	seen[path] = true

	local f = io.open(path, "r")
	if not f then
		return
	end

	for line in f:lines() do
		local include, host = extract(line)
		if include then
			parse(include, list, seen)
		elseif host then
			add_hosts(host, list)
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
	parse("~/.ssh/config", list, {})
	if #list == 0 then
		return hs.alert.show("No SSH hosts 🤷")
	end
	chooser:choices(list)
	chooser:show()
end

return M
