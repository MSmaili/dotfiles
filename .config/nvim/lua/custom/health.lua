local M = {}

local function theme_exists(name)
	if type(name) ~= "string" or name == "" then
		return false
	end

	local available = vim.fn.getcompletion("", "color")
	return vim.tbl_contains(available, name)
end

-- Check parsers have a reachable highlights query; dangling query symlinks
-- break highlighting silently, since vim.treesitter.start() still succeeds.
local function check_treesitter()
	local ok, ts_config = pcall(require, "nvim-treesitter.config")
	if not ok then
		vim.health.warn("nvim-treesitter is not loaded; skipped query check")
		return
	end

	local parsers = ts_config.get_installed("parsers")
	if #parsers == 0 then
		vim.health.warn("No treesitter parsers are installed")
		return
	end

	local missing = {}
	for _, lang in ipairs(parsers) do
		if #vim.treesitter.query.get_files(lang, "highlights") == 0 then
			table.insert(missing, lang)
		end
	end

	if #missing == 0 then
		vim.health.ok(("All %d treesitter parsers have a highlights query"):format(#parsers))
		return
	end

	table.sort(missing)
	vim.health.error(
		("%d of %d parsers have no highlights query: %s"):format(#missing, #parsers, table.concat(missing, ", ")),
		{
			"These filetypes render with no highlighting at all.",
			"Usually dangling symlinks after $HOME changed: ls -l " .. ts_config.get_install_dir("queries"),
			"Fix with :TSInstall! " .. table.concat(missing, " "),
		}
	)
end

function M.check()
	vim.health.start("Custom Configuration")

	-- Check settings file
	local settings_file = Custom.state.file()
	if vim.fn.filereadable(settings_file) == 1 then
		vim.health.ok("Settings file exists: " .. settings_file)

		local ok, content = pcall(vim.fn.readfile, settings_file)
		if ok and #content > 0 then
			local success, data = pcall(vim.json.decode, table.concat(content))
			if success then
				vim.health.ok("Settings file is valid JSON")
			else
				vim.health.error("Settings file contains invalid JSON")
			end
		end
	else
		vim.health.warn("Settings file does not exist (will be created on first save)")
	end

	-- Check current theme
	local theme = Custom.colorscheme.name
	if theme_exists(theme) then
		vim.health.ok("Current theme '" .. theme .. "' is installed")
	else
		vim.health.error("Current theme '" .. theme .. "' is not installed")
	end

	-- Check state consistency
	local saved = Custom.state.load("theme", {})
	if saved.name == Custom.colorscheme.name and saved.transparent == Custom.colorscheme.transparent then
		vim.health.ok("In-memory state matches saved state")
	else
		vim.health.warn("In-memory state differs from saved state (will sync on next save)")
	end

	vim.health.start("Custom Treesitter")
	check_treesitter()
end

return M
