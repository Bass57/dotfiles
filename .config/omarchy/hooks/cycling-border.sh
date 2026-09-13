#!/bin/bash
# Slow animated border gradient.
# Smoothly breathes the theme's linear border gradient between its colors and
# slowly rotates the gradient angle. Re-primes from looknfeel.lua whenever the
# theme regenerates it, so the border always animates the active theme.

set -euo pipefail

# Cadence: seconds between gradient updates (small = smooth)
STEP_SECONDS="${1:-0.2}"
# Full color-breath cycle length in seconds (slow, eased)
CYCLE_SECONDS="${2:-45}"
# Seconds for a full 360-degree angle revolution (0 disables rotation)
REVOLUTION_SECONDS="${3:-180}"

# Fallback wheel when no theme gradient can be read
FALLBACK_WHEEL=(6254B5 6973FB 8B5CF6 B6559D CB6269 E8913A)

LOOKNFEEL="$HOME/.config/hypr/looknfeel.lua"
PRIMED_MTIME=""

COLORS=()
ANGLE=45

# Re-prime COLORS + ANGLE from looknfeel.lua when it changes.
parse_config_colors() {
  [[ -f "$LOOKNFEEL" ]] || return 1
  local out=() hex a
  while read -r hex; do
    [[ "$hex" =~ ^[0-9A-Fa-f]{6}$ ]] && out+=("${hex^^}")
  done < <(sed -n 's/.*rgba(\([0-9A-Fa-f]\{6\}\)ee).*/\1/p' "$LOOKNFEEL")

  if (( ${#out[@]} >= 2 )); then
    COLORS=("${out[@]}")
    a=$(sed -n 's/.*angle *= *\([0-9][0-9]*\).*/\1/p' "$LOOKNFEEL" | head -1)
    [[ "$a" =~ ^[0-9]+$ ]] && ANGLE=$a
    PRIMED_MTIME=$(stat -c %Y "$LOOKNFEEL")
    return 0
  fi
  return 1
}

# Mix two hex colors at permille p (0..1000) -> hex
mix() {
  local c1=$1 c2=$2 p=$3
  local r1 g1 b1 r2 g2 b2 r g b
  r1=$((16#${c1:0:2})); g1=$((16#${c1:2:2})); b1=$((16#${c1:4:2}))
  r2=$((16#${c2:0:2})); g2=$((16#${c2:2:2})); b2=$((16#${c2:4:2}))
  r=$(( (r1 * (1000 - p) + r2 * p) / 1000 ))
  g=$(( (g1 * (1000 - p) + g2 * p) / 1000 ))
  b=$(( (b1 * (1000 - p) + b2 * p) / 1000 ))
  printf '%02X%02X%02X' "$r" "$g" "$b"
}

apply_gradient() {
  local stop1=$1 stop2=$2 angle=$3
  local g="{ colors = { \"rgba(${stop1}ee)\", \"rgba(${stop2}ee)\" }, angle = ${angle} }"
  hyprctl eval "hl.config({ general = { col = { active_border = $g } } })" >/dev/null 2>&1
  hyprctl eval "hl.config({ group = { col = { border_active = $g } } })" >/dev/null 2>&1
}

# Prime the palette: looknfeel.lua first, then live theme, wheel as fallback.
if ! parse_config_colors; then
  COLORS=("${FALLBACK_WHEEL[@]}")
fi
ANGLE_START=$ANGLE

CYCLE_MS=$(( CYCLE_SECONDS * 1000 ))
REV_MS=$(( REVOLUTION_SECONDS * 1000 ))
start_ms=$(( $(date +%s%N) / 1000000 ))

while true; do
  # Re-prime when the theme regenerates looknfeel.lua
  if [[ -f "$LOOKNFEEL" ]]; then
    mtime=$(stat -c %Y "$LOOKNFEEL" 2>/dev/null || echo 0)
    if [[ "$mtime" != "$PRIMED_MTIME" ]]; then
      if parse_config_colors; then
        ANGLE_START=$ANGLE
        start_ms=$(( $(date +%s%N) / 1000000 ))
      fi
    fi
  fi

  now=$(( $(date +%s%N) / 1000000 ))
  elapsed=$(( now - start_ms ))

  # Fraction (0..1) along the cycle for the sliding color-window.
  f=$(awk -v e="$elapsed" -v c="$CYCLE_MS" 'BEGIN{ printf "%.6f", (e % c) / c }')

  n=${#COLORS[@]}
  # Sliding keyframe window over the palette; cosine-ease within each segment.
  key=$(awk -v f="$f" -v n="$n" 'BEGIN{ printf "%.3f", f * n }')
  j=$(( ${key%%.*} % n ))
  q="${key#*.}"
  while (( ${#q} < 3 )); do q+="0"; done
  qt=$(( 10#$q ))
  e=$(awk -v qt="$qt" 'BEGIN{ printf "%d", (0.5 - 0.5 * cos(3.141592653589793 * qt / 1000)) * 1000 }')

  c_j="${COLORS[j]}"
  c_j1="${COLORS[(( (j + 1) % n ))]}"
  c_j2="${COLORS[(( (j + 2) % n ))]}"

  stop1=$(mix "$c_j" "$c_j1" "$e")
  stop2=$(mix "$c_j1" "$c_j2" "$e")

  # Slow gradient-angle drift (0 disables rotation)
  angle=$ANGLE
  if (( REV_MS > 0 )); then
    drift100=$(( ( (now - start_ms) % REV_MS ) * 36000 / REV_MS ))
    angle=$(( (ANGLE_START * 100 + drift100) / 100 % 360 ))
  fi

  apply_gradient "$stop1" "$stop2" "$angle"

  sleep "$STEP_SECONDS"
done