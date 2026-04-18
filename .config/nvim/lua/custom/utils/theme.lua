local M = {}
local transparent_groups = {
	"Normal",
	"EndOfBuffer",
	"NormalFloat",
	"FloatBorder",
	"FloatTitle",
	"SignColumn",
	"NormalNC",
	"FoldColumn",
	"Folded",
	"NormalSB",
	"Pmenu",
	"PmenuSbar",
	"NonText",
	"SpecialKey",
	"VertSplit",
	"WinSeparator",
}
local theme_highlights = {}
local resolved_theme_highlights = {}

local function get_highlight(name, opts)
	local ok, definition = pcall(vim.api.nvim_get_hl, 0, vim.tbl_extend("keep", {
		name = name,
		create = false,
	}, opts or {}))
	if ok and type(definition) == "table" then
		return definition
	end

	return {}
end

local function save_config()
	Custom.state.save("theme", {
		name = Custom.colorscheme.name,
		transparent = Custom.colorscheme.transparent,
	})
end

local function capture_theme_highlights()
	theme_highlights = {}
	resolved_theme_highlights = {}

	for _, hl in ipairs(transparent_groups) do
		theme_highlights[hl] = get_highlight(hl, { link = true })
		resolved_theme_highlights[hl] = get_highlight(hl, { link = false })
	end
end

local function restore_theme_highlights()
	for _, hl in ipairs(transparent_groups) do
		vim.api.nvim_set_hl(0, hl, vim.deepcopy(theme_highlights[hl] or {}))
	end
end

local function sync_transparency()
	if vim.tbl_isempty(theme_highlights) then
		capture_theme_highlights()
	end

	if not Custom.colorscheme.transparent then
		restore_theme_highlights()
		return
	end

	for _, hl in ipairs(transparent_groups) do
		local definition = vim.deepcopy(resolved_theme_highlights[hl] or {})
		definition.link = nil
		definition.bg = "NONE"
		definition.ctermbg = "NONE"
		vim.api.nvim_set_hl(0, hl, definition)
	end
end

local function refresh_theme_decorations()
	vim.schedule(function()
		local ok, lualine = pcall(require, "lualine")
		if ok then
			lualine.setup(require("custom.plugins.lualine").opts())
		end

		vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "LspReferenceText", underline = true })
		vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "LspReferenceRead", underline = true })
		vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "LspReferenceWrite", underline = true })
	end)
end

local function apply_theme_state()
	capture_theme_highlights()
	sync_transparency()
	refresh_theme_decorations()
end

function M.apply(theme, transparent)
	vim.opt.termguicolors = true
	theme = theme or Custom.colorscheme.name

	local previous_theme = Custom.colorscheme.name
	local previous_transparent = Custom.colorscheme.transparent

	Custom.colorscheme.name = theme
	if transparent ~= nil then
		Custom.colorscheme.transparent = transparent
	end

	local ok = pcall(vim.cmd.colorscheme, theme)
	if not ok then
		Custom.colorscheme.name = previous_theme
		Custom.colorscheme.transparent = previous_transparent
		vim.notify(string.format("Failed to load theme: %s", theme), vim.log.levels.ERROR)
		return false
	end

	apply_theme_state()
	save_config()

	vim.notify(string.format("Theme: %s (%s)", theme, Custom.colorscheme.transparent and "transparent" or "opaque"))
	return true
end

function M.toggle_transparency()
	Custom.colorscheme.transparent = not Custom.colorscheme.transparent
	sync_transparency()
	save_config()
	refresh_theme_decorations()
	vim.notify(string.format("Transparency: %s", Custom.colorscheme.transparent and "on" or "off"))
end

return M
