# LazyTmux

LazyTmux is a starter tmux setup inspired by LazyVim: sensible defaults, an
easy extension point, and a plugin manager UI for tmux plugins.

It does not require TPM. Plugins are declared in a small spec file and installed
as Git repositories under `~/.local/share/lazytmux/plugins`.

## Requirements

- tmux 3.5 or newer
- git
- Lua 5.1 or newer, or LuaJIT. Lua is intentionally required because your
  plugin, theme, and statusline configuration are Lua files.
- fzf, optional but recommended for the plugin viewer

## Install

### Starter Repo

LazyTmux is designed to use a starter repo, like LazyVim. The starter contains a
small `.tmux.conf` that bootstraps the main LazyTmux distribution into:

```text
~/.local/share/lazytmux/LazyTmux
```

The starter template lives in:

```text
starter/.tmux.conf
```

The starter repo is:

```text
https://github.com/TudorAndrei/LazyTmux-starter
```

### Manual Install

Clone this repository and source the tmux entrypoint from `~/.tmux.conf`:

```tmux
run-shell "/path/to/LazyTmux/lazytmux.tmux"
```

Then reload tmux:

```sh
tmux source-file ~/.tmux.conf
```

On first load, LazyTmux copies the default plugin spec to:

```text
~/.config/lazytmux/plugins.lua
~/.config/lazytmux/theme.lua
~/.config/lazytmux/statusline.lua
```

Edit those files to add plugins, switch themes, or change the statusline.

## Keymaps

LazyTmux uses `C-Space` as the prefix.

| Key | Action |
| --- | --- |
| `prefix + P` | Open the LazyTmux plugin viewer |
| `prefix + I` | Sync plugins, then source installed tmux plugins |
| `prefix + R` | Reload LazyTmux |
| `prefix + \|` | Split pane horizontally |
| `prefix + -` | Split pane vertically |
| `prefix + h/j/k/l` | Move between panes |
| `prefix + H/J/K/L` | Resize panes |

## Plugin Spec

`plugins.lua` returns a Lua table, similar to LazyVim plugin specs:

```lua
return {
  {
    "tmux-plugins/tmux-sensible",
    name = "sensible",
    enabled = true,
    desc = "Baseline tmux defaults",
  },
}
```

- The first value is a GitHub `owner/repo` or a full Git URL.
- `name` is the local directory name under the plugin root.
- `enabled` controls whether the plugin syncs and loads.
- `desc` is shown in the viewer.

Plugin names must be unique safe directory basenames beginning with a letter or
number; later characters may include `.`, `_`, and `-`. Bare `owner/repo`
values expand to GitHub HTTPS URLs; HTTPS,
SSH URI, and SCP-style Git remotes are used unchanged.

`plugins.lua` is always user-owned source. `bin/lazytmux toggle <name>` and the
viewer persist only effective-state differences in
`~/.local/share/lazytmux/plugin-overrides`; toggling back to the declared value
removes that entry instead of rewriting your Lua file.

## Commands

```sh
bin/lazytmux list
bin/lazytmux sync
bin/lazytmux install
bin/lazytmux update
bin/lazytmux clean
bin/lazytmux source
bin/lazytmux toggle sensible
bin/lazytmux themes
bin/lazytmux theme
bin/lazytmux statusline
bin/lazytmux ui
bin/lazytmux popup
bin/lazytmux watch
bin/lazytmux doctor
```

Inside tmux, `bin/lazytmux popup` opens the UI in a centered tmux popup.

## Development

Run all pre-commit checks with hk:

```sh
mise exec -- hk check --all
```

Run the behavioral CLI and isolated-tmux suite with:

```sh
mise run test
```

Lua language-server hints live in `lua/lazytmux/types.lua`. User-facing config
files reference those types with `---@type ...` annotations, which avoids
duplicate type diagnostics when editing multiple config files at once.

## Themes

LazyTmux generates tmux UI colors from:

```text
~/.config/lazytmux/theme.lua
```

The default theme is your Dracula palette. Bundled alternatives live in
`themes/` and can be listed with:

```sh
bin/lazytmux themes
```

To switch themes, copy one of the bundled files over your user theme:

```sh
cp themes/tokyonight.lua ~/.config/lazytmux/theme.lua
```

The active theme is available to `statusline.lua` as `LazyTmuxTheme.colors`, so
statusline blocks can use theme names instead of repeating hex values.

## Statusline

LazyTmux generates the tmux statusline from:

```text
~/.config/lazytmux/statusline.lua
```

The file returns blocks for `left`, `right`, and window labels. Editing a block
is similar to editing a Neovim statusline component:

```lua
return {
  left = {
    { fg = LazyTmuxTheme.colors.BACKGROUND, bg = LazyTmuxTheme.colors.PURPLE, attr = "bold", text = " #S " },
    { fg = LazyTmuxTheme.colors.FG, bg = LazyTmuxTheme.colors.COMMENT, text = " #H " },
  },
  right = {
    { fg = LazyTmuxTheme.colors.FG, bg = LazyTmuxTheme.colors.COMMENT, text = " %Y-%m-%d " },
  },
}
```

LazyTmux auto-reloads when its tmux files, `plugins.lua`, `theme.lua`, or
`statusline.lua` change.

## Layout

```text
lazytmux.tmux          tmux entrypoint
bin/lazytmux           plugin manager and viewer
config/options.tmux    defaults
config/keymaps.tmux    key bindings
plugins/default.lua    starter plugin spec
lua/lazytmux/cli.lua   Lua plugin manager and viewer
lua/lazytmux/types.lua Lua language-server hints for config files
themes/default.lua     default Dracula theme
statusline/default.lua default statusline block spec
```
