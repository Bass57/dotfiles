#!/usr/bin/env bash
set -euo pipefail

THEME_FILE="${HOME}/.local/state/omarchy/current/theme/ghostty.conf"
SHADER_DIR="${HOME}/.config/ghostty/shaders"
ORIGINAL_DIR="${SHADER_DIR}/original"
CONFIG_FILE="${SHADER_DIR}/variant.conf"

ACCENT_IDX=6
CUSTOM_COLOR=""
RAINBOW=0
RAINBOW_SPEED=0.40
if [[ -f "$CONFIG_FILE" ]]; then
  ACCENT_IDX=$(sed -n 's/^ACCENT_IDX=//p' "$CONFIG_FILE" | tail -1)
  CUSTOM_COLOR=$(sed -n 's/^CUSTOM_COLOR=//p' "$CONFIG_FILE" | tail -1)
  RAINBOW=$(sed -n 's/^RAINBOW=//p' "$CONFIG_FILE" | tail -1)
  RAINBOW_SPEED=$(sed -n 's/^RAINBOW_SPEED=//p' "$CONFIG_FILE" | tail -1)
fi
ACCENT_IDX="${ACCENT_IDX:-6}"
[[ "$ACCENT_IDX" =~ ^[0-9]+$ ]] || ACCENT_IDX=6
RAINBOW_SPEED="${RAINBOW_SPEED:-0.40}"
[[ "$RAINBOW_SPEED" =~ ^[0-9.]+$ ]] || RAINBOW_SPEED=0.40
RAINBOW_ON=0
[[ "$RAINBOW" == "1" || "$RAINBOW" == "true" || "$RAINBOW" == "yes" ]] && RAINBOW_ON=1

if [[ ! -f "$THEME_FILE" ]]; then
  echo "Theme file not found: $THEME_FILE" >&2
  exit 1
fi

get_palette() {
  local idx="$1" line hex
  line=$(grep -E "^palette = (0)?${idx}=" "$THEME_FILE" | head -1)
  [[ -z "$line" ]] && return 1
  hex=$(echo "$line" | sed 's/.*= *//' | tr -d '"#')
  if [[ ${#hex} -eq 3 ]]; then
    hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
  fi
  echo "$hex"
}

hex_to_vec() {
  local h="$1" clr="$2" dr dg db r g b
  dr=$((16#${h:0:2})); dg=$((16#${h:2:2})); db=$((16#${h:4:2}))
  if [[ "$clr" == "lighten" ]]; then
    r=$((dr + (255 - dr) * 35 / 100))
    g=$((dg + (255 - dg) * 35 / 100))
    b=$((db + (255 - db) * 35 / 100))
  else
    r=$dr; g=$dg; b=$db
  fi
  printf "vec4(%d.0, %d.0, %d.0, 1.0)" "$r" "$g" "$b"
}

# Restore from pristine copies so every run is deterministic.
reset_from_pristine() {
  cp "$ORIGINAL_DIR/$(basename "$1")" "$1"
}

rainbow_patch() {
  local f="$1" spd="$2"
  local hsv hue hue2
  hsv='vec3 hsv2rgb(vec3 c){vec3 p=abs(fract(c.xxx+vec3(0.,2./3.,1./3.))*6.-3.);return mix(vec3(1.),clamp(p-1.,0.,1.),c.y)*c.z;}'
  hue="vec4(hsv2rgb(vec3(fract(iTime*${spd}),0.90,1.00)), 1.0)"
  hue2="vec4(hsv2rgb(vec3(fract(iTime*${spd}+0.05),0.90,1.00)), 1.0)"
  sed -i \
    -e "s|^const vec4 TRAIL_COLOR = .*|${hsv}\n#define TRAIL_COLOR ${hue}|" \
    -e "s|^const vec4 TRAIL_COLOR_ACCENT = .*|#define TRAIL_COLOR_ACCENT ${hue2}|" \
    -e "s|^const vec4 CURRENT_CURSOR_COLOR = .*|#define CURRENT_CURSOR_COLOR TRAIL_COLOR|" \
    -e "s|^const vec4 PREVIOUS_CURSOR_COLOR = .*|#define PREVIOUS_CURSOR_COLOR TRAIL_COLOR|" \
    "$f"
  echo "Rainbow-patched $(basename "$f") (speed $spd)"
}

static_patch() {
  local f="$1"
  sed -i "s|^const vec4 TRAIL_COLOR = .*|const vec4 TRAIL_COLOR = ${ACCENT};|" "$f"
  sed -i "s|^const vec4 TRAIL_COLOR_ACCENT = .*|const vec4 TRAIL_COLOR_ACCENT = ${ACCENT_LIGHT};|" "$f"
  echo "Patched $(basename "$f"): TRAIL_COLOR=${ACCENT} ACCENT=${ACCENT_LIGHT}"
}

ACCENT_HEX=""
if [[ $RAINBOW_ON -ne 1 ]]; then
  if [[ -n "$CUSTOM_COLOR" ]]; then
    ACCENT_HEX="${CUSTOM_COLOR#\#}"
    if [[ ${#ACCENT_HEX} -eq 3 ]]; then
      ACCENT_HEX="${ACCENT_HEX:0:1}${ACCENT_HEX:0:1}${ACCENT_HEX:1:1}${ACCENT_HEX:1:1}${ACCENT_HEX:2:1}${ACCENT_HEX:2:1}"
    fi
    [[ ${#ACCENT_HEX} -eq 6 ]] || ACCENT_HEX=""
  fi
  if [[ -z "$ACCENT_HEX" ]]; then
    ACCENT_HEX=$(get_palette "$ACCENT_IDX") || {
      echo "Palette index $ACCENT_IDX missing in $THEME_FILE" >&2
      exit 1
    }
  fi
  ACCENT=$(hex_to_vec "$ACCENT_HEX" "")
  ACCENT_LIGHT=$(hex_to_vec "$ACCENT_HEX" lighten)
fi

if [[ ! -d "$ORIGINAL_DIR" ]] || ! compgen -G "$ORIGINAL_DIR"/cursor_*.glsl >/dev/null; then
  echo "Pristine shader copies missing in $ORIGINAL_DIR" >&2
  exit 1
fi

PATCHED=0
for SHADER_FILE in "$SHADER_DIR"/cursor_*.glsl; do
  [[ -e "$SHADER_FILE" ]] || continue
  [[ -e "$ORIGINAL_DIR/$(basename "$SHADER_FILE")" ]] || continue
  reset_from_pristine "$SHADER_FILE"
  if [[ $RAINBOW_ON -eq 1 ]]; then
    rainbow_patch "$SHADER_FILE" "$RAINBOW_SPEED"
  else
    static_patch "$SHADER_FILE"
  fi
  PATCHED=$((PATCHED + 1))
done

if [[ $PATCHED -eq 0 ]]; then
  echo "No shaders found in $SHADER_DIR" >&2
  exit 1
fi

if [[ $RAINBOW_ON -eq 1 ]]; then
  echo "Done. Rainbow mode applied to $PATCHED shader(s) (speed $RAINBOW_SPEED)."
elif [[ -n "$CUSTOM_COLOR" ]]; then
  echo "Done. Custom color #$ACCENT_HEX applied to $PATCHED shader(s)."
else
  echo "Done. Theme accent #$ACCENT_HEX (palette $ACCENT_IDX) applied to $PATCHED shader(s)."
fi