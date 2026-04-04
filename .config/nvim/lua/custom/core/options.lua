local options = {
	------------------------------
	-- Indention options
	------------------------------
	expandtab = true, -- convert tabs to spaces
	shiftwidth = 2, -- the number of spaces inserted for each indentation
	smartindent = true, -- make indenting smarter again
	smarttab = true, -- Insert “tabstop” number of spaces when the “tab” key is pressed.
	tabstop = 2, -- insert 2 spaces for a tab
	autoindent = true, -- lines inherit the indentation of previous lines.
	breakindent = true, -- enable break indent

	------------------------------
	-- Search options
	------------------------------
	ignorecase = true, -- ignore case in search patterns
	hlsearch = true, -- highlight all matches on previous search pattern
	smartcase = true, -- switch to case sensitve if we use uppercase letters smart case
	incsearch = true, -- incremental search that shows partial matches.
	inccommand = "split", -- update changes right away

	------------------------------
	-- Performance options
	------------------------------
	lazyredraw = false, -- Don’t update screen during macro and script execution
	updatetime = 300, -- faster completion (4000ms default)
	timeoutlen = 500, -- time to wait for a mapped sequence to complete (in milliseconds)

	------------------------------
	-- Text rendering options
	------------------------------
	scrolloff = 8, -- minimal number of screen lines to keep above and below the cursor
	sidescrolloff = 8, -- minimal number of screen columns either side of cursor if wrap is `false`
	wrap = false, -- display lines as one long line
	linebreak = true, -- companion to wrap, don't split words
	syntax = "enable",
	whichwrap = "bs<>[]hl", -- which "horizontal" keys are allowed to travel to prev/next line
	numberwidth = 4, -- set number column width to 2 {default 4}
	signcolumn = "yes", -- always show the sign column, otherwise it would shift the text each time
	-- conceallevel = 0, -- so that `` is visible in markdown files
	fileencoding = "utf-8", -- the encoding written to a file

	------------------------------
	-- UI options
	------------------------------
	-- cmdheight = 0, -- more space in the neovim command line for displaying messages
	pumheight = 10, -- pop up menu height
	showtabline = 0, -- always show tabs
	mouse = "a", -- allow the mouse to be used in neovim
	number = true, -- set numbered lines
	relativenumber = true, -- set relative numbered lines
	title = false, -- the file currently being edited
	showmode = false, -- we don't need to see mode, we have statusline
	termguicolors = true, -- set term gui colors (most terminals support this)
	laststatus = 3, -- when to have a status line (options from 0-3) 2 default
	showmatch = true, -- Show matching brackets when text indicator is over them
	mat = 2, -- How many tenths of a second to blink when matching brackets
	cursorline = true, -- highlight the current line

	------------------------------
	-- Split options
	------------------------------
	splitbelow = true, -- force all horizontal splits to go below current window
	splitright = true, -- force all vertical splits to go to the right of current window

	------------------------------
	-- Miscellaneous options
	----------------------------
	swapfile = false, -- creates a swapfile
	undofile = true, -- enable persistent undo
	-- undodir=$HOME/.local/state/nvim/undo
	writebackup = false, -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
	spell = false,

	------------------------------
	-- Fold text
	----------------------------
	foldlevel = 99,
	foldexpr = "v:lua.vim.treesitter.foldexpr()",
	foldmethod = "expr",
	foldenable = true,
	fillchars = {
		foldopen = "",
		foldclose = "",
		fold = " ",
		foldsep = " ",
		diff = "╱",
		msgsep = "─",
		eob = " ",
	},
	foldtext = "",

	------------------------------
	-- Other options
	------------------------------
	backup = false, -- creates a backup file
	-- clipboard = "unnamedplus", -- allows neovim to access the system clipboard
	completeopt = "menu,menuone,noselect", -- mostly just for cmp
}

vim.opt.wildignore:append({ "*/node_modules/*" })
vim.opt.messagesopt = "hit-enter,history:500,progress:"
vim.g.clipboard = "osc52"
vim.o.winborder = "rounded"

for k, v in pairs(options) do
	vim.opt[k] = v
end
