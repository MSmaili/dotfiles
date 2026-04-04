return {
	{ "tpope/vim-repeat", keys = { { "." }, { ";" } } },
	-- opposite and increment/decrement
	{
		"nat-418/boole.nvim",
		keys = { { "<C-a>" }, { "<C-x>" } },
		opts = {
			mappings = {
				increment = "<C-a>",
				decrement = "<C-x>",
			},
		},
	},

	-- Generate documentation
	{
		"danymat/neogen",
		config = true,
		keys = {
			{
				"<leader>cn",
				function()
					require("neogen").generate({})
				end,
				desc = "Generate func|class|type documentation",
			},
		},
	},

	{
		"andrewferrier/debugprint.nvim",
		opts = {},
		keys = {
			{ "g?v", mode = { "n", "x" }, desc = "Veriable log" },
			{ "g?V", mode = { "n", "x" }, desc = "Veriable log above" },
			{ "g?p", mode = { "n", "x" }, desc = "Plain debug log below" },
			{ "g?P", mode = { "n", "x" }, desc = "Plain debug log below" },
		},
		version = "*",
	},
}
