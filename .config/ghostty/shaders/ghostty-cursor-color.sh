#!/usr/bin/env bash
set -euo pipefail

THEME_FILE="${HOME}/.local/state/omarchy/current/theme/ghostty.conf"
SHADER_DIR="${HOME}/.config/ghostty/shaders"
CONFIG_FILE="${SHADER_DIR}/variant.conf"

ACCENT_IDX=6
if [[ -f "$CONFIG_FILE" ]]; then
  ACCENT_IDX=$(sed -n 's/^ACCENT_IDX=//p' "$CONFIG_FILE" | tail -1)
fi
ACCENT_IDX="${ACCENT_IDX:-6}"
[[ "$ACCENT_IDX" =~ ^[0-9]+$ ]] || ACCENT_IDX=6

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

ACCENT_HEX=$(get_palette "$ACCENT_IDX") || {
  echo "Palette index $ACCENT_IDX missing in $THEME_FILE" >&2
  exit 1
}
ACCENT=$(hex_to_vec "$ACCENT_HEX" "")
ACCENT_LIGHT=$(hex_to_vec "$ACCENT_HEX" lighten)

PATCHED=0
for SHADER_FILE in "$SHADER_DIR"/cursor_*.glsl; do
  [[ -e "$SHADER_FILE" ]] || continue
  if grep -q '^const vec4 TRAIL_COLOR' "$SHADER_FILE"; then
    sed -i "s|^const vec4 TRAIL_COLOR = .*|const vec4 TRAIL_COLOR = ${ACCENT};|" "$SHADER_FILE"
    sed -i "s|^const vec4 TRAIL_COLOR_ACCENT = .*|const vec4 TRAIL_COLOR_ACCENT = ${ACCENT_LIGHT};|" "$SHADER_FILE"
    echo "Patched $(basename "$SHADER_FILE"): TRAIL_COLOR=${ACCENT} ACCENT=${ACCENT_LIGHT}"
    PATCHED=$((PATCHED + 1))
  fi
done

if [[ $PATCHED -eq 0 ]]; then
  echo "No shader defines TRAIL_COLOR in $SHADER_DIR" >&2
  exit 1
fi

echo "Done. Theme accent #$ACCENT_HEX (palette $ACCENT_IDX) applied to $PATCHED shader(s)."