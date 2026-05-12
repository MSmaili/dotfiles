local M = {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
}

local function keymaps()
	local gitsigns = require("gitsigns")

	return {
		n = {
			["<leader>ghd"] = { gitsigns.diffthis, desc = "Diff This" },
			["<leader>ga"] = { gitsigns.get_actions, desc = "Get git actions" },
			["<leader>ghb"] = { gitsigns.blame_line, desc = "View git blame line" },
			["<leader>ghp"] = { gitsigns.preview_hunk, desc = "View git hunk per current line" },
			["]h"] = { gitsigns.next_hunk, desc = "Next hunk" },
			["[h"] = { gitsigns.prev_hunk, desc = "Prev hunk" },
			["<leader>ghr"] = { gitsigns.reset_hunk, desc = "Reset current hunk" },
			["<leader>ghs"] = { gitsigns.stage_hunk, desc = "Stage current hunk" },
			["<leader>gtd"] = { gitsigns.toggle_deleted, desc = "Git toggle deleted" },
			["<leader>gts"] = { gitsigns.toggle_signs, desc = "Git toggle signs" },
			["<leader>gtw"] = { gitsigns.toggle_word_diff, desc = "Git toggle word diff" },
			["<leader>gtb"] = { gitsigns.toggle_current_line_blame, desc = "Git toggle current line blame" },
		},
	}
end

function M.config()
	local gitsigns = require("gitsigns")

	gitsigns.setup({
		current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
	})

	-- Git signs
	Custom.set_keymappings(keymaps())
end

return M
