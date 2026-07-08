---@alias LazyTmuxColor string Hex colors like "#BD93F9" or tmux color names.

---@class LazyTmuxThemeStyles
---@field status? string tmux style for the status bar.
---@field pane_border? string tmux style for inactive pane borders.
---@field pane_active_border? string tmux style for active pane borders.
---@field display_panes? LazyTmuxColor Color for pane numbers.
---@field display_panes_active? LazyTmuxColor Color for the active pane number.
---@field clock? LazyTmuxColor Color for clock mode.
---@field message? string tmux style for messages.
---@field message_command? string tmux style for command prompts.
---@field mode? string tmux style for copy-mode selection.

---@class LazyTmuxTheme
---@field name string Human-readable theme name.
---@field colors table<string, LazyTmuxColor> Named colors available to statusline.lua as LazyTmuxTheme.colors.
---@field styles LazyTmuxThemeStyles tmux UI styles generated into theme.tmux.

---@type LazyTmuxTheme
return {
  name = "dracula",
  colors = {
    BACKGROUND = "#282A36",
    FG = "#F8F8F2",
    SELECTION = "#44475A",
    COMMENT = "#6272A4",
    PURPLE = "#BD93F9",
    RED = "#FF5555",
    GREEN = "#50FA7B",
    YELLOW = "#F1FA8C",
    ORANGE = "#FFB86C",
    CYAN = "#8BE9FD",
    PINK = "#FF79C6",
  },
  styles = {
    status = "fg=#F8F8F2,bg=#282A36,none",
    pane_border = "fg=#44475A,bg=#282A36",
    pane_active_border = "fg=#8BE9FD,bg=#282A36",
    display_panes = "#6272A4",
    display_panes_active = "#8BE9FD",
    clock = "#BD93F9",
    message = "fg=#F8F8F2,bg=#44475A",
    message_command = "fg=#F8F8F2,bg=#44475A",
    mode = "fg=#F8F8F2,bg=#44475A",
  },
}

