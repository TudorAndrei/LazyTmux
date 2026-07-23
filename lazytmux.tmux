# LazyTmux entrypoint.

set-environment -gF LAZYTMUX_ROOT "#{d:current_file}"
set-environment -gF LAZYTMUX_CONFIG "#{E:HOME}/.config/lazytmux"
set-environment -gF LAZYTMUX_DATA "#{E:HOME}/.local/share/lazytmux"

if-shell 'command -v luajit >/dev/null 2>&1 || command -v lua >/dev/null 2>&1' {
  run-shell 'mkdir -p "$HOME/.config/lazytmux" "$HOME/.local/share/lazytmux/plugins"'
  run-shell 'test -f "$HOME/.config/lazytmux/plugins.lua" || cp "#{E:LAZYTMUX_ROOT}/plugins/default.lua" "$HOME/.config/lazytmux/plugins.lua"'
  run-shell 'test -f "$HOME/.config/lazytmux/theme.lua" || cp "#{E:LAZYTMUX_ROOT}/themes/default.lua" "$HOME/.config/lazytmux/theme.lua"'
  run-shell 'test -f "$HOME/.config/lazytmux/statusline.lua" || cp "#{E:LAZYTMUX_ROOT}/statusline/default.lua" "$HOME/.config/lazytmux/statusline.lua"'

  source-file -F "#{E:LAZYTMUX_ROOT}/config/options.tmux"
  source-file -F "#{E:LAZYTMUX_ROOT}/config/keymaps.tmux"

  run-shell '"#{E:LAZYTMUX_ROOT}/bin/lazytmux" theme'
  source-file -F "#{E:LAZYTMUX_DATA}/theme.tmux"
  run-shell '"#{E:LAZYTMUX_ROOT}/bin/lazytmux" statusline'
  source-file -F "#{E:LAZYTMUX_DATA}/statusline.tmux"
  run-shell -b '"#{E:LAZYTMUX_ROOT}/bin/lazytmux" source >/dev/null 2>&1'
  if-shell '[ "#{E:LAZYTMUX_NO_WATCH}" != 1 ]' 'run-shell -b "\"#{E:LAZYTMUX_ROOT}/bin/lazytmux\" watch \"#{pid}\" >/dev/null 2>&1"'
} {
  display-message "LazyTmux requires Lua 5.1+ or LuaJIT on PATH; install one and reload."
}
