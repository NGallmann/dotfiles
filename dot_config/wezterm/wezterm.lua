local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.window_close_confirmation = 'NeverPrompt'
config.window_decorations = 'RESIZE'
config.default_cursor_style = 'BlinkingBar'
config.font = wezterm.font('JetBrains Mono', { weight = 'Bold' })
config.font_size = 12.5
config.window_background_opacity = 0.88
config.text_background_opacity = 0.65

-- Cool blues/cyans to match the nebula; cell bg is navy so the
-- wallpaper still reads through with text_background_opacity.
config.color_scheme = 'Tokyo Night Storm'
config.colors = {
  background = '#0b1520',
  foreground = '#c8d6ea',
  cursor_bg = '#7dcfff',
  cursor_fg = '#0b1520',
  cursor_border = '#7dcfff',
  selection_bg = '#1f4a6e',
  selection_fg = '#e8f1ff',
}

config.background = {
  {
    source = {
      File = wezterm.config_dir .. '/bg.jpg',
    },
    hsb = {
      hue = 1.0,
      saturation = 1.02,
      brightness = 0.45,
    },
    width = '100%',
    height = '100%',
    opacity = 0.9,
  },
  {
    source = {
      Color = '#0b1520',
    },
    width = '100%',
    height = '100%',
    opacity = 0.22,
  },
}

return config
