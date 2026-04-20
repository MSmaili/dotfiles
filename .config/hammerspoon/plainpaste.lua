local M = {}

function M.paste()
	local txt = hs.pasteboard.getContents()
	if txt then
		hs.pasteboard.setContents(txt)
		hs.eventtap.keyStroke({ "cmd" }, "v", 0)
	end
end

return M
