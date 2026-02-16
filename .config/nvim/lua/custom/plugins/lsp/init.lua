return {
	{
		"neovim/nvim-lspconfig",
		event = "VeryLazy",
		cmd = { "Mason" },
		dependencies = {
			{ "mason-org/mason.nvim", opts = { ui = { border = "rounded" } }, build = ":MasonUpdate" },
			"mason-org/mason-lspconfig.nvim",
			"echasnovski/mini.icons",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			"b0o/SchemaStore.nvim",
			"rrethy/vim-illuminate",
		},
		opts = {
			lsp_servers = {
				"html",
				"pbls",
				"vimls",
				"cssls",
				"astro",
				"robotframework-lsp",
			},
			tools = {
				"prettierd",
				"beautysh",
				"eslint_d",
				"goimports",
				"sonarlint-language-server",
				"gotests",
				"golangci-lint",
				"yamllint",
				"write-good",
				"stylua",
			},
		},
		config = function(_, opts)
			----------------------------------
			-- LSP attach
			----------------------------------
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("custom-lsp-attach", { clear = true }),
				callback = function(event)
					----------------------------------
					-- Load key mappings
					----------------------------------
					require("custom.plugins.lsp.keymaps")(event.buf)

					----------------------------------
					-- Add highlights
					----------------------------------
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					local methods = vim.lsp.protocol.Methods
					if client and client:supports_method(methods.textDocument_documentHighlight) then
						local custom_higlight_name = "custom-lsp/highlight"
						local cursor_higlights_group =
							vim.api.nvim_create_augroup(custom_higlight_name, { clear = false })

						vim.api.nvim_create_autocmd({ "CursorHold", "InsertLeave" }, {
							buffer = event.buf,
							group = cursor_higlights_group,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
							buffer = event.buf,
							group = cursor_higlights_group,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("custom-lsp/detach", { clear = true }),
							callback = function(detach_event)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({
									group = custom_higlight_name,
									buffer = detach_event.buf,
								})
							end,
						})

						require("fzf-lua").register_ui_select()
					end

					----------------------------------
					-- inlay_hint
					----------------------------------
					if client and client:supports_method(methods.textDocument_inlayHint) then
						vim.keymap.set("n", "<leader>uh", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
						end, { desc = "Toggle inlay hints", buffer = event.buf })
					end
				end,
			})

			----------------------------------
			-- Server configuration
			----------------------------------
			-- Get server names from after/lsp
			local servers = {}
			local lsp_servers_path = vim.fn.stdpath("config") .. "/lsp"

			for file in vim.fs.dir(lsp_servers_path) do
				local name = file:match("(.+)%.lua$")
				if name then
					servers[name] = true
				end
			end
			----------------------------------
			-- Add servers automaticlly
			----------------------------------
			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, opts.lsp_servers)
			vim.list_extend(ensure_installed, opts.tools)

			require("mason-lspconfig").setup({
				automatic_enable = {
					exclude = { "tailwindcss" },
				},
				ensure_installed = {},
			})

			require("mason-tool-installer").setup({
				ensure_installed = ensure_installed,
				auto_update = true,
				run_on_start = true,
			})

			----------------------------------
			-- Diagnostics
			----------------------------------
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			vim.diagnostic.config({
				virtual_text = {
					spacing = 4,
					source = "if_many",
					prefix = "●",
				},
				underline = true,
				virtual_lines = Custom.lsp.diagnostic.virtual_line_enabled,
				update_in_insert = false,
				document_highlight = {
					enabled = true,
				},
				codelens = {
					enabled = false,
				},
				severity_sort = true,
				float = {
					border = "rounded",
					source = "if_many",
					-- Show severity icons as prefixes.
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
