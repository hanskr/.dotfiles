local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
wezterm.plugin.update_all()

resurrect.state_manager.periodic_save({interval_seconds = 60, save_workspaces=true})
wezterm.on("resurrect.state_manager.periodic_save.finished", function(opts)
  write_current_state("default", "workspace")
end)
wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)

config.font = wezterm.font 'MesloLGS NF'
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

config.front_end = 'WebGpu'
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_padding = {
    left = 2,
    right = 2,
    top = 48,  -- push content below the integrated buttons
    bottom = 0,
  }
config.inactive_pane_hsb = { saturation = 0.6, brightness = 0.8 }

config.send_composed_key_when_left_alt_is_pressed = true

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
  { key = 'Enter', mods = 'SHIFT', action = wezterm.action.SendString '\x1b[13;2u' },
}

config.mouse_bindings = {
    -- Disable the default click behavior
    {
      event = { Up = { streak = 1, button = "Left"} },
      mods = "NONE",
      action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
    },
    -- Ctrl-click will open the link under the mouse cursor
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "CMD",
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
    -- Disable the Ctrl-click down event to stop programs from seeing it when a URL is clicked
    {
        event = { Down = { streak = 1, button = "Left" } },
        mods = "CMD",
        action = wezterm.action.Nop,
    },
}

return config
