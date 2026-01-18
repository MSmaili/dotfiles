local wezterm = require("wezterm")

local windowPadding = 5

wezterm.on("toggle-opacity", function(window, _)
	local overrides = window:get_config_overrides() or {}
	if overrides.window_background_opacity == 1.0 then
		overrides.window_background_opacity = 0.90
	else
		overrides.window_background_opacity = 1.0
	end
	window:set_config_overrides(overrides)
end)

return {
	window_decorations = "RESIZE",
	-- color_scheme = "Catppuccin Mocha",
	color_scheme = "rose-pine",
	enable_tab_bar = false,
	font_size = 18,
	bold_brightens_ansi_colors = true,
	window_background_opacity = 0.90,
	automatically_reload_config = true,
	macos_window_background_blur = 30,
	-- front_end = "WebGpu",
	-- webgpu_power_preference = "HighPerformance",

	freetype_load_flags = "NO_HINTING",
	freetype_load_target = "Normal",
	freetype_render_target = "HorizontalLcd",
	font = wezterm.font_with_fallback({
		{
			family = "MonoLisa Variable",
			weight = 400,
			stretch = "Normal",
			style = "Normal",
			harfbuzz_features = {
				"calt",
				"liga",
				"zero",
				"dlig",
				"ss01",
				"ss02",
				"ss05",
				"ss06",
				"ss07",
				"ss10",
				"ss11",
				"ss13",
				"ss15",
				"ss16",
				"ss17",
				"ss18",
			},
		},
		{ family = "Maple Mono NF CN", scale = 1.2 },
	}),

	window_padding = {
		left = windowPadding,
		right = windowPadding,
		top = windowPadding,
		bottom = windowPadding,
	},
	keys = {
		{ key = "LeftArrow", mods = "OPT", action = wezterm.action({ SendString = "\x1bb" }) },
		{ key = "RightArrow", mods = "OPT", action = wezterm.action({ SendString = "\x1bf" }) },
		{ key = "u", mods = "CMD", action = wezterm.action.EmitEvent("toggle-opacity") },
	},
}
