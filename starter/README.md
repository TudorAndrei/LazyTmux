# LazyTmux Starter

Starter configuration for [LazyTmux](https://github.com/TudorAndrei/LazyTmux).

## Requirements

- tmux 3.5 or newer
- git
- Lua 5.1 or newer, or LuaJIT

Lua is required because LazyTmux evaluates Lua plugin, theme, and statusline
configuration files. The starter displays one actionable message and stops
before bootstrapping when it is unavailable.

## Install

Back up any existing tmux config, then clone this starter:

```sh
git clone https://github.com/TudorAndrei/LazyTmux-starter.git ~/.config/tmux
```

Start tmux or reload your config:

```sh
tmux source-file ~/.config/tmux/.tmux.conf
```

The starter bootstraps LazyTmux into:

```text
~/.local/share/lazytmux/LazyTmux
```

User-editable LazyTmux files are copied to:

```text
~/.config/lazytmux/plugins.lua
~/.config/lazytmux/theme.lua
~/.config/lazytmux/statusline.lua
```
