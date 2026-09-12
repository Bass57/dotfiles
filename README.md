# Dotfiles

Snapshot of personal Omarchy customizations. Lives at `~/dotfiles` on the machine
`Bass57` and mirrors the files as-is — no symlinks, no install script.

## What's inside

Everything here is user-owned config under `~/.config/`, so `omarchy update`
never overwrites it (updates only replace `/usr/share/omarchy/*`). This repo is
the safety net for when you manually reset something (`omarchy refresh`,
`omarchy reinstall`, a broken experiment, etc.).

| Path | What it is |
|------|-----------|
| `.config/ghostty/config` | Ghostty config + enabled custom cursor shader |
| `.config/ghostty/shaders/` | Cursor smear/trail GLSL shaders (KroneCorylus) + `ghostty-cursor-color.sh` theme-color sync |
| `.config/hypr/` | Full Hyprland config (bindings, input, monitors, looknfeel, autostart, hyprsunset, ...) |
| `.config/nvim/lua/plugins/smear-cursor.lua` | LazyVim spec for `sphamba/smear-cursor.nvim` |
| `.config/omarchy/plugins/bass.menu/` | Cloned menu plugin (`bass.menu`) incl. scroll-position fix in `Menu.qml` |
| `.config/omarchy/hooks/theme-set.d/` | Theme hooks (incl. `ghostty-cursor-color.sh`) |

## Restore

After a reset or reinstall, copy the whole tree back:

```bash
cp -a ~/dotfiles/.config/. ~/.config/
```

Then reload what needs a restart:

```bash
omarchy restart shell       # menu/bar
omarchy restart terminal    # ghostty/kitty/foot/alacritty
hyprctl reload              # hyprland
```

## Save a new snapshot

After you edit any config you want protected:

```bash
git -C ~/dotfiles add -A
git -C ~/dotfiles commit -m "snapshot"
git -C ~/dotfiles push
```

## Ghostty cursor shader notes

- Enabled: `custom-shader = shaders/cursor_smear.glsl` + `custom-shader-animation = always`
- Swap in another effect by editing `.config/ghostty/config`:
  - `shaders/cursor_blaze.glsl` — fiery trail
  - `shaders/cursor_blaze_no_trail.glsl` — blaze without trail
  - `shaders/cursor_smear_fade.glsl` — fading smear
- Sources: https://github.com/KroneCorylus/shader-playground (commit `803afa2`)

### Theme-color sync

`shaders/ghostty-cursor-color.sh` patches the shader colors to match the active
Omarchy theme — the trail uses the theme **accent** color (`palette` index, default
6), and the blaze shaders get a lightened accent as their secondary color. The
accent index is overridable in `shaders/variant.conf` (`ACCENT_IDX=6`); setting
`CUSTOM_COLOR=#rrggbb` pins a fixed color instead. It is installed as a
`theme-set` hook
(`~/.config/omarchy/hooks/theme-set.d/ghostty-cursor-color.sh`), so every
`omarchy theme set` restyles the trail automatically; Ghostty hot-reloads the
shader files on change. Reinstall after a reset with:

```bash
omarchy hook install theme-set ~/.config/ghostty/shaders/ghostty-cursor-color.sh
~/.config/ghostty/shaders/ghostty-cursor-color.sh   # apply current theme now
```