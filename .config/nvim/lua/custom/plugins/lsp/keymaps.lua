-- Toggle virtual_text
local virtual_text_enabled = Custom.lsp.diagnostic.virtual_text_enabled
local virtual_line_enabled = Custom.lsp.diagnostic.virtual_line_enabled

local function toggle_virtual_text()
	virtual_text_enabled = not virtual_text_enabled
	vim.diagnostic.config({
		virtual_text = virtual_text_enabled,
	})
	vim.notify("Virtual text: " .. (virtual_text_enabled and "On" or "Off"), vim.log.levels.INFO)
end

local function toggle_virtual_lines()
	virtual_line_enabled = not virtual_line_enabled
	vim.diagnostic.config({
		virtual_lines = virtual_line_enabled,
	})
	vim.notify("Virtual lines: " .. (virtual_line_enabled and "On" or "Off"), vim.log.levels.INFO)
end

return function(bufnr)
	local keymaps = {
		n = {
			------------------------------
			-- LSP
			------------------------------
			-- ["<leader>cr"] = { vim.lsp.buf.rename, desc = "Rename", buffer = bufnr },
			-- ["<leader>ca"] = { vim.lsp.buf.code_action, desc = "Action", buffer = bufnr },
			["<leader>cS"] = { "<cmd>FzfLua lsp_document_symbols<CR>", desc = "Document Symbols", buffer = bufnr },
			["<leader>ci"] = {
				"<cmd>FzfLua lsp_incoming_calls<CR>",
				desc = "List incoming calls (FZF)",
				buffer = bufnr,
			},
			["<leader>cd"] = { vim.diagnostic.open_float, desc = "Show diagnostics", buffer = bufnr },
			------------------------------
			-- Hover
			------------------------------
			["K"] = { vim.lsp.buf.hover, desc = "Hover Documentation", buffer = bufnr },

			------------------------------
			-- Workspace
			------------------------------
			["<leader>cwa"] = { vim.lsp.buf.add_workspace_folder, desc = "Workspace Add Folder", buffer = bufnr },
			["<leader>cwr"] = {
				vim.lsp.buf.remove_workspace_folder,
				desc = "Workspace Remove Folder",
				buffer = bufnr,
			},
			["<leader>cwd"] = { ":FzfLua diagnostics_workspace<CR>", desc = "Workspace diagnostics", buffer = bufnr },

			------------------------------
			-- LSP
			------------------------------
			["gd"] = { ":FzfLua lsp_definitions<CR>", desc = "Peek definition", buffer = bufnr },
			-- grt, not gt: gt / gT are Vim's tab switches
			["grt"] = { ":FzfLua lsp_typedefs<CR>", desc = "Peek type definition", buffer = bufnr },
			["grr"] = { ":FzfLua lsp_references<CR>", desc = "Go to refrences", buffer = bufnr },
			["gra"] = {
				function()
					require("fzf-lua").lsp_code_actions({
						winopts = {
							relative = "cursor",
							width = 0.4,
							height = 0.4,
							row = 1,
							preview = { horizontal = "up:70%" },
						},
						multiprocess = true,
					})
				end,
				desc = "Code action",
				buffer = bufnr,
			},
			["gD"] = {
				function()
					require("fzf-lua").lsp_definitions({ jump1 = true })
				end,
				desc = "[G]oto [D]eclaration",
				buffer = bufnr,
			},
			["gI"] = { ":FzfLua lsp_implementations<CR>", desc = "[G]oto [I]mplementation", buffer = bufnr },
			["<leader>uvt"] = { toggle_virtual_text, desc = "Toggle virtual text", buffer = bufnr },
			["<leader>uvl"] = { toggle_virtual_lines, desc = "Toggle virtual lines", buffer = bufnr },
		},
	}

	Custom.set_keymappings(keymaps)
end
