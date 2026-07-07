---@alias LazyTmuxColor string Hex colors like "#BD93F9" or tmux color names.
---@alias LazyTmuxAttr "bold"|"dim"|"underscore"|"blink"|"reverse"|"hidden"|"italics"|"none"|string

---@class LazyTmuxStatusBlock
---@field fg LazyTmuxColor Foreground color for this status segment.
---@field bg LazyTmuxColor Background color for this status segment.
---@field attr? LazyTmuxAttr Optional tmux style attribute.
---@field text string Tmux status text. Supports tmux formats like "#{pane_id}" and shell commands like "#(...)".

---@class LazyTmuxWindowStatus
---@field fg LazyTmuxColor
---@field bg LazyTmuxColor
---@field attr? LazyTmuxAttr
---@field text string Tmux window label text. Common formats: "#I" window index, "#W" window name.

---@class LazyTmuxStatuslineSpec
---@field palette table<string, LazyTmuxColor> Named colors for reuse in blocks.
---@field window { normal: LazyTmuxWindowStatus, current: LazyTmuxWindowStatus } Window label styles.
---@field left LazyTmuxStatusBlock[] Left statusline blocks, rendered in order.
---@field right LazyTmuxStatusBlock[] Right statusline blocks, rendered in order.

local c = {
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
}

---@type LazyTmuxStatuslineSpec
return {
  palette = c,
  window = {
    normal = {
      fg = c.FG,
      bg = c.BACKGROUND,
      text = " #I #W ",
    },
    current = {
      fg = c.BACKGROUND,
      bg = c.CYAN,
      text = " #I #W ",
    },
  },
  left = {
    {
      fg = c.BACKGROUND,
      bg = c.PURPLE,
      attr = "bold",
      text = " #S#(git -C '#{pane_current_path}' rev-parse --git-dir 2>/dev/null | grep -q /worktrees/ || git -C '#{pane_current_path}' symbolic-ref --short HEAD 2>/dev/null | sed 's/.*/ (&)/') ",
    },
    {
      fg = c.FG,
      bg = c.COMMENT,
      text = " #H ",
    },
    {
      fg = c.CYAN,
      bg = c.COMMENT,
      text = "#{pane_id} ",
    },
  },
  right = {
    {
      fg = c.FG,
      bg = c.COMMENT,
      text = " %Y-%m-%d ",
    },
    {
      fg = c.BACKGROUND,
      bg = c.PURPLE,
      attr = "bold",
      text = " %H:%M ",
    },
  },
}
