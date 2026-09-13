#!/bin/bash
# Auto-generate Hyprland border gradient from current theme + wallpaper

set -euo pipefail

THEME_DIR="$HOME/.config/omarchy/themes"
CURRENT_THEME=$(omarchy theme current | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
THEME_PATH="$THEME_DIR/$CURRENT_THEME"
WALLPAPER_DIR="$THEME_PATH/backgrounds"
AETHER_THEME_PATH="$HOME/.config/aether/theme"

# Find current wallpaper (symlink or first image)
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) 2>/dev/null | head -1)

# Fallback to Aether theme wallpaper if no theme-specific wallpaper
if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    WALLPAPER=$(find "$AETHER_THEME_PATH/backgrounds" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) 2>/dev/null | head -1)
fi

# Extract accent color from theme's colors.toml
ACCENT_COLOR="#6973fb"  # default Aether accent
if [[ -f "$THEME_PATH/colors.toml" ]]; then
    ACCENT_COLOR=$(grep '^accent' "$THEME_PATH/colors.toml" | cut -d'"' -f2)
elif [[ -f "$AETHER_THEME_PATH/colors.toml" ]]; then
    ACCENT_COLOR=$(grep '^accent' "$AETHER_THEME_PATH/colors.toml" | cut -d'"' -f2)
fi

# Border gradient spec from theme's colors.toml (hyprland_active_border key)
ACTIVE_BORDER_SPEC=""
INACTIVE_BORDER_SPEC=""
if [[ -f "$THEME_PATH/colors.toml" ]]; then
    ACTIVE_BORDER_SPEC=$(grep '^hyprland_active_border' "$THEME_PATH/colors.toml" | head -1 | cut -d'=' -f2- | tr -d '"' | xargs)
    INACTIVE_BORDER_SPEC=$(grep '^hyprland_inactive_border' "$THEME_PATH/colors.toml" | head -1 | cut -d'=' -f2- | tr -d '"' | xargs)
elif [[ -f "$AETHER_THEME_PATH/colors.toml" ]]; then
    ACTIVE_BORDER_SPEC=$(grep '^hyprland_active_border' "$AETHER_THEME_PATH/colors.toml" | head -1 | cut -d'=' -f2- | tr -d '"' | xargs)
    INACTIVE_BORDER_SPEC=$(grep '^hyprland_inactive_border' "$AETHER_THEME_PATH/colors.toml" | head -1 | cut -d'=' -f2- | tr -d '"' | xargs)
fi

# Extract dominant colors from wallpaper using ImageMagick
WALLPAPER_COLORS=()
if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
    # Get top 4 dominant colors (excluding near-black/white backgrounds)
    mapfile -t WALLPAPER_COLORS < <(
        magick "$WALLPAPER" -resize 50x50 -colors 8 -format "%c" histogram:info: 2>/dev/null |
        awk -F'[#)]' '/srgb/ { 
            hex = $2; 
            r = strtonum("0x" substr(hex,1,2));
            g = strtonum("0x" substr(hex,3,2));
            b = strtonum("0x" substr(hex,5,2));
            # Skip very dark (<30) or very light (>220) colors
            if (r > 30 && g > 30 && b > 30 && r < 220 && g < 220 && b < 220) {
                print "#" hex
            }
        }' | head -4
    )
fi

# Build gradient colors: prefer the theme's hyprland_active_border spec.
# Spec format: "rgba(RRGGBBAA) rgba(RRGGBBAA) [ANGLE]deg"
GRADIENT_ANGLE=135
RGBA_COLORS=()
if [[ -n "$ACTIVE_BORDER_SPEC" ]]; then
    for tok in $ACTIVE_BORDER_SPEC; do
        if [[ "$tok" == *deg ]]; then
            GRADIENT_ANGLE="${tok%deg}"
        else
            RGBA_COLORS+=("$tok")
        fi
    done
else
    # Fallback: wallpaper dominant colors + theme accent
    GRADIENT_COLORS=()
    for color in "${WALLPAPER_COLORS[@]}"; do
        GRADIENT_COLORS+=("$color")
    done
    GRADIENT_COLORS+=("$ACCENT_COLOR")

    # Ensure we have at least 2 colors
    if [[ ${#GRADIENT_COLORS[@]} -lt 2 ]]; then
        GRADIENT_COLORS=("#6254B5" "#6973fb" "#B6559D" "#CB6269")
    fi

    # Generate rgba strings with 93% opacity (ee)
    for color in "${GRADIENT_COLORS[@]}"; do
        hex=${color#\#}
        RGBA_COLORS+=("rgba(${hex}ee)")
    done
fi

# Inactive border: prefer theme's hyprland_inactive_border, else wallpaper bg
INACTIVE_LUA="rgba(1E1E2Aaa)"
if [[ -n "$INACTIVE_BORDER_SPEC" ]]; then
    INACTIVE_LUA="$INACTIVE_BORDER_SPEC"
else
    INACTIVE_BG="1E1E2A"
    if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
        EXTRACTED_BG=$(magick "$WALLPAPER" -resize 50x50 -colors 4 -format "%c" histogram:info: 2>/dev/null |
            awk -F'#' '/srgb/ {
                hex=$2; gsub(/ .*/,"",hex);
                r=strtonum("0x" substr(hex,1,2));
                g=strtonum("0x" substr(hex,3,2));
                b=strtonum("0x" substr(hex,5,2));
                brightness=(r+g+b)/3;
                if (brightness < 60) print hex
            }' | head -1)
        if [[ -n "$EXTRACTED_BG" ]]; then
            INACTIVE_BG="$EXTRACTED_BG"
        fi
    fi
    INACTIVE_LUA="rgba(${INACTIVE_BG}aa)"
fi

# Write looknfeel.lua using a template approach
cat > "$HOME/.config/hypr/looknfeel.lua" << 'HYPR_EOF'
-- Auto-generated border gradient from theme: __THEME__
-- Wallpaper: __WALLPAPER__
-- Accent: __ACCENT__
-- Border source: colors.toml (hyprland_active_border)
-- Generated: __DATE__

local active_border_color = {
  colors = {
__COLORS__
  },
  angle = __ANGLE__,
}
local inactive_border_color = "__INACTIVE_LUA__"

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

# Build colors string
COLORS_STR=""
for rgba in "${RGBA_COLORS[@]}"; do
    COLORS_STR="${COLORS_STR}    \"${rgba}\",\n"
done

# Replace placeholders
sed -i "s/__THEME__/${CURRENT_THEME}/g" "$HOME/.config/hypr/looknfeel.lua"
sed -i "s|__WALLPAPER__|$(basename "$WALLPAPER")|g" "$HOME/.config/hypr/looknfeel.lua"
sed -i "s/__ACCENT__/${ACCENT_COLOR}/g" "$HOME/.config/hypr/looknfeel.lua"
sed -i "s/__DATE__/$(date)/g" "$HOME/.config/hypr/looknfeel.lua"
sed -i "s/__ANGLE__/${GRADIENT_ANGLE}/g" "$HOME/.config/hypr/looknfeel.lua"
sed -i "s/__INACTIVE_LUA__/${INACTIVE_LUA}/g" "$HOME/.config/hypr/looknfeel.lua"
# Use awk to replace the __COLORS__ placeholder with the actual colors
awk -v colors="${COLORS_STR}" '{gsub(/__COLORS__/, colors)} 1' "$HOME/.config/hypr/looknfeel.lua" > "$HOME/.config/hypr/looknfeel.lua.tmp" && mv "$HOME/.config/hypr/looknfeel.lua.tmp" "$HOME/.config/hypr/looknfeel.lua"

# Reload Hyprland
hyprctl reload >/dev/null 2>&1 || true
