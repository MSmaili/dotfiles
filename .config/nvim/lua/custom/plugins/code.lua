return {
	{ "tpope/vim-repeat", keys = { { "." }, { ";" } } },
	-- opposite and increment/decrement
	-- Generate documentation
	{
		"jeangiraldoo/codedocs.nvim",
		keys = {
			{
				"<leader>cn",
				":Codedocs<cr>",
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
