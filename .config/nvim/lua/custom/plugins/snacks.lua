return {
	"folke/snacks.nvim",
	lazy = false,
	keys = {
		{
			"<leader>gg",
			function()
				require("snacks").lazygit.open()
			end,
			desc = "Open LazyGit",
		},
		{
			"<leader>uc",
			function()
				require("snacks").zen()
			end,
			desc = "Toggle center mode",
		},
		{
			"<leader>x",
			function()
				Snacks.scratch()
			end,
			desc = "Toggle Scratch Buffer",
		},
		{
			"<leader>S",
			function()
				Snacks.scratch.select()
			end,
			desc = "Select Scratch Buffer",
		},
	},
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		indent = { enabled = true, animate = { enabled = false } },
		lazygit = { enabled = true },
		statuscolumn = { enabled = true },
		zen = { enabled = true, toggles = { dim = false } },
		quickfile = { enabled = true },

		explorer = { enabled = false, replace_netrw = false },
		dashboard = { enabled = false },
		scroll = { enabled = false },
		input = { enabled = false },
		notifier = { enabled = false },
		words = { enabled = false },
	},
}
