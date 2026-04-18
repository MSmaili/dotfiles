local M = {}

local settings_file = vim.fs.joinpath(vim.fn.stdpath("state"), "custom_settings.json")

local function decode_file(path)
	local ok, content = pcall(vim.fn.readfile, path)
	if not ok or #content == 0 then
		return nil
	end

	local success, data = pcall(vim.json.decode, table.concat(content))
	if success and type(data) == "table" then
		return data
	end

	return {}
end

local function read_file()
	local data = decode_file(settings_file)
	if data ~= nil then
		return data
	end

	return {}
end

local function write_file(data)
	vim.fn.mkdir(vim.fs.dirname(settings_file), "p")
	pcall(vim.fn.writefile, { vim.json.encode(data) }, settings_file)
end

local function merge_defaults(value, defaults)
	if type(defaults) ~= "table" then
		return value ~= nil and value or defaults
	end

	if type(value) ~= "table" then
		return vim.deepcopy(defaults)
	end

	return vim.tbl_deep_extend("force", vim.deepcopy(defaults), value)
end

function M.file()
	return settings_file
end

function M.load(key, defaults)
	local data = read_file()
	return merge_defaults(data[key], defaults or {})
end

function M.save(key, value)
	local data = read_file()
	data[key] = type(value) == "table" and vim.deepcopy(value) or value
	write_file(data)
end

return M
