local M = {}

local canvas = nil
local key_tap = nil
local slot_frames = {}
local icon_cache = {}

local style = {
	font = "SF Pro Text",
	font_bold = "SF Pro Text Bold",
	title_size = 24,
	hint_size = 13,
	label_size = 15,
	state_size = 11,
	panel_radius = 24,
	card_radius = 18,
	key_radius = 10,
	panel_pad = 26,
	header_h = 54,
	gap = 18,
	card_w = 144,
	card_h = 118,
	bg = { white = 0.06, alpha = 0.78 },
	panel_bg = { hex = "#0F172A", alpha = 0.94 },
	card_bg = { hex = "#172033", alpha = 0.98 },
	card_running = { hex = "#1E293B", alpha = 0.98 },
	card_active = { hex = "#1D4ED8", alpha = 0.98 },
	border = { hex = "#334155", alpha = 0.9 },
	border_active = { hex = "#93C5FD", alpha = 0.95 },
	key_bg = { hex = "#0B1220", alpha = 0.9 },
	key_text = { hex = "#93C5FD", alpha = 1 },
	title = { hex = "#E2E8F0", alpha = 1 },
	hint = { hex = "#94A3B8", alpha = 1 },
	label = { hex = "#F8FAFC", alpha = 1 },
	label_dim = { hex = "#94A3B8", alpha = 1 },
	state = { hex = "#CBD5E1", alpha = 1 },
	state_dim = { hex = "#64748B", alpha = 1 },
	shadow = { alpha = 0.3, blurRadius = 18, offset = { h = 0, w = 0 }, color = { white = 0 } },
}

local slots = {
	{
		key = "g",
		hint = "G",
		label = "Ghostty",
		launch_name = "Ghostty",
		bundle_ids = { "com.mitchellh.ghostty" },
	},
	{
		key = "b",
		hint = "B",
		label = "Brave",
		launch_name = "Brave Browser",
		bundle_ids = { "com.brave.Browser" },
	},
	{
		key = "f",
		hint = "F",
		label = "Finder",
		launch_name = "Finder",
		bundle_ids = { "com.apple.finder" },
	},
	{
		key = "t",
		hint = "T",
		label = "Teams",
		launch_name = "Microsoft Teams",
		bundle_ids = { "com.microsoft.teams2" },
	},
	{
		key = "m",
		hint = "M",
		label = "Mail",
		bundle_ids = { "com.microsoft.Outlook", "org.mozilla.thunderbird" },
		action = function(resolved)
			if resolved.app then
				resolved.app:activate(true)
				return
			end
			hs.application.launchOrFocus(
				hs.application.pathForBundleID("com.microsoft.Outlook") and "Microsoft Outlook" or "Thunderbird"
			)
		end,
	},
	{
		key = "o",
		hint = "O",
		label = "Obsidian",
		launch_name = "Obsidian",
		bundle_ids = { "md.obsidian" },
	},
	{
		key = "d",
		hint = "D",
		label = "Discord",
		launch_name = "Discord",
		bundle_ids = { "com.hnc.Discord" },
	},
	{
		key = "w",
		hint = "W",
		label = "WhatsApp",
		launch_name = "WhatsApp",
		bundle_ids = { "net.whatsapp.WhatsApp" },
	},
}

local function destroy_canvas()
	if canvas then
		canvas:delete()
		canvas = nil
	end
	slot_frames = {}
end

local function stop_key_tap()
	if key_tap then
		key_tap:stop()
		key_tap = nil
	end
end

local function hide()
	stop_key_tap()
	destroy_canvas()
end

local function target_screen()
	local frontmost = hs.window.frontmostWindow()
	if frontmost then
		return frontmost:screen()
	end
	return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

local function running_apps()
	local by_bundle = {}
	for _, app in ipairs(hs.application.runningApplications()) do
		local bundle_id = app:bundleID()
		if bundle_id and bundle_id ~= "" and not by_bundle[bundle_id] then
			by_bundle[bundle_id] = app
		end
	end
	return by_bundle
end

local function installed_bundle_id(slot)
	for _, bundle_id in ipairs(slot.bundle_ids or {}) do
		if hs.application.pathForBundleID(bundle_id) then
			return bundle_id
		end
	end
	return slot.bundle_ids and slot.bundle_ids[1] or nil
end

local function resolve_slot(slot, by_bundle)
	for _, bundle_id in ipairs(slot.bundle_ids or {}) do
		local app = by_bundle[bundle_id]
		if app then
			return {
				app = app,
				bundle_id = bundle_id,
				running = true,
			}
		end
	end
	return {
		bundle_id = installed_bundle_id(slot),
		running = false,
	}
end

local function icon_for(slot, resolved)
	local seen = {}
	local bundle_ids = {}
	if resolved.bundle_id then
		bundle_ids[#bundle_ids + 1] = resolved.bundle_id
		seen[resolved.bundle_id] = true
	end
	for _, bundle_id in ipairs(slot.bundle_ids or {}) do
		if bundle_id and not seen[bundle_id] then
			bundle_ids[#bundle_ids + 1] = bundle_id
			seen[bundle_id] = true
		end
	end
	for _, bundle_id in ipairs(bundle_ids) do
		local icon = icon_cache[bundle_id]
		if icon == nil then
			icon = hs.image.imageFromAppBundle(bundle_id) or false
			icon_cache[bundle_id] = icon
		end
		if icon then
			return icon
		end
	end
	return nil
end

local function activate_slot(slot, resolved)
	hide()
	if slot.action then
		slot.action(resolved)
		return
	end
	if slot.launch_name then
		hs.application.launchOrFocus(slot.launch_name)
		return
	end
	if resolved.app then
		resolved.app:activate(true)
	end
end

local function hit_slot(x, y)
	for _, hit in ipairs(slot_frames) do
		local frame = hit.frame
		if x >= frame.x and x <= frame.x + frame.w and y >= frame.y and y <= frame.y + frame.h then
			return hit
		end
	end
	return nil
end

local function build_text(text, font_name, size, color, alignment)
	local style_spec = {
		font = { name = font_name, size = size },
		color = color,
	}
	if alignment then
		style_spec.paragraphStyle = { alignment = alignment }
	end
	return hs.styledtext.new(text, style_spec)
end

local function build_elements(full)
	local frontmost = hs.application.frontmostApplication()
	local frontmost_bundle = frontmost and frontmost:bundleID() or nil
	local by_bundle = running_apps()
	local cols = 4
	local rows = 2
	local panel_w = style.panel_pad * 2 + cols * style.card_w + (cols - 1) * style.gap
	local panel_h = style.panel_pad * 2 + style.header_h + rows * style.card_h + (rows - 1) * style.gap
	local panel_x = math.floor((full.w - panel_w) / 2)
	local panel_y = math.floor((full.h - panel_h) / 2)
	local cards_y = panel_y + style.panel_pad + style.header_h
	local elements = {
		{
			type = "rectangle",
			action = "fill",
			fillColor = style.bg,
			frame = { x = 0, y = 0, w = full.w, h = full.h },
		},
		{
			type = "rectangle",
			action = "fill",
			fillColor = style.panel_bg,
			strokeColor = style.border,
			strokeWidth = 1,
			shadow = style.shadow,
			roundedRectRadii = { xRadius = style.panel_radius, yRadius = style.panel_radius },
			frame = { x = panel_x, y = panel_y, w = panel_w, h = panel_h },
		},
		{
			type = "text",
			text = build_text("Apps", style.font_bold, style.title_size, style.title),
			frame = {
				x = panel_x + style.panel_pad,
				y = panel_y + 14,
				w = panel_w - style.panel_pad * 2,
				h = style.title_size + 10,
			},
		},
		{
			type = "text",
			text = build_text("Press app initial or click a card", style.font, style.hint_size, style.hint),
			frame = {
				x = panel_x + style.panel_pad,
				y = panel_y + 18 + style.title_size,
				w = panel_w - style.panel_pad * 2,
				h = style.hint_size + 8,
			},
		},
	}

	slot_frames = {}

	for index, slot in ipairs(slots) do
		local resolved = resolve_slot(slot, by_bundle)
		local is_active = resolved.bundle_id and resolved.bundle_id == frontmost_bundle
		local col = (index - 1) % cols
		local row = math.floor((index - 1) / cols)
		local x = panel_x + style.panel_pad + col * (style.card_w + style.gap)
		local y = cards_y + row * (style.card_h + style.gap)
		local icon = icon_for(slot, resolved)
		local card_fill = is_active and style.card_active or (resolved.running and style.card_running or style.card_bg)
		local border = is_active and style.border_active or style.border
		local label_color = resolved.running and style.label or style.label_dim
		local state_text = is_active and "ACTIVE" or (resolved.running and "RUNNING" or "LAUNCH")
		local state_color = resolved.running and style.state or style.state_dim

		slot_frames[#slot_frames + 1] = {
			key = slot.key,
			slot = slot,
			resolved = resolved,
			frame = { x = x, y = y, w = style.card_w, h = style.card_h },
		}

		elements[#elements + 1] = {
			type = "rectangle",
			action = "fill",
			fillColor = card_fill,
			strokeColor = border,
			strokeWidth = is_active and 2 or 1,
			roundedRectRadii = { xRadius = style.card_radius, yRadius = style.card_radius },
			frame = { x = x, y = y, w = style.card_w, h = style.card_h },
		}
		elements[#elements + 1] = {
			type = "rectangle",
			action = "fill",
			fillColor = style.key_bg,
			roundedRectRadii = { xRadius = style.key_radius, yRadius = style.key_radius },
			frame = { x = x + 12, y = y + 12, w = 28, h = 28 },
		}
		elements[#elements + 1] = {
			type = "text",
			text = build_text(slot.hint or slot.key:upper(), style.font_bold, 14, style.key_text, "center"),
			frame = { x = x + 12, y = y + 15, w = 28, h = 18 },
		}

		if icon then
			elements[#elements + 1] = {
				type = "image",
				image = icon,
				imageScaling = "scaleProportionally",
				frame = { x = x + 44, y = y + 16, w = 56, h = 56 },
			}
		end

		elements[#elements + 1] = {
			type = "text",
			text = build_text(slot.label, style.font_bold, style.label_size, label_color, "center"),
			frame = { x = x + 10, y = y + 76, w = style.card_w - 20, h = 20 },
		}
		elements[#elements + 1] = {
			type = "text",
			text = build_text(state_text, style.font, style.state_size, state_color, "center"),
			frame = { x = x + 10, y = y + 95, w = style.card_w - 20, h = 16 },
		}
	end

	return elements
end

local function on_mouse(_, message, _, x, y)
	if message ~= "mouseUp" then
		return
	end
	local hit = hit_slot(x, y)
	if not hit then
		hide()
		return
	end
	activate_slot(hit.slot, hit.resolved)
end

local function on_key(event)
	local key_name = hs.keycodes.map[event:getKeyCode()]
	if not key_name then
		return true
	end
	local lower = key_name:lower()
	if lower == "escape" or lower == "tab" then
		hide()
		return true
	end
	for _, hit in ipairs(slot_frames) do
		if lower == hit.key then
			activate_slot(hit.slot, hit.resolved)
			return true
		end
	end
	hide()
	return true
end

function M.show()
	hide()
	local screen = target_screen()
	local full = screen:fullFrame()
	canvas = hs.canvas.new(full)
	canvas:level(hs.canvas.windowLevels.overlay)
	canvas:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
	canvas:clickActivating(false)
	canvas:mouseCallback(on_mouse)
	canvas:replaceElements(build_elements(full))
	canvas:show()

	key_tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, on_key)
	key_tap:start()
end

function M.hide()
	hide()
end

function M.toggle()
	if canvas then
		hide()
	else
		M.show()
	end
end

return M
