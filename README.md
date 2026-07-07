# LazyTmux

LazyTmux is a starter tmux setup inspired by LazyVim: sensible defaults, an
easy extension point, and a plugin manager UI for tmux plugins.

It does not require TPM. Plugins are declared in a small spec file and installed
as Git repositories under `~/.local/share/lazytmux/plugins`.

## Requirements

- tmux 3.2 or newer
- git
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

That file can be copied as the initial contents of a separate
`LazyTmux-starter` repository.

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
```

Edit that file to add, remove, or disable plugins.

## Keymaps

LazyTmux uses `C-a` as the prefix.

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

## Commands

```sh
bin/lazytmux list
bin/lazytmux sync
bin/lazytmux update
bin/lazytmux clean
bin/lazytmux statusline
bin/lazytmux ui
```

Inside tmux, `bin/lazytmux popup` opens the UI in a centered tmux popup.

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
    { fg = "#282A36", bg = "#BD93F9", attr = "bold", text = " #S " },
    { fg = "#F8F8F2", bg = "#6272A4", text = " #H " },
  },
  right = {
    { fg = "#F8F8F2", bg = "#6272A4", text = " %Y-%m-%d " },
  },
}
```

LazyTmux auto-reloads when its tmux files, `plugins.lua`, or `statusline.lua`
change.

## Layout

```text
lazytmux.tmux          tmux entrypoint
bin/lazytmux           plugin manager and viewer
config/options.tmux    defaults
config/keymaps.tmux    key bindings
plugins/default.lua    starter plugin spec
lua/lazytmux/cli.lua   Lua plugin manager and viewer
statusline/default.lua default statusline block spec
```
