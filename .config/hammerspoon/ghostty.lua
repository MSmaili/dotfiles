local M = {}

-- Open a new Ghostty window at `dir`.
--
-- macOS has no single API that both reuses the running Ghostty instance AND
-- accepts a working directory, so we branch:
--   * running → AppleScript `make new window` (reuses instance cleanly)
--   * not running → `open -na --args --working-directory=…` (launches fresh
--     with the dir; no duplicate Dock icon since no instance exists yet)
function M.openAt(dir)
	if hs.application.get("Ghostty") then
		hs.osascript.applescript(string.format(
			[[
				tell application "Ghostty"
					activate
					try
						make new window with configuration {initial working directory:"%s"}
					end try
				end tell
			]],
			dir
		))
	else
		hs.execute(string.format("/usr/bin/open -na Ghostty --args --working-directory=%q", dir))
	end
end

-- Leader action factory: resolves `path` against $HOME at call time.
function M.openHome(path)
	return function()
		M.openAt(os.getenv("HOME") .. "/" .. path)
	end
end

return M
