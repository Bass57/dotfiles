#!/usr/bin/env bash
set -euo pipefail

THEME_FILE="${HOME}/.local/state/omarchy/current/theme/ghostty.conf"
SHADER_DIR="${HOME}/.config/ghostty/shaders"

if [[ ! -f "$THEME_FILE" ]]; then
  echo "Theme file not found: $THEME_FILE" >&2
  exit 1
fi

HEX=$(grep '^cursor-color' "$THEME_FILE" | sed 's/^cursor-color = //' | tr -d '"')
if [[ -z "$HEX" ]]; then
  echo "cursor-color not found in $THEME_FILE" >&2
  exit 1
fi

# Normalize 3-digit shorthand (#abc -> #aabbcc)
HEX="${HEX#\#}"
if [[ ${#HEX} -eq 3 ]]; then
  HEX="${HEX:0:1}${HEX:0:1}${HEX:1:1}${HEX:1:1}${HEX:2:1}${HEX:2:1}"
fi
if [[ ${#HEX} -ne 6 ]]; then
  echo "Unexpected cursor-color format: $HEX" >&2
  exit 1
fi

R=$(printf "%d" "0x${HEX:0:2}")
G=$(printf "%d" "0x${HEX:2:2}")
B=$(printf "%d" "0x${HEX:4:2}")

PATCHED=0
for SHADER_FILE in "$SHADER_DIR"/*.glsl; do
  if grep -q '^const vec4 TRAIL_COLOR' "$SHADER_FILE"; then
    sed -i "s/^const vec4 TRAIL_COLOR = .*/const vec4 TRAIL_COLOR = vec4(${R}.0, ${G}.0, ${B}.0, 1.0);/" "$SHADER_FILE"
    echo "Patched $SHADER_FILE -> vec4(${R}.0, ${G}.0, ${B}.0, 1.0);"
    PATCHED=$((PATCHED + 1))
  fi
done

if [[ $PATCHED -eq 0 ]]; then
  echo "No shader defines TRAIL_COLOR in $SHADER_DIR" >&2
  exit 1
fi

echo "Done. #$HEX -> vec4(${R}.0, ${G}.0, ${B}.0, 1.0) applied to $PATCHED shader(s)."