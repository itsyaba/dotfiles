# yeab's dotfiles

CachyOS · Hyprland 0.56 (Lua config) · [Caelestia](https://github.com/caelestia-dots/shell) shell · kitty · fish

Look and feel partly ported from [denonmaryland/omarchy-dotfiles](https://github.com/denonmaryland/omarchy-dotfiles) (MIT),
adapted to run on Caelestia instead of Omarchy.

## What's here

| Path | What |
|---|---|
| `.config/hypr/` | Hyprland config (Caelestia's layout, Lua) |
| `.config/caelestia/hypr-user.lua` | My binds, rules, monitors, autostart |
| `.config/caelestia/hypr-look.lua` | Glass blur + macOS-style motion (ported) |
| `.config/caelestia/hypr-recess.lua` | Recessed / raised window depth, follows the Caelestia scheme (ported) |
| `.config/caelestia/shell.json` | Caelestia shell settings |
| `.config/quickshell/` | My own Quickshell configs: `gshot` screenshot UI, `desktop-media` music card, `hypr-settings` |
| `.config/fastfetch/` | `fastfetch` = dashboard (ported); `greeting.jsonc` = compact fetch for new shells |
| `.config/fish/`, `.config/kitty/`, `.config/starship.toml` | Shell and terminal |
| `.local/bin/` | Small helper scripts |

## How the repo works

A bare git repo in `~/.dotfiles` with `$HOME` as the work tree. Files live where they normally do, with no symlinks.

```fish
alias dot 'git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dot status          # only tracked files show up
dot add ~/.config/foo/bar.conf
dot commit -m "..."
dot push
```

## Install on a new machine

```fish
git clone --bare <repo-url> ~/.dotfiles
alias dot 'git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dot checkout        # move any conflicting files aside first
dot config status.showUntrackedFiles no
```

Needs Caelestia (shell + dots) installed first.

## Tweaks

- Dashboard name: `~/.config/fastfetch/brand.txt`; logo: `~/.config/fastfetch/logo.txt`
- Depth style: edit `S` at the top of `hypr-recess.lua` (`style = "raised"`, or `enabled = false`)
- Note: HyprMod writes `hyprland-gui.lua`, which loads last. If it sets `general.border_size = 0` again, the depth effect disappears.
