# LazyTmux Starter

Starter configuration for [LazyTmux](https://github.com/TudorAndrei/LazyTmux).

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
~/.config/lazytmux/statusline.lua
```

