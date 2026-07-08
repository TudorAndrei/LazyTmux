---@meta

---@alias LazyTmuxColor string Hex colors like "#BD93F9" or tmux color names.
---@alias LazyTmuxAttr "bold"|"dim"|"underscore"|"blink"|"reverse"|"hidden"|"italics"|"none"|string

---@class LazyTmuxPluginSpec
---@field [1] string GitHub "owner/repo" or full Git URL.
---@field name string Local plugin directory name.
---@field enabled? boolean Install and source this plugin when true.
---@field desc? string Description shown in the plugin viewer.

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
