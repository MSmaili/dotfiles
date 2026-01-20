return {
	{
		"neovim/nvim-lspconfig",
		event = "VeryLazy",
		dependencies = {
			"echasnovski/mini.icons",
			"b0o/SchemaStore.nvim",
			"rrethy/vim-illuminate",
		},
		config = function()
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("custom-lsp-attach", { clear = true }),
				callback = function(event)
					require("custom.plugins.lsp.keymaps")(event.buf)

					local client = vim.lsp.get_client_by_id(event.data.client_id)
					local methods = vim.lsp.protocol.Methods

					if client and client:supports_method(methods.textDocument_documentHighlight) then
						local highlight_group = "custom-lsp/highlight"
						local augroup = vim.api.nvim_create_augroup(highlight_group, { clear = false })

						vim.api.nvim_create_autocmd({ "CursorHold", "InsertLeave" }, {
							buffer = event.buf,
							group = augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
							buffer = event.buf,
							group = augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("custom-lsp/detach", { clear = true }),
							callback = function(detach_event)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = highlight_group, buffer = detach_event.buf })
							end,
						})

						require("fzf-lua").register_ui_select()
					end

					if client and client:supports_method(methods.textDocument_inlayHint) then
						vim.keymap.set("n", "<leader>uh", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
						end, { desc = "Toggle inlay hints", buffer = event.buf })
					end
				end,
			})

			-- Enable servers (configs loaded from lsp/*.lua)
			vim.lsp.enable({
				"lua_ls",
				"gopls",
				"clangd",
				"vtsls",
				"eslint",
				"jsonls",
				"yamlls",
				"tailwindcss",
				"html",
				"cssls",
				"astro",
				"bashls",
				"vimls",
				"sonarlint",
			})

			-- Diagnostics
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			vim.diagnostic.config({
				virtual_text = { spacing = 4, source = "if_many", prefix = "●" },
				underline = true,
				virtual_lines = Custom.lsp.diagnostic.virtual_line_enabled,
				update_in_insert = false,
				document_highlight = { enabled = true },
				codelens = { enabled = false },
				severity_sort = true,
				float = {
					border = "rounded",
					source = "if_many",
					prefix = function(diag)
						local level = vim.diagnostic.severity[diag.severity]
						local prefix = string.format(" %s ", signs[level])
						return prefix, "Diagnostic" .. level:gsub("^%l", string.upper)
					end,
				},
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = signs.Error,
						[vim.diagnostic.severity.WARN] = signs.Warn,
						[vim.diagnostic.severity.HINT] = signs.Hint,
						[vim.diagnostic.severity.INFO] = signs.Info,
					},
				},
			})
		end,
	},
}
