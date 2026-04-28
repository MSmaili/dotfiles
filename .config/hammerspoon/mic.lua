local M = {}

local function input_device()
	return hs.audiodevice.defaultInputDevice()
end

function M.toggle()
	local device = input_device()
	if not device then
		hs.alert.show("No input device")
		return
	end
	device:setInputMuted(not device:inputMuted())
	hs.alert.show(device:inputMuted() and "Mic MUTED 🔇" or "Mic LIVE 🎤")
end

return M
