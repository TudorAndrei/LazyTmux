---@type LazyTmuxPluginSpec[]
return {
  {
    "tmux-plugins/tmux-sensible",
    name = "sensible",
    enabled = true,
    desc = "Baseline tmux defaults",
  },
  {
    "tmux-plugins/tmux-resurrect",
    name = "resurrect",
    enabled = true,
    desc = "Save and restore tmux sessions",
  },
  {
    "tmux-plugins/tmux-continuum",
    name = "continuum",
    enabled = true,
    desc = "Automatic session save and restore",
  },
  {
    "tmux-plugins/tmux-yank",
    name = "yank",
    enabled = true,
    desc = "Copy text to the system clipboard",
  },
  {
    "tmux-plugins/tmux-open",
    name = "open",
    enabled = true,
    desc = "Open highlighted files and URLs",
  },
  {
    "christoomey/vim-tmux-navigator",
    name = "vim-tmux-navigator",
    enabled = true,
    desc = "Seamless Vim and tmux pane navigation",
  },
  {
    "pschmitt/tmux-ssh-split",
    name = "tmux-ssh-split",
    enabled = true,
    desc = "Split panes while preserving SSH context",
  },
  {
    "TudorAndrei/amux",
    name = "amux",
    enabled = true,
    desc = "AI-assisted tmux workflow helpers",
  },
}
