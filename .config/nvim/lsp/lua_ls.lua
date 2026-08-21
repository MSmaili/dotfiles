---@type vim.lsp.Config
return {
	settings = {
		Lua = {
			runtime = {
				-- Neovim is LuaJIT; without this lua_ls assumes 5.4 and flags 5.1 builtins
				version = "LuaJIT",
				path = { "lua/?.lua", "lua/?/init.lua" },
			},
			workspace = {
				checkThirdParty = false,
				library = vim.api.nvim_get_runtime_file("", true),
				maxPreload = 1000, -- Limit preloaded files for performance
				preloadFileSize = 150, -- Skip large files
			},
			completion = {
				callSnippet = "Replace",
				keywordSnippet = "Replace",
				showWord = "Disable", -- Disable noisy word completions
			},
			diagnostics = {
				globals = { "vim" },
				severity = {
					["unused-local"] = "Hint",
					["redefined-local"] = "Warning",
				},
			},
			hint = {
				enable = true,
				setType = true, -- Show type hints for variables
				paramType = true, -- Show parameter type hints
				await = true, -- Show hints for async functions
			},
			semantic = {
				enable = true, -- Enable semantic tokens for better syntax highlighting
			},
			telemetry = {
				enable = false, -- Disable telemetry
			},
			format = {
				enable = true, -- Enable formatting
				defaultConfig = {
					indent_style = "space",
					indent_size = "2",
				},
			},
		},
	},
}
