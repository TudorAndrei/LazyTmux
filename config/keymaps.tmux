unbind C-b
set-option -g prefix C-Space
bind-key C-Space send-prefix

unbind r
bind-key r refresh-client

bind-key R run-shell 'if tmux source-file "#{E:LAZYTMUX_ROOT}/lazytmux.tmux"; then tmux display-message "LazyTmux reloaded"; else tmux display-message "LazyTmux reload failed"; fi'
bind-key P run-shell '"#{E:LAZYTMUX_ROOT}/bin/lazytmux" popup'
bind-key I run-shell -b '"#{E:LAZYTMUX_ROOT}/bin/lazytmux" sync && "#{E:LAZYTMUX_ROOT}/bin/lazytmux" source'

unbind '"'
unbind %
unbind v
unbind h
unbind n
unbind w

bind-key x kill-pane
bind-key Tab switch-client -l
bind-key n command-prompt "rename-window '%%'"

is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"

bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'

bind-key S run-shell 'tmux save-buffer - | tmux load-buffer -'
bind-key C-s run-shell -b 'test -d "#{E:LAZYTMUX_DATA}/plugins/resurrect" && tmux display-message "Saving session..." && "#{E:LAZYTMUX_DATA}/plugins/resurrect/scripts/save.sh" || tmux display-message "Install plugins with prefix + I"'
bind-key C-r run-shell -b 'test -d "#{E:LAZYTMUX_DATA}/plugins/resurrect" && tmux display-message "Restoring session..." && "#{E:LAZYTMUX_DATA}/plugins/resurrect/scripts/restore.sh" || tmux display-message "Install plugins with prefix + I"'

bind-key | split-window -h -c "#{pane_current_path}"
bind-key - split-window -v -c "#{pane_current_path}"

bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R

bind-key H resize-pane -L 5
bind-key J resize-pane -D 3
bind-key K resize-pane -U 3
bind-key L resize-pane -R 5

bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
bind-key [ copy-mode
