-- Persistent window decoration: macOS-style hyprbars buttons.
-- Unlike looknfeel.lua, this file is NOT regenerated when an Omarchy theme is
-- applied, so these settings survive theme switches (hyprland.lua requires it).

hl.config({
  plugin = {
    hyprbars = {
      bar_height = 28,
      bar_buttons_alignment = "left",
      bar_padding = 8,
      bar_button_padding = 8,
      bar_part_of_window = true,
      bar_text_font = "JetBrainsMono Nerd Font",
      bar_text_weight = 600,
      bar_text_size = 12,
      bar_text_align = "center",
      col = {
        text = "rgb(d8dee9)",
      },
    },
  },
})

-- macOS traffic-light buttons, left to right: red (close) -> yellow (minimize) -> green (fullscreen).
hl.plugin.hyprbars.add_button({
  bg_color = "rgb(ff5f57)",
  fg_color = "rgb(000000)",
  size = 12,
  icon = "",
  action = "hyprctl dispatch killactive",
})
hl.plugin.hyprbars.add_button({
  bg_color = "rgb(febc2e)",
  fg_color = "rgb(000000)",
  size = 12,
  icon = "",
  action = "hyprctl dispatch movetoworkspacesilent special:minimized",
})
hl.plugin.hyprbars.add_button({
  bg_color = "rgb(28c840)",
  fg_color = "rgb(000000)",
  size = 12,
  icon = "",
  action = "hyprctl dispatch fullscreen 1",
})

-- Hide the bar for grouped windows (only the core groupbar remains).
hl.window_rule({ ["hyprbars:no_bar"] = true, match = { group = true } })