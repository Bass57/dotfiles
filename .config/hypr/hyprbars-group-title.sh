#!/usr/bin/env bash

set -u

state_file="${XDG_RUNTIME_DIR:-/tmp}/hyprbars-title-state"
lock_file="${XDG_RUNTIME_DIR:-/tmp}/hyprbars-group-title.lock"
socket_dir="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}"
socket="${socket_dir}/.socket2.sock"

exec 9>"$lock_file"
flock -n 9 || exit 0

update_title() {
  local grouped
  grouped="$(hyprctl activewindow -j 2>/dev/null | jq -r '(.grouped // []) | length > 1')"

  if [[ "$grouped" == "true" ]]; then
    [[ -f "$state_file" && "$(cat "$state_file")" == "false" ]] && return
    hyprctl keyword plugin:hyprbars:bar_title_enabled false >/dev/null
    printf 'false\n' > "$state_file"
  else
    [[ -f "$state_file" && "$(cat "$state_file")" == "true" ]] && return
    hyprctl keyword plugin:hyprbars:bar_title_enabled true >/dev/null
    printf 'true\n' > "$state_file"
  fi
}

update_title
socat -u "UNIX-CONNECT:${socket}" - | while IFS= read -r _; do
  update_title
done
