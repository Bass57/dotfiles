-- Keybinding feedback OSD.
--
-- Shows a brief on-screen indicator at the bottom center whenever a Hyprland
-- keybinding is pressed (e.g. SUPER + SPACE -> "Omarchy menu"), so you can see
-- what shortcut you just triggered. It reuses the stock Omarchy volume/brightness
-- OSD surface, so the card (and its window-border gradient) come for free.
--
-- Loaded from ~/.config/hypr/hyprland.lua BEFORE require("default.hypr.omarchy")
-- so every default binding flows through the wrapper below, not just your own
-- additions in hypr/bindings.lua.

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- Fire the OSD. Runs as a deferred exec so it never blocks the binding that
-- triggered it. The keyboard icon + key combo show in a card that auto-hides
-- after ~1.2s.
local function show_osd(keys, description)
  local cmd = "omarchy-osd -i keyboard -m " .. shell_quote(keys)
  -- Hyprland's hl.timer drops zero/negative timeouts, so use a small positive
  -- delay: it still defers the OSD off the binding's own dispatch path.
  hl.timer(function()
    hl.dispatch(hl.dsp.exec_cmd(cmd))
  end, { timeout = 1, type = "oneshot" })
end

local real_bind = hl.bind

-- The laptop's Fn+F1..F12 row emits XF86* keys (brightness, volume, media,
-- touchpad, …). Those already get their own native OSD bars, so don't layer
-- the keybinding card on top. Literal F# chords (e.g. voxtype F9) still show.
local function is_hardware_row(keys)
  for token in tostring(keys):gmatch("[^ +]+") do
    if token:match("^XF86") then
      return true
    end
  end
  return false
end

function hl.bind(keys, dispatcher, opts)
  local description = opts and opts.description

  -- Wrap only bindings that carry a human description (the user-facing ones).
  -- Internal binds with a nil description (switch events, transient layer
  -- helpers, etc.) and the hardware Fn-row pass straight through untouched.
  if description and type(dispatcher) == "function" then
    if is_hardware_row(keys) then
      return real_bind(keys, dispatcher, opts)
    end
    local original = dispatcher
    local wrapped = function()
      show_osd(keys, description)
      return original()
    end
    return real_bind(keys, wrapped, opts)
  elseif description then
    if is_hardware_row(keys) then
      return real_bind(keys, dispatcher, opts)
    end
    local original = dispatcher
    local wrapped = function()
      show_osd(keys, description)
      return hl.dispatch(original)
    end
    return real_bind(keys, wrapped, opts)
  end

  return real_bind(keys, dispatcher, opts)
end
