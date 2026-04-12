return {
	"kndndrj/nvim-dbee",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"MattiasMTS/cmp-dbee",
	},
	build = function()
		require("dbee").install()
	end,
	keys = { { "<leader>D", "<cmd>Dbee open<cr>", desc = "Open Nvim DBEE" } },
	cmd = { "Dbee" },
	config = function()
		local source = require("dbee.sources")
		require("dbee").setup({
			sources = {
				source.EnvSource:new("DBEE_CONNECTIONS"),
			},
		})

		---@diagnostic disable-next-line: param-type-mismatch
		local base = vim.fs.joinpath(vim.fn.stdpath("state"), "dbee", "notes")
		local pattern = string.format("%s/.*", base)
		vim.filetype.add({
			extension = {
				sql = function(path, _)
					if path:match(pattern) then
						return "sql.dbee"
					end

					return "sql"
				end,
			},

			pattern = {
				[pattern] = "sql.dbee",
			},
		})
	end,
}
