-- User override: window border gradient sourced from the theme's colors.toml.
-- Generated into the current theme dir by omarchy-theme-set-templates.
-- Keys read: hyprland_active_border, hyprland_inactive_border (colors.toml).

local active_border_color = {{ hypr_gradient hyprland_active_border accent }}
local inactive_border_color = {{ hypr_gradient hyprland_inactive_border rgba(595959aa) }}

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})