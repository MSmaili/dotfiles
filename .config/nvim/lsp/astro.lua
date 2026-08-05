---@type vim.lsp.Config
return {
	cmd = { "astro-ls", "--stdio" },
	filetypes = { "astro" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
	workspace_required = true,
	init_options = {
		typescript = {},
	},
	before_init = function(_, config)
		config.init_options.typescript.tsdk = vim.fs.joinpath(
			config.root_dir,
			"node_modules",
			"@typescript",
			"typescript6",
			"lib"
		)
	end,
}
