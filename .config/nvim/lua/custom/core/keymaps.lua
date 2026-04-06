local M = {}

local keymap = vim.api.nvim_set_keymap
--
------------------------------
-- LEADER KEY
------------------------------
keymap("", "<Space>", "<Nop>", { noremap = true, silent = true })
keymap("", "<C-z>", "<Nop>", { noremap = true, silent = true }) -- turn off ctrl-z
vim.g.mapleader = " "
vim.g.maplocalleader = " "

------------------------------
-- Mappings
------------------------------
-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",
M.keyMaps = {
	-------------------------------------
	-- Normal Mode
	-------------------------------------
	n = {
		------------------------------
		-- Window
		------------------------------
		["<C-h>"] = "<C-w>h",
		["<C-j>"] = "<C-w>j",
		["<C-k>"] = "<C-w>k",
		["<C-l>"] = "<C-w>l",

		-- Close
		["<leader>qq"] = { ":q<CR>", desc = "Quit window" },
		["<leader>qQ"] = { ":qa!<CR>", desc = "Quit vim & do not save" },

		------------------------------
		-- UI
		------------------------------
		-- Toggle spellchker
		["<leader>us"] = { ":setlocal spell!<CR>", desc = "Toggle spellchker" },

		-- toggle transparentcy
		["<leader>ut"] = { ":ToggleTransparency<CR>", desc = "Toggle transparent theme" },

		-- Toggle pastemode
		["<leader>up"] = { ":setlocal paste!<CR>", desc = "Toggle paste mode" },
		["<leader>uf"] = {
			function()
				vim.g.autoformat = not vim.g.autoformat
				vim.notify(
					string.format("%s formatting", vim.g.autoformat and "Enabling" or "Disabling"),
					vim.log.levels.INFO
				)
			end,
			desc = "Toggle format on save",
		},

		["<leader>ub"] = {
			":Gitsigns toggle_current_line_blame<cr>",
			desc = "Toggle format on save",
		},

		------------------------------
		-- Resize splits with arrows
		------------------------------
		["<C-Up>"] = ":resize -2<CR>",
		["<C-Down>"] = ":resize +2<CR>",
		["<C-Left>"] = ":vertical resize -2<CR>",
		["<C-Right>"] = ":vertical resize +2<CR>",

		------------------------------
		-- Buffers
		------------------------------
		-- Navigate
		["<S-l>"] = {
			function()
				return require("arrow.persist").next()
			end,
			desc = "Go to next bookmark",
		},
		["<S-h>"] = {
			function()
				return require("arrow.persist").previous()
			end,
			desc = "Go to previous bookmark",
		},

		-- Save
		["<leader>w"] = ":w<CR>",

		-- Close
		["<leader>cm"] = ":Mason<CR>",
		-- ["<leader>C"] = ":bdelete!<CR>",

		-- SUDO save
		-- ["<leader>W"] = ":w !sudo -S tee % <CR>",

		------------------------------
		-- Open neo tree
		------------------------------
		-- ["<leader>e"] = ":NvimTreeToggle<CR>",

		------------------------------
		-- Text
		------------------------------
		-- Move text up/down
		["<A-j>"] = ":m .+1<CR>==",
		["<A-k>"] = ":m .-2<CR>==",

		-- Move half screen up/down and center
		["<C-d>"] = "<C-d>zz",
		["<C-u>"] = "<C-u>zz",

		-- Disable highlight
		["<leader>h"] = ":nohl<CR>",

		-- UNDO-TREE
		["<leader>gu"] = { ":Undotree<cr>", desc = "Toggle undotree" },

		------------------------------
		-- Plugin manager
		------------------------------
		["<leader>l"] = { "<cmd>Lazy<cr>", desc = "Toggle lazyVim" },
	},

	-------------------------------------
	-- Visual Mode
	-------------------------------------
	v = {
		------------------------------
		-- Text
		------------------------------
		-- Move text up/down
		["<A-j>"] = ":m '>+1<CR>gv=gv",
		["<A-k>"] = ":m '<-2<CR>gv=gv",

		-- Stay on indent
		["<"] = "<gv",
		[">"] = ">gv",

		-- Visual mode pressing # searches for the current selection
		["#"] = '"fy/\\V<C-R>f<CR>',
	},

	-------------------------------------
	-- Visual Block Mode
	-------------------------------------
	x = {
		------------------------------
		-- Text
		------------------------------
		-- Move text up/down
		["<A-j>"] = ":m '>+1<CR>gv-gv",
		["<A-k>"] = ":m '<-2<CR>gv-gv",
		-- Paste over selection: deleted text shifts into "1-"9, yanked text stays in ""
		["p"] = [[d"0p:if v:register == '"'<Bar>let @@=@0<Bar>endif<CR>]],
	},

	-------------------------------------
	-- Terminal Mode
	-------------------------------------
	t = {
		-- Terminal window navigation
		["<C-h>"] = "<C-\\><C-N><C-w>h",
		["<C-j>"] = "<C-\\><C-N><C-w>j",
		["<C-k>"] = "<C-\\><C-N><C-w>k",
		["<C-l>"] = "<C-\\><C-N><C-w>l",
	},

	-------------------------------------
	-- Command Mode
	-------------------------------------
	c = {
		-- Bash like keys
		["<C-A>"] = "<Home>",
		["<C-E>"] = "<END>",
		["<C-K>"] = "<C-U>",
		["<C-P>"] = "<Up>",
		["<C-N>"] = "<Down>",
	},
}

------------------------------
-- Set keymaps
------------------------------
Custom.set_keymappings(M.keyMaps)

-- j/k with count: save position to jumplist first (so Ctrl-O works), then move.
-- j/k without count: use gj/gk to move by visual lines (better for wrapped lines).
vim.keymap.set("n", "k", function()
	return vim.v.count > 0 and "m'" .. vim.v.count .. "k" or "gk"
end, { expr = true })
vim.keymap.set("n", "j", function()
	return vim.v.count > 0 and "m'" .. vim.v.count .. "j" or "gj"
end, { expr = true })

-- Yank to clipboard motion with gy
vim.keymap.set({ "n", "v", "o" }, "gy", '"+y', { desc = "Copy to clipboard" })
