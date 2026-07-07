# LazyTmux defaults based on the user's tmux config.

set-option -g default-terminal "tmux-256color"
set-option -g extended-keys on
set-option -g extended-keys-format csi-u
set-option -g detach-on-destroy off
set-option -g history-limit 100000
set-option -ag update-environment " HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE OZONE_PLATFORM_HINT OZONE_PLATFORM ELECTRON_OZONE_PLATFORM_HINT"

set-option -g base-index 1
setw -g pane-base-index 1
set-option -g renumber-windows on
set-option -g mouse on
set-option -g focus-events on
set-option -g set-clipboard on

set-window-option -g status-keys vi
set-window-option -g mode-keys vi
set-option -g -a terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'
set-option -ga terminal-overrides ",*:Tc"
set-option -ga terminal-overrides ",*:Sync@"
set-option -ga terminal-features "*:hyperlinks"

set-option -g status-interval 5
set-option -g status on
set-option -g status-position top
set-option -g status-justify absolute-centre
set-option -g status-left-length 80
set-option -g status-right-length 80
set-option -g status-style "fg=#F8F8F2,bg=#282A36,none"
set-option -g window-status-separator ""

set-option -g pane-border-style "fg=#44475A,bg=#282A36"
set-option -g pane-active-border-style "fg=#8BE9FD,bg=#282A36"
set-option -g display-panes-colour "#6272A4"
set-option -g display-panes-active-colour "#8BE9FD"
setw -g clock-mode-colour "#BD93F9"
set-option -g message-style "fg=#F8F8F2,bg=#44475A"
set-option -g message-command-style "fg=#F8F8F2,bg=#44475A"

set-environment -g TMUX_PLUGIN_MANAGER_PATH "#{E:LAZYTMUX_DATA}/plugins/"

set-option -g @amux-status off
set-option -g @amux-picker-key "l"

set-option -g @ssh-split-h-key "v"
set-option -g @ssh-split-v-key "h"
set-option -g @ssh-split-w-key "c"
set-option -g @ssh-split-keep-cwd "true"
set-option -g @ssh-split-keep-remote-cwd "true"
set-option -g @ssh-split-strip-cmd "true"
set-option -g @ssh-split-fail "false"

set-option -g @resurrect-strategy-nvim 'session'
set-option -g @resurrect-capture-pane-contents 'on'
set-option -g @resurrect-processes 'ssh'
set-option -g @resurrect-save-bash-history 'on'
set-option -g @resurrect-save-shell-history 'on'
set-option -g @resurrect-strategy-vim 'session'
set-option -g @resurrect-strategy-vi 'session'
set-option -g @resurrect-dir '~/.local/state/tmux/resurrect'
set-option -g @resurrect-delete-backup-after '2'

set-option -g @continuum-restore 'on'
set-option -g @continuum-save-interval '15'
