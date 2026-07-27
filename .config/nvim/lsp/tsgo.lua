---@type vim.lsp.Config
return {
	settings = {
		typescript = {
			suggest = {
				completeFunctionCalls = true,
				includeCompletionsForModuleExports = true,
				includeAutomaticOptionalChainCompletions = true,
			},
			inlayHints = {
				enumMemberValues = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				parameterNames = { enabled = "literals" },
				parameterTypes = { enabled = true },
				propertyDeclarationTypes = { enabled = true },
				variableTypes = { enabled = true },
			},
			format = { enable = false },
		},
		javascript = {
			suggest = { completeFunctionCalls = true },
			inlayHints = {
				functionLikeReturnTypes = { enabled = true },
				parameterNames = { enabled = "literals" },
				variableTypes = { enabled = true },
			},
			format = { enable = false },
		},
	},
}
