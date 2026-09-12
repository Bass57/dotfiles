#!/bin/bash
# Auto-generate Hyprland border gradient following the color palette of every
# theme: one accent color per custom theme, deduped and ordered by hue so the
# combined gradient flows smoothly. Re-run it whenever a theme is added or its
# accent changes (it runs automatically on every `omarchy theme set` via the
# theme-set.d hook directory).

set -euo pipefail

THEME_DIR="$HOME/.config/omarchy/themes"
CURRENT_THEME=$(omarchy theme current | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
THEME_PATH="$THEME_DIR/$CURRENT_THEME"
AETHER_THEME_PATH="$HOME/.config/aether/theme"

# Extract accent color from the active theme (for the looknfeel.lua header note)
ACCENT_COLOR="#6973fb"  # default Aether accent
if [[ -f "$THEME_PATH/colors.toml" ]]; then
    ACCENT_COLOR=$(grep '^accent' "$THEME_PATH/colors.toml" | cut -d'"' -f2)
elif [[ -f "$AETHER_THEME_PATH/colors.toml" ]]; then
    ACCENT_COLOR=$(grep '^accent' "$AETHER_THEME_PATH/colors.toml" | cut -d'"' -f2)
fi

# Inactive border spec from the active theme's colors.toml
INACTIVE_BORDER_SPEC=""
if [[ -f "$THEME_PATH/colors.toml" ]]; then
    INACTIVE_BORDER_SPEC=$(grep '^hyprland_inactive_border' "$THEME_PATH/colors.toml" | head -1 | cut -d'=' -f2- | tr -d '"' | xargs)
elif [[ -f "$AETHER_THEME_PATH/colors.toml" ]]; then
    INACTIVE_BORDER_SPEC=$(grep '^hyprland_inactive_border' "$AETHER_THEME_PATH/colors.toml" | head -1 | cut -d'=' -f2- | tr -d '"' | xargs)
fi

# Sort hex colors by hue so the gradient reads as a smooth rainbow.
sort_by_hue() {
    python3 -c '
import colorsys, sys
rows = []
for h in sys.argv[1:]:
    if len(h) != 6 or any(c not in "0123456789ABCDEFabcdef" for c in h):
        continue
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    hue = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)[0]
    rows.append((hue, h.upper()))
for _, h in sorted(rows):
    print(h)
' "$@"
}

# Build the combined border palette: one accent color per custom theme.
# Follows the color palette of every theme in ~/.config/omarchy/themes.
declare -A SEEN_HEX=()
PALETTE_HEX=()
for theme_colors in "$THEME_DIR"/*/colors.toml; do
    accent=$(grep '^accent' "$theme_colors" 2>/dev/null | head -1 | cut -d'"' -f2)
    [[ $accent =~ ^#[0-9a-fA-F]{6}$ ]] || continue
    hex="${accent#\#}"
    [[ -n ${SEEN_HEX[$hex]:-} ]] && continue
    SEEN_HEX[$hex]=1
    PALETTE_HEX+=("${hex^^}")
done

# Fallback wheel if fewer than 2 themes contributed
if (( ${#PALETTE_HEX[@]} < 2 )); then
    PALETTE_HEX=("6254B5" "6973FB" "8B5CF6" "B6559D" "CB6269" "E8913A")
fi

# Order by hue so colours flow smoothly around the border
mapfile -t SORTED_HEX < <(sort_by_hue "${PALETTE_HEX[@]}")

# Render as rgba stops with 93% opacity (ee), matching theme colors.toml style
GRADIENT_ANGLE=135
RGBA_COLORS=()
for hex in "${SORTED_HEX[@]}"; do
    RGBA_COLORS+=("rgba(${hex}ee)")
done

# Inactive border: prefer theme's hyprland_inactive_border, else theme background
INACTIVE_LUA="rgba(1E1E2Aaa)"
if [[ -n "$INACTIVE_BORDER_SPEC" ]]; then
    INACTIVE_LUA="$INACTIVE_BORDER_SPEC"
else
    INACTIVE_BG="1E1E2A"
    if [[ -f "$THEME_PATH/colors.toml" ]]; then
        THEME_BG=$(grep '^background' "$THEME_PATH/colors.toml" | head -1 | cut -d'"' -f2 | tr -d '#')
        if [[ $THEME_BG =~ ^[0-9a-fA-F]{6}$ ]]; then
            INACTIVE_BG="${THEME_BG^^}"
        fi
    fi
    INACTIVE_LUA="rgba(${INACTIVE_BG}aa)"
fi

# Write looknfeel.lua
cat > "$HOME/.config/hypr/looknfeel.lua" << HYPR_EOF
-- Auto-generated border gradient: one accent color per custom theme
-- Active theme: $CURRENT_THEME (accent $ACCENT_COLOR)
-- Palette: $(IFS=,; echo "${SORTED_HEX[*]:0:6}") ...
-- Combined from all themes in colors.toml (${#RGBA_COLORS[@]} stops)
-- Generated: $(date)

local active_border_color = {
  colors = {
HYPR_EOF

for rgba in "${RGBA_COLORS[@]}"; do
    echo "    \"$rgba\"," >> "$HOME/.config/hypr/looknfeel.lua"
done

cat >> "$HOME/.config/hypr/looknfeel.lua" << HYPR_EOF
  },
  angle = $GRADIENT_ANGLE,
}
local inactive_border_color = "$INACTIVE_LUA"

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,

    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },

    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding = 16,

    dim_inactive = true,
    dim_strength = 0.15,

    shadow = {
      enabled = false,
    },

    blur = {
      enabled = false,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },

    groupbar = {
      font_size = 12,
      font_family = "monospace",
      font_weight_active = "ultraheavy",
      font_weight_inactive = "normal",
      indicator_height = 1,
      indicator_gap = 5,
      height = 22,
      gaps_in = 5,
      gaps_out = 0,
      text_color = "rgb(ffffff)",
      text_color_inactive = "rgba(ffffff90)",
      col = {
        active = "rgba(00000040)",
        inactive = "rgba(00000020)",
      },
      gradients = true,
      gradient_rounding = 0,
      gradient_round_only_edges = false,
    },
  },

  animations = {
    enabled = true,
  },
})

-- Default animations
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 3.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "fadeSwitch", enabled = false })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slidevert" })

hl.config({
  dwindle = {
    preserve_split = true,
    force_split = 2,
  },

  scrolling = {
    column_width = 0.49,
  },

  master = {
    new_status = "master",
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_scale_notification = true,
    focus_on_activate = true,
    anr_missed_pings = 3,
    on_focus_under_fullscreen = 1,
    initial_workspace_tracking = 0,
    allow_session_lock_restore = true,
  },

  cursor = {
    hide_on_key_press = true,
    warp_on_change_workspace = 1,
  },

  binds = {
    hide_special_on_workspace_change = true,
  },
})
HYPR_EOF

# Reload Hyprland
hyprctl reload >/dev/null 2>&1 || true
