-- Native TypeScript 7 server (`tsc --lsp`, the Go implementation).
---@type vim.lsp.Config
return {
	settings = {
		-- js/ts is the native server's namespace; typescript.*/javascript.* are
		-- only lower-precedence fallbacks.
		["js/ts"] = {
			suggest = {
				autoImports = true,
				includeAutomaticOptionalChainCompletions = true,
			},
		},
	},
}
