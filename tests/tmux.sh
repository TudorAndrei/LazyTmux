#!/usr/bin/env sh

set -eu

. "$(dirname "$0")/helpers.sh"
server=""
cleanup_tmux_test() {
  if [ -n "$server" ]; then
    TMUX= tmux -L "$server" kill-server >/dev/null 2>&1 || true
  fi
  cleanup_test
}
trap cleanup_tmux_test EXIT INT TERM
setup_test

server="lazytmux-test-$$"
session="test-$$"
export TMUX_TMPDIR="$TEST_TMUX_TMPDIR"
tmux_home="$TEST_ROOT/home"
mkdir -p "$tmux_home"
TMUX= LAZYTMUX_NO_WATCH=1 HOME="$tmux_home" tmux -L "$server" -f /dev/null new-session -d -s "$session"
TMUX= HOME="$tmux_home" tmux -L "$server" source-file "$REPO_ROOT/lazytmux.tmux"
assert_file "$tmux_home/.local/share/lazytmux/theme.tmux"
assert_file "$tmux_home/.local/share/lazytmux/statusline.tmux"
assert_equal "bottom" "$(TMUX= tmux -L "$server" show-option -gv status-position)"
bindings=$(TMUX= tmux -L "$server" list-keys -T prefix | tr -s '[:space:]' ' ')
assert_contains "$bindings" '-T prefix P '
assert_contains "$bindings" '-T prefix I '
assert_contains "$bindings" '-T prefix R '
assert_contains "$bindings" '-T prefix L resize-pane -R 5'
TMUX= tmux -L "$server" run-shell "if tmux source-file \"$REPO_ROOT/lazytmux.tmux\"; then tmux display-message \"LazyTmux reloaded\"; else tmux display-message \"LazyTmux reload failed\"; fi"
reload_messages=$(TMUX= tmux -L "$server" show-messages)
assert_contains "$reload_messages" 'command: display-message "LazyTmux reloaded"'
TMUX= tmux -L "$server" run-shell "if tmux source-file \"$TEST_ROOT/missing-root/lazytmux.tmux\"; then tmux display-message \"LazyTmux reloaded\"; else tmux display-message \"LazyTmux reload failed\"; fi"
failed_reload_messages=$(TMUX= tmux -L "$server" show-messages)
assert_contains "$failed_reload_messages" 'command: display-message "LazyTmux reload failed"'
TMUX= tmux -L "$server" kill-server
server=""

missing_root="$TEST_ROOT/missing"
missing_session="missing-$$"
missing_server="lazytmux-missing-$$"
mkdir -p "$missing_root/bin"
ln -s "$(command -v tmux)" "$missing_root/bin/tmux"
TMUX= LAZYTMUX_NO_WATCH=1 PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/home" \
  "$missing_root/bin/tmux" -L "$missing_server" -f /dev/null new-session -d -s "$missing_session"
TMUX= PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/home" \
  "$missing_root/bin/tmux" -L "$missing_server" source-file "$REPO_ROOT/lazytmux.tmux"
messages=$(TMUX= PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/home" "$missing_root/bin/tmux" -L "$missing_server" show-messages)
assert_equal "1" "$(printf '%s\n' "$messages" | grep -E -c 'command: display-message "LazyTmux requires Lua 5.1\+ or LuaJIT on PATH')"
[ ! -e "$missing_root/home/.local/share/lazytmux/theme.tmux" ] || fail "missing Lua initialized generated config"
TMUX= PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/home" "$missing_root/bin/tmux" -L "$missing_server" kill-server

starter_server="lazytmux-starter-missing-$$"
TMUX= LAZYTMUX_NO_WATCH=1 PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/starter-home" \
  "$missing_root/bin/tmux" -L "$starter_server" -f /dev/null new-session -d -s "$missing_session-starter"
TMUX= PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/starter-home" \
  "$missing_root/bin/tmux" -L "$starter_server" source-file "$REPO_ROOT/starter/.tmux.conf"
starter_messages=$(TMUX= PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/starter-home" "$missing_root/bin/tmux" -L "$starter_server" show-messages)
assert_equal "1" "$(printf '%s\n' "$starter_messages" | grep -E -c 'command: display-message "LazyTmux requires Lua 5.1\+ or LuaJIT on PATH')"
[ ! -e "$missing_root/starter-home/.local/share/lazytmux/LazyTmux" ] || fail "starter bootstrapped without Lua"
TMUX= PATH="$missing_root/bin:/usr/bin:/bin" HOME="$missing_root/starter-home" "$missing_root/bin/tmux" -L "$starter_server" kill-server

printf '%s\n' "tmux tests passed"
