return {
	"esmuellert/codediff.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	cmd = "CodeDiff",
	keys = {
		{ "<leader>gs", "<cmd>CodeDiff<cr>", desc = "Git diff 3-way-split" },
	},
}
