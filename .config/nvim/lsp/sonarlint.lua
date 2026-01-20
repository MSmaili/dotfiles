---@type vim.lsp.Config
return {
	cmd = { "sonarlint-language-server", "-stdio" },
	filetypes = { "python", "javascript", "typescript", "java", "go", "php", "ruby" },
	root_markers = { ".git" },
	init_options = {
		productKey = "nvim",
		telemetryStorage = "off",
		productName = "Neovim",
		productVersion = vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
		showVerboseLogs = false,
	},
}
