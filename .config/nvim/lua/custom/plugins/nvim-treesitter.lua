-------------------------------------------------
-- name : nvim-treesitter
-- url  : https://github.com/nvim-treesitter/nvim-treesitter
-------------------------------------------------
return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = "BufReadPost",
	branch = "main",
	dependencies = {
		{
			"nvim-treesitter/nvim-treesitter-context",
			config = true,
			opts = {
				enable = true,
				max_lines = 3,
				multiline_threshold = 1,
				min_window_height = 20,
			},

			keys = {
				{ "<leader>uC", ":TSContextToggle<CR>", desc = "Toggle TSContext" },
				{
					"[c",
					":lua require('treesitter-context').go_to_context()<cr>",
					silent = true,
					desc = "Go to context",
				},
			},
		},
	},
	opts = {
		ensure_installed = {
			"javascript",
			"typescript",
			"tsx",
			"tmux",
			"lua",
			"jsdoc",
			"json",
			"json5",
			"jsonc",
			"prisma",
			"sql",
			"regex",
			"html",
			"css",
			"scss",
			"jsdoc",
			"robot",
			"astro",
			"go",
			"gomod",
			"bash",
			"markdown",
			"http",
			"markdown_inline",
			"query",
			"vim",
			"vimdoc",
			"gitignore",
			"gitcommit",
			"git_config",
			"diff",
			"http",
			"git_rebase",
			"toml",
			"yaml",
		},
	},
	config = function(_, opts)
		require("nvim-treesitter").setup()
		require("nvim-treesitter").install(opts.ensure_installed)

		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				if vim.api.nvim_buf_line_count(0) > 10000 then
					return
				end
				pcall(vim.treesitter.start)
			end,
		})
	end,
}
