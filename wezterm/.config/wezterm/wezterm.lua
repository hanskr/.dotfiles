ilocal wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

config.font_size = 13
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
config.hide_tab_bar_if_only_one_tab = true
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_function = 'EaseIn',
  fade_in_duration_ms = 100,
  fade_out_function = 'EaseOut',
  fade_out_duration_ms = 100,
}
config.colors = {
  visual_bell = '#202020',
  scrollbar_thumb = '#666666',
}
config.enable_scroll_bar = true
config.scrollback_lines = 100000

config.window_decorations = "RESIZE"
config.inactive_pane_hsb = { saturation = 0.6, brightness = 0.8 }

-- config.window_background_opacity = 0.9
-- config.macos_window_background_blur = 30

-- Keybinds for splitting panes
config.keys = {
  { key = "d", mods = "SHIFT|CMD", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "d", mods = "CMD", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "DownArrow", mods = "CMD|OPT", action = wezterm.action.ActivatePaneDirection("Down") },
  { key = "UpArrow", mods = "CMD|OPT", action = wezterm.action.ActivatePaneDirection("Up") },
  { key = "LeftArrow", mods = "CMD|OPT", action = wezterm.action.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "CMD|OPT", action = wezterm.action.ActivatePaneDirection("Right") },
  { key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "r", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
  { key = "Enter", mods = "SHIFT|CMD", action = act.TogglePaneZoomState },
  {
    key = 'k',
    mods = 'CMD',
    action = act.ClearScrollback 'ScrollbackAndViewport',
  },
}

return config

