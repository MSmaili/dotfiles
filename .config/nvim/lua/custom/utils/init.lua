Custom = {
	colorscheme = {
		transparent = true,
		name = "catppuccin",
	},
	explorer = {},
	lsp = {
		diagnostic = {
			virtual_text_enabled = true,
			virtual_line_enabled = false,
		},
	},
	obsidian = {
		workspaces = {
			{ name = "work", path = "~/.vaults/work" },
			{ name = "personal", path = "~/.vaults/personal" },
		},
		default_workspace = "work",
	},
	state = require("custom.state"),
	theme = require("custom.utils.theme"),
}

-- Load saved theme settings
Custom.colorscheme = Custom.state.load("theme", Custom.colorscheme)

-- Load saved Obsidian settings
Custom.obsidian = Custom.state.load("obsidian", Custom.obsidian)

-- Set key-map by table
function Custom.set_keymappings(keymaps)
	local default_options = {
		n = { noremap = true, silent = true },
		t = { silent = true },
	}

	for vimMode, keyMaps in pairs(keymaps) do
		local base_options = default_options[vimMode] or default_options["n"]

		for keyMap, commandOrTable in pairs(keyMaps) do
			local command = commandOrTable

			if type(commandOrTable) == "table" then
				command = commandOrTable[1]
				base_options = vim.tbl_extend("force", base_options, commandOrTable)
				base_options[1] = nil
			end

			vim.keymap.set(vimMode, keyMap, command, base_options)
		end
	end
end
