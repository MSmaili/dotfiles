local M = {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
}

-- gitsigns.diffthis() has no counterpart to close the diff, so toggle it here.
local function toggle_diffthis()
	local closed = false

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
		if vim.startswith(bufname, "gitsigns://") then
			vim.api.nvim_win_close(win, true)
			closed = true
		end
	end

	if closed then
		-- Closing one side leaves 'diff' set on the remaining window.
		vim.cmd("diffoff!")
	else
		require("gitsigns").diffthis()
	end
end

-- gitsigns hunks normally, native ]c / [c in a diff view. `normal!` skips
-- mini.bracketed, which owns ]c / [c globally.
local function diff_aware_nav(dir)
	return function()
		if vim.wo.diff then
			vim.cmd("silent! normal! " .. vim.v.count1 .. (dir == "next" and "]c" or "[c"))
		else
			require("gitsigns").nav_hunk(dir)
		end
	end
end

-- Full inline diff in the current buffer: changed lines highlighted, intra-line
-- word diff, and deleted lines as virtual lines. State comes from the first
-- toggle's return value, so <leader>gtl/gtw/gtd can't desync it.
local function toggle_diff_overlay()
	local gitsigns = require("gitsigns")
	local on = gitsigns.toggle_linehl()
	gitsigns.toggle_word_diff(on)
	gitsigns.toggle_deleted(on)
	vim.notify("Git diff overlay " .. (on and "on" or "off"), vim.log.levels.INFO)
end

local function keymaps()
	local gitsigns = require("gitsigns")

	return {
		n = {
			["<leader>gd"] = { toggle_diffthis, desc = "Diff This (toggle)" },
			["<leader>ga"] = { gitsigns.get_actions, desc = "Get git actions" },
			["<leader>ghb"] = { gitsigns.blame_line, desc = "View git blame line" },
			["<leader>ghp"] = { gitsigns.preview_hunk, desc = "View git hunk per current line" },
			["]h"] = { diff_aware_nav("next"), desc = "Next hunk / change" },
			["[h"] = { diff_aware_nav("prev"), desc = "Prev hunk / change" },
			["<leader>ghr"] = { gitsigns.reset_hunk, desc = "Reset current hunk" },
			["<leader>ghs"] = { gitsigns.stage_hunk, desc = "Stage current hunk" },

			["<leader>gto"] = { toggle_diff_overlay, desc = "Git toggle diff overlay" },
			["<leader>gtb"] = { gitsigns.toggle_current_line_blame, desc = "Git toggle current line blame" },
			["<leader>gtd"] = { gitsigns.toggle_deleted, desc = "Git toggle deleted lines" },
			["<leader>gtl"] = { gitsigns.toggle_linehl, desc = "Git toggle line highlight" },
			["<leader>gts"] = { gitsigns.toggle_signs, desc = "Git toggle signs" },
			["<leader>gtw"] = { gitsigns.toggle_word_diff, desc = "Git toggle word diff" },
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

	-- Hunk text object, matching codediff's "ih"
	vim.keymap.set({ "o", "x" }, "ih", gitsigns.select_hunk, { desc = "Inner git hunk" })
	vim.keymap.set({ "o", "x" }, "ah", gitsigns.select_hunk, { desc = "Around git hunk" })
end

return M
