#!/usr/bin/env sh

set -eu

. "$(dirname "$0")/helpers.sh"
server=""
cleanup_smoke() {
  if [ -n "$server" ]; then
    TMUX= TMUX_TMPDIR=/private/tmp tmux -L "$server" kill-server >/dev/null 2>&1 || true
  fi
  cleanup_test
}
trap cleanup_smoke EXIT INT TERM
setup_test
export REPO_ROOT

fake_bin="$TEST_ROOT/fake-bin"
starter_home="$TEST_ROOT/starter home"
server="lazytmux-smoke-$$"
mkdir -p "$fake_bin" "$starter_home"
cat > "$fake_bin/git" <<'EOF'
#!/usr/bin/env sh

set -eu

if [ "$1" = clone ]; then
  for argument in "$@"; do
    destination=$argument
  done
  mkdir -p "$(dirname "$destination")"
  if [ "$(basename "$destination")" = LazyTmux ]; then
    ln -s "$REPO_ROOT" "$destination"
  else
    mkdir -p "$destination/.git"
  fi
fi
EOF
chmod +x "$fake_bin/git"

TMUX= LAZYTMUX_NO_WATCH=1 PATH="$fake_bin:$PATH" TMUX_TMPDIR=/private/tmp HOME="$starter_home" \
  tmux -L "$server" -f /dev/null new-session -d -s smoke
TMUX= PATH="$fake_bin:$PATH" TMUX_TMPDIR=/private/tmp HOME="$starter_home" \
  tmux -L "$server" source-file "$REPO_ROOT/starter/.tmux.conf"

cloned_root="$starter_home/.local/share/lazytmux/LazyTmux"
attempt=0
while [ ! -f "$cloned_root/lazytmux.tmux" ] && [ "$attempt" -lt 50 ]; do
  attempt=$((attempt + 1))
  sleep 0.1
done
assert_file "$cloned_root/lazytmux.tmux"

export LAZYTMUX_ROOT="$cloned_root"
export LAZYTMUX_CONFIG="$starter_home/.config/lazytmux"
export LAZYTMUX_DATA="$starter_home/.local/share/lazytmux"
export LAZYTMUX_PLUGIN_DIR="$LAZYTMUX_DATA/plugins"
export PATH="$fake_bin:$PATH"
doctor=$(run_cli doctor)
assert_contains "$doctor" "ok      tmux"
assert_contains "$doctor" "ok      git"

printf '%s\n' 'return {{ "file:///fixture", name = "fixture", enabled = true }, { "file:///disabled", name = "disabled", enabled = false }}' > "$LAZYTMUX_CONFIG/plugins.lua"
run_cli sync
[ -d "$LAZYTMUX_PLUGIN_DIR/fixture/.git" ] || fail "fixture plugin did not sync"
run_cli toggle fixture
run_cli toggle fixture
[ ! -s "$LAZYTMUX_DATA/plugin-overrides" ] || fail "fixture override was not cleaned up"
run_cli theme
run_cli statusline
assert_file "$LAZYTMUX_DATA/theme.tmux"
assert_file "$LAZYTMUX_DATA/statusline.tmux"
mkdir -p "$LAZYTMUX_PLUGIN_DIR/disabled"
run_cli clean
[ ! -d "$LAZYTMUX_PLUGIN_DIR/disabled" ] || fail "disabled fixture was not cleaned"

TMUX= TMUX_TMPDIR=/private/tmp tmux -L "$server" run-shell "if tmux source-file \"$cloned_root/lazytmux.tmux\"; then tmux display-message \"LazyTmux reloaded\"; else tmux display-message \"LazyTmux reload failed\"; fi"
messages=$(TMUX= TMUX_TMPDIR=/private/tmp tmux -L "$server" show-messages)
assert_contains "$messages" 'command: display-message "LazyTmux reloaded"'

printf '%s\n' "smoke test passed"
