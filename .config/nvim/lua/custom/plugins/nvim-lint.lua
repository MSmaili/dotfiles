return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		-- local eslint_filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "astro" }
		-- for _, ft in ipairs(eslint_filetypes) do
		-- 	lint.linters_by_ft[ft] = { "eslint_d" }
		-- end

		lint.linters_by_ft = vim.tbl_extend("force", lint.linters_by_ft, {
			go = { "golangcilint" },
			yaml = { "yamllint" },
			proto = { "protolint" },
			json = {},
			zsh = { "zsh" },
			markdown = {},
		})

		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

		vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "BufEnter" }, {
			group = lint_augroup,
			callback = function()
				lint.try_lint()
			end,
		})

		vim.keymap.set("n", "<leader>cl", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end,
}
