#!/usr/bin/env bash
set -euo pipefail

# Pin the Neovim cursor + accent to the neon cyan (#00E5FF) used by the
# Ghostty cursor-shader trail. Omarchy regenerates the staged neovim.lua on
# every `omarchy theme set`; this hook re-applies the neon colors to the
# staged file that ~/.config/nvim/lua/plugins/theme.lua symlinks to.
THEME_FILE="${HOME}/.local/state/omarchy/current/theme/neovim.lua"

[[ -f "$THEME_FILE" ]] || {
  echo "Omarchy nvim theme not found: $THEME_FILE" >&2
  exit 0
}

sed -i \
  -e 's/^\( *\)accent = .*/\1accent = "#00E5FF",/' \
  -e 's/^\( *\)cursor = .*/\1cursor = "#00E5FF",/' \
  "$THEME_FILE"

echo "Neovim accent + cursor pinned to neon #00E5FF"