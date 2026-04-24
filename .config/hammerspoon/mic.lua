local M = {}

function M.toggle()
	local dev = hs.audiodevice.defaultInputDevice()
	if not dev then
		hs.alert.show("No input device")
		return
	end
	local newState = not dev:inputMuted()
	dev:setInputMuted(newState)
	hs.alert.show(newState and "Mic MUTED 🔇" or "Mic LIVE 🎤")
end

return M
