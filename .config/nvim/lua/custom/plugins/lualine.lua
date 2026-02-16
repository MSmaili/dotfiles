-------------------------------------------------
-- name : nvim-lualine
-- url  : https://github.com/nvim-lualine/lualine.nvim
-------------------------------------------------
local function arrow_all_buffers()
	local arrow = require("arrow.statusline")
	local filenames = vim.g.arrow_filenames or {}
	local current_index = arrow.is_on_arrow_file()

	if #filenames == 0 then
		return ""
	end

	local parts = {}
	table.insert(parts, "󱡁 ")

	for i, _ in ipairs(filenames) do
		local label = arrow.text_for_statusline(_, i)
		local highlighted_label

		if i == current_index then
			highlighted_label = "%#ArrowCurrentFile#[" .. label .. "]"
		else
			highlighted_label = "%#ArrowFileIndex#" .. label
		end

		table.insert(parts, highlighted_label)

		if i < #filenames then
			table.insert(parts, "%*")
		end
	end

	table.insert(parts, "%*")

	return table.concat(parts)
end

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	opts = function()
		local fileName = require("lualine.components.filename"):extend()
		fileName.apply_icon = require("lualine.components.filetype").apply_icon
		fileName.icon_hl_cache = {}

		return {
			options = {
				theme = "auto",
				icons_enabled = true,
				component_separators = "",
				section_separators = "",
			},
			sections = {
				lualine_a = {
					{
						"mode",
						fmt = function(str)
							local m = vim.api.nvim_get_mode().mode
							if m == "\22" then
								return "C-V"
							end
							return str:sub(1, 1)
						end,
					},
				},
				lualine_b = {
					{ arrow_all_buffers },
				},
				lualine_c = {
					{
						fileName,
						path = 1,
						symbols = { modified = " ", readonly = "", unnamed = " " },
						colored = true,
					},
				},
				lualine_x = {
					{
						"lsp_status",
						symbols = {
							spinner = {
								"󰫃",
								"󰫄",
								"󰫅",
								"󰫆",
								"󰫇",
								"󰫈",
								"󰫈",
								"󰫇",
								"󰫆",
								"󰫅",
								"󰫄",
								"󰫃",
							},
							done = "",
						},
					},
					{
						require("wiremux").statusline.component(),
						padding = { left = 1, right = 1 },
					},
					{
						"diagnostics",
						symbols = { error = "◦", warn = "◦", info = "◦", hint = "◦" },
						padding = { left = 0, right = 1 },
						fmt = function(str)
							local count = str:match("%d+")
							if count then
								return str:gsub("%d+%s*", "")
							end
							return str
						end,
					},
				},
				lualine_y = {
					{ "filetype", icon_only = false, separator = "", padding = { left = 1, right = 1 } },
				},
				lualine_z = {
					{
						"progress",
						separator = " ",
						-- padding = { left = 1, right = 0 },
						fmt = function(str)
							local lines = vim.api.nvim_buf_line_count(0)
							return str .. "/" .. lines
						end,
					},
				},
			},
			inactive_winbar = {
				lualine_a = { "filename" },
				lualine_c = {
					{
						fileName,
						path = 1,
						symbols = { modified = " ", readonly = "", unnamed = " " },
						colored = true,
					},
				},
				lualine_y = {
					{
						"datetime",
						style = "default",
					},
				},
			},
			extensions = { "nvim-tree", "fzf", "lazy", "fugitive" },
		}
	end,
}
