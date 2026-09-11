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
| `.config/ghostty/shaders/` | Cursor smear/trail GLSL shaders (KroneCorylus) |
| `.config/hypr/bindings.lua` | Hyprland keybindings (SUPER+R unbind) |
| `.config/hypr/input.lua` | Hyprland input rules |
| `.config/nvim/lua/plugins/smear-cursor.lua` | LazyVim spec for `sphamba/smear-cursor.nvim` |
| `.config/omarchy/plugins/bass.menu/` | Cloned menu plugin (`bass.menu`) incl. scroll-position fix in `Menu.qml` |

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