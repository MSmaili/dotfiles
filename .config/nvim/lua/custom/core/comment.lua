-- gco / gcO / gcA on top of Neovim's built-in commenting (:h commenting).
local M = {}

-- Filetype-level fallbacks for filetypes Neovim ships no 'commentstring' for.
-- JSX and other node-level cases come from treesitter metadata (nvim-treesitter
-- sets `bo.commentstring` in queries/jsx/highlights.scm), not from here.
-- Don't add astro: $VIMRUNTIME/ftplugin/astro.vim already picks //, /* */ or
-- <!-- --> per scope on CursorMoved, which is strictly better than a fixed one.
M.commentstrings = {
	robot = "# %s",
	gotmpl = "{{/* %s */}}",
	rest = "# %s",
}

--- Mirrors the resolution order of runtime/lua/vim/_comment.lua.
---@return string
local function commentstring_at_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local caps = vim.treesitter.get_captures_at_pos(0, row, col)
	for i = #caps, 1, -1 do
		local id, metadata = caps[i].id, caps[i].metadata
		local cms = metadata["bo.commentstring"] or (metadata[id] and metadata[id]["bo.commentstring"])
		if type(cms) == "string" then
			return cms
		end
	end

	local parser = vim.treesitter.get_parser(0, nil, { error = false })
	if parser then
		local tree = parser:language_for_range({ row, col, row, col })
		for _, ft in ipairs(vim.treesitter.language.get_filetypes(tree:lang())) do
			local cms = vim.filetype.get_option(ft, "commentstring")
			if type(cms) == "string" and cms ~= "" then
				return cms
			end
		end
	end

	return vim.bo.commentstring
end

---@return string left, string right
local function comment_parts()
	local left, right = commentstring_at_cursor():match("^(.*)%%s(.*)$")
	return vim.trim(left or ""), vim.trim(right or "")
end

--- Insert an empty comment and leave the cursor inside it, in insert mode.
---@param where "above"|"below"|"eol"
function M.insert(where)
	local left, right = comment_parts()
	if left == "" then
		vim.notify("No commentstring for this buffer", vim.log.levels.WARN)
		return
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local current = vim.api.nvim_get_current_line()
	local text, target_row

	if where == "eol" then
		text = current .. (current:match("%s$") and "" or " ") .. left .. " "
		target_row = row
		vim.api.nvim_buf_set_lines(0, row - 1, row, false, { text .. (right ~= "" and " " .. right or "") })
	else
		-- Indent is copied rather than opening the line with o/O, which would let
		-- autopairs mangle the comment markers.
		text = current:match("^%s*") .. left .. " "
		local at = where == "above" and row - 1 or row
		target_row = where == "above" and row or row + 1
		vim.api.nvim_buf_set_lines(0, at, at, false, { text .. (right ~= "" and " " .. right or "") })
	end

	local col = #text
	if right == "" then
		vim.api.nvim_win_set_cursor(0, { target_row, math.max(col - 1, 0) })
		vim.cmd("startinsert!")
	else
		vim.api.nvim_win_set_cursor(0, { target_row, col })
		vim.cmd("startinsert")
	end
end

function M.setup(opts)
	M.commentstrings = vim.tbl_extend("force", M.commentstrings, (opts or {}).commentstrings or {})

	-- The `filetypeplugin` augroup already exists when init.lua runs, so this
	-- autocmd is registered after it and wins. vim.filetype.get_option() picks
	-- these up too, which is what the injected-language path above needs.
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("custom.commentstring", { clear = true }),
		pattern = vim.tbl_keys(M.commentstrings),
		callback = function(ev)
			vim.bo[ev.buf].commentstring = M.commentstrings[ev.match]
		end,
	})

	local map = function(lhs, where, desc)
		vim.keymap.set("n", lhs, function()
			M.insert(where)
		end, { desc = desc })
	end

	map("gco", "below", "Comment line below")
	map("gcO", "above", "Comment line above")
	map("gcA", "eol", "Comment at end of line")
end

return M
