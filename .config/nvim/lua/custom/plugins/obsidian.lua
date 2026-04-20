local settings_state = rawget(_G, "Custom") and Custom.state or require("custom.state")

local function fallback_workspaces()
	return {
		{ name = "work", path = "~/.vaults/work" },
		{ name = "personal", path = "~/.vaults/personal" },
	}
end

local function load_workspace_settings()
	local settings = rawget(_G, "Custom") and Custom.obsidian or {}
	local configured = settings.workspaces
	local workspaces = vim.deepcopy(configured or fallback_workspaces())

	if #workspaces == 0 then
		workspaces = fallback_workspaces()
	end

	local default_workspace = settings.default_workspace
	if type(default_workspace) ~= "string" or default_workspace == "" then
		default_workspace = workspaces[1] and workspaces[1].name or nil
	end

	return workspaces, default_workspace
end

local workspaces, default_workspace = load_workspace_settings()

local function workspace_by_name(name)
	for _, workspace in ipairs(workspaces) do
		if workspace.name == name then
			return workspace
		end
	end

	return nil
end

if default_workspace and not workspace_by_name(default_workspace) then
	default_workspace = workspaces[1] and workspaces[1].name or nil
end

local function ordered_workspaces()
	local preferred = default_workspace and workspace_by_name(default_workspace) or nil
	if not preferred then
		return vim.deepcopy(workspaces)
	end

	local ordered = { preferred }
	for _, workspace in ipairs(workspaces) do
		if workspace.name ~= default_workspace then
			table.insert(ordered, workspace)
		end
	end

	return ordered
end

local function obsidian(cmd, args)
	local argv = { cmd }
	if args then
		for _, arg in ipairs(args) do
			table.insert(argv, arg)
		end
	end
	vim.cmd({ cmd = "Obsidian", args = argv })
end

local function obsidian_cmd(cmd)
	return function()
		obsidian(cmd)
	end
end

local function save_default_workspace(name)
	if not workspace_by_name(name) then
		return
	end

	default_workspace = name

	if rawget(_G, "Custom") and Custom.obsidian then
		Custom.obsidian.default_workspace = name
	end

	local saved = settings_state.load("obsidian", {})
	if type(saved) ~= "table" then
		saved = {}
	end

	saved.default_workspace = name
	settings_state.save("obsidian", saved)
end

local function switch_workspace(name, opts)
	obsidian("workspace", { name })

	if opts and opts.persist_default then
		save_default_workspace(name)
	end

	local suffix = opts and opts.persist_default and " (saved default)" or ""
	vim.notify("Obsidian workspace: " .. name .. suffix, vim.log.levels.INFO)
end

local function choose_workspace(opts, on_choice)
	opts = opts or {}
	vim.ui.select(ordered_workspaces(), {
		prompt = opts.prompt or "Obsidian workspace:",
		format_item = function(item)
			local suffix = opts.mark_default and item.name == default_workspace and " (default)" or ""
			return string.format("%s%s -> %s", item.name, suffix, item.path)
		end,
	}, function(choice)
		if choice then
			on_choice(choice)
		end
	end)
end

local function obsidian_workspace_status()
	local obsidian_state = rawget(_G, "Obsidian")
	local current = obsidian_state and obsidian_state.workspace and obsidian_state.workspace.name or "unknown"
	local preferred = default_workspace or "none"
	vim.notify(string.format("Obsidian workspace: %s (default: %s)", current, preferred), vim.log.levels.INFO)
end

local function obsidian_workspace_picker()
	choose_workspace({ prompt = "Obsidian workspace:", mark_default = true }, function(choice)
		switch_workspace(choice.name, { persist_default = true })
	end)
end

local function template_names_for_workspace(workspace)
	local template_dir = vim.fs.normalize(vim.fn.expand(workspace.path .. "/templates"))
	local names = {}

	local ok, iter = pcall(vim.fs.dir, template_dir)
	if not ok then
		return names
	end

	for name, entry_type in iter do
		if entry_type == "file" and name:sub(-3) == ".md" then
			table.insert(names, name:sub(1, -4))
		end
	end

	table.sort(names)
	return names
end

local function obsidian_capture()
	choose_workspace({ prompt = "Capture workspace:", mark_default = false }, function(workspace)
		switch_workspace(workspace.name, { persist_default = false })

		local templates = template_names_for_workspace(workspace)
		if #templates == 0 then
			vim.notify("No templates found in " .. workspace.path .. "/templates", vim.log.levels.WARN)
			return
		end

		vim.ui.select(templates, { prompt = "Capture template:" }, function(template)
			if not template then
				return
			end

			vim.ui.input({ prompt = "Note title: " }, function(title)
				local normalized = title and vim.trim(title) or ""
				if normalized == "" then
					normalized = string.format("%s-%s", os.date("%Y-%m-%d-%H%M"), template)
				end

				obsidian("new_from_template", { normalized, template })
			end)
		end)
	end)
end

local function obsidian_weekly_review()
	local title = string.format("weekly-review-%s", os.date("%Y-W%W"))
	obsidian("new_from_template", { title, "weekly-review" })
end

local function make_result_message(result)
	local chunks = {}

	if result.stderr and result.stderr ~= "" then
		table.insert(chunks, vim.trim(result.stderr))
	end

	if result.stdout and result.stdout ~= "" then
		table.insert(chunks, vim.trim(result.stdout))
	end

	return table.concat(chunks, "\n")
end

local function run_vault_make(target)
	return function()
		local cmd = { "make", "-C", vim.fn.expand("~/.vaults"), target }

		local ok, err = pcall(function()
			vim.system(cmd, { text = true }, function(result)
				vim.schedule(function()
					if result.code == 0 then
						vim.notify(string.format("Vault %s completed", target), vim.log.levels.INFO)
						return
					end

					local msg = make_result_message(result)
					if msg == "" then
						msg = string.format("Vault %s failed", target)
					end

					vim.notify(msg, vim.log.levels.ERROR)
				end)
			end)
		end)

		if not ok then
			vim.notify("Failed to run make target " .. target .. ": " .. tostring(err), vim.log.levels.ERROR)
		end
	end
end

return {
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*",
		lazy = true,
		ft = "markdown",
		cmd = { "Obsidian" },
		keys = {
			{ "<leader>oC", obsidian_workspace_picker, desc = "Change Obsidian workspace + save default" },
			{ "<leader>oc", obsidian_capture, desc = "Capture note (workspace + template)" },
			{ "<leader>oi", obsidian_workspace_status, desc = "Show active vault" },
			{ "<leader>oap", run_vault_make("pull"), desc = "Vault pull + decrypt" },
			{ "<leader>oaP", run_vault_make("push"), desc = "Vault encrypt + push" },
			{ "<leader>oac", run_vault_make("check"), desc = "Vault safety check" },
			{ "<leader>on", obsidian_cmd("new"), desc = "New note (active vault)" },
			{ "<leader>os", obsidian_cmd("quick_switch"), desc = "Search notes (active vault)" },
			{ "<leader>og", obsidian_cmd("search"), desc = "Grep notes (active vault)" },
			{ "<leader>or", obsidian_weekly_review, desc = "Weekly review (active vault)" },
			{ "<leader>ol", obsidian_cmd("follow_link"), desc = "Follow link" },
			{ "<leader>ob", obsidian_cmd("backlinks"), desc = "Backlinks" },
			{ "<leader>oo", obsidian_cmd("open"), desc = "Open in Obsidian app" },
		},
		opts = {
			ui = { enable = false },
			legacy_commands = false,
			note_id_func = function(title)
				if title then
					return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
				end
				return tostring(os.time())
			end,
			workspaces = ordered_workspaces(),
			notes_subdir = "inbox",
			new_notes_location = "notes_subdir",
			link = {
				style = "wiki",
				format = "shortest",
			},
			frontmatter = {
				enabled = true,
			},
			templates = {
				enabled = true,
				folder = "templates",
				date_format = "YYYY-MM-DD",
				time_format = "HH:mm",
				customizations = {
					["weekly-review.md"] = {
						notes_subdir = "review/weekly",
					},
					["presentation.md"] = {
						notes_subdir = "presentations",
					},
				},
			},
			daily_notes = {
				enabled = false,
			},
			completion = {
				blink = true,
				nvim_cmp = false,
				min_chars = 2,
			},
		},
	},
}
