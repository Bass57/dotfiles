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
| `.config/ghostty/config` | Ghostty config, custom cursor shader, and CSI-u encodings for modified keys |
| `.config/ghostty/shaders/` | Cursor smear/trail GLSL shaders (KroneCorylus) + `ghostty-cursor-color.sh` theme-color sync |
| `.config/hypr/` | Full Hyprland config (bindings, input, monitors, looknfeel, autostart, hyprsunset, ...) |
| `.config/nvim/` | LazyVim setup, editor defaults, modified-key shortcuts, and custom plugin specs |
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
git -C ~/dotfiles push origin HEAD
```

## Neovim word shortcuts

In Insert mode, `Ctrl+Backspace` deletes the previous word, `Ctrl+Delete` deletes
the next word, and `Ctrl+Left` / `Ctrl+Right` move by word. Ghostty sends
distinct CSI-u sequences for these keys so Neovim can recognize them.

## Ghostty cursor shader notes

- Enabled: `custom-shader = shaders/cursor_smear.glsl` + `custom-shader-animation = always`
- Swap in another effect by editing `.config/ghostty/config`:
  - `shaders/cursor_blaze.glsl` — fiery trail
  - `shaders/cursor_blaze_no_trail.glsl` — blaze without trail
  - `shaders/cursor_smear_fade.glsl` — fading smear
- Sources: https://github.com/KroneCorylus/shader-playground (commit `803afa2`)
  - pristine copies kept in `shaders/original/` so the patch script can reset each run

### Theme-color sync

`shaders/ghostty-cursor-color.sh` patches the shader colors in one of three modes,
selected in `shaders/variant.conf`:

| Mode | Config | Effect |
|---|---|---|
| **Rainbow** | `RAINBOW=1` (default), `RAINBOW_SPEED=0.40` | trail cycles through all neon colors over time |
| **Fixed color** | `RAINBOW=0` + `CUSTOM_COLOR=#00E5FF` | pins a vivid custom color |
| **Theme accent** | `RAINBOW=0`, blank `CUSTOM_COLOR` | follows theme `palette` index `ACCENT_IDX=6` |

The blaze shaders get a lightened accent as their secondary color. The script
resets from the pristine copies in `shaders/original/` before patching, so every
run is deterministic. It is installed as a `theme-set` hook
(`~/.config/omarchy/hooks/theme-set.d/ghostty-cursor-color.sh`), so every
`omarchy theme set` restyles the trail automatically; Ghostty hot-reloads the
shader files on change. Reinstall after a reset with:

```bash
omarchy hook install theme-set ~/.config/ghostty/shaders/ghostty-cursor-color.sh
~/.config/ghostty/shaders/ghostty-cursor-color.sh   # apply current theme now
```

### Neon accent

The neon cyan `#00E5FF` is applied across the setup:

- **opencode TUI**: `.config/opencode/themes/neon.json` (custom `neon` theme; selected in
  `.config/opencode/tui.json` + `tui.jsonc`), plus neon agent badge colors in
  `.config/opencode/opencode.json`.
- **Neovim**: hook `.config/omarchy/hooks/theme-set.d/nvim-neon.sh` re-pins the
  aether `accent` + `cursor` to `#00E5FF` in the staged neovim.lua after every
  `omarchy theme set`. Run `:LazyReload` in Neovim to apply.