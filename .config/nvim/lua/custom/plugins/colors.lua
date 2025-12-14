-- Theme
------------------------------
------------------------------
return {
	{
		"sainnhe/everforest",
		lazy = false,
		opts = {},
	},
	{
		"loctvl842/monokai-pro.nvim",
		lazy = false,
		opts = {},
	},
	{
		"webhooked/kanso.nvim",
		lazy = false,
		opts = {},
	},
	{
		"sho-87/kanagawa-paper.nvim",
		lazy = false,
		opts = {},
	},
	{
		"datsfilipe/vesper.nvim",
		opts = {},
		lazy = false,
	},
	{
		"olivercederborg/poimandres.nvim",
		lazy = false,
		opts = {},
	},
	{
		"sainnhe/gruvbox-material",
		opts = {},
		config = function()
			vim.cmd("let g:gruvbox_material_background = 'hard'")
		end,
	},
	{
		"rose-pine/neovim",
		name = "rose-pine",
		lazy = false,
		opts = {
			before_highlight = function(_, highlight)
				if highlight.undercurl then
					highlight.undercurl = false
				end
			end,
		},
	},
	{
		"sainnhe/sonokai",
		opts = {},
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		opts = {
			integrations = {
				cmp = true,
				treesitter = true,
				treesitter_context = true,
				notify = false,
				fzf = true,
				gitsigns = true,
				nvimtree = true,
				blink_cmp = true,
				snacks = {
					enabled = true,
					indent_scope_color = "lavender",
				},
				neotest = true,
				mason = true,
				illuminate = {
					enabled = true,
					lsp = false,
				},
				native_lsp = {
					enabled = true,
					virtual_text = {
						errors = { "italic" },
						hints = { "italic" },
						warnings = { "italic" },
						information = { "italic" },
						ok = { "italic" },
					},
					underlines = {
						errors = { "undercurl" },
						hints = { "undercurl" },
						warnings = { "undercurl" },
						information = { "undercurl" },
					},
					inlay_hints = {
						background = true,
					},
				},
				mini = { enabled = true },
			},
			styles = {},
			highlight_overrides = {
				all = function(_)
					return {
						LineNr = { fg = "#4b5481" },
					}
				end,
			},
		},
	},
	{
		"vague2k/vague.nvim",
		lazy = false,
		opts = {},
	},
	{
		"wtfox/jellybeans.nvim",
		lazy = false,
		opts = {
			italics = true,
			plugins = {
				all = true,
				auto = true,
			},
		},
	},
	{
		"KijitoraFinch/nanode.nvim",
		lazy = false,
		opts = {},
	},
	{
		"abhilash26/mapledark.nvim",
		lazy = false,
		opts = {},
	},
	{
		"folke/tokyonight.nvim",
		lazy = false,
		opts = {},
	},
}
