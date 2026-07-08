---@type LazyTmuxTheme
LazyTmuxTheme = LazyTmuxTheme

local c = LazyTmuxTheme.colors

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
      text = " #S#("
        .. "git -C '#{pane_current_path}' rev-parse --git-dir 2>/dev/null | grep -q /worktrees/ "
        .. "|| git -C '#{pane_current_path}' symbolic-ref --short HEAD 2>/dev/null | sed 's/.*/ (&)/'"
        .. ") ",
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
