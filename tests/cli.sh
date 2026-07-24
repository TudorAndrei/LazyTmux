#!/usr/bin/env sh

set -eu

. "$(dirname "$0")/helpers.sh"
trap cleanup_test EXIT INT TERM
setup_test

list_output=$(run_cli list)
assert_contains "$list_output" "sensible"
lua "$REPO_ROOT/lua/lazytmux/cli.lua" list >/dev/null
luajit "$REPO_ROOT/lua/lazytmux/cli.lua" list >/dev/null
assert_file "$LAZYTMUX_CONFIG/plugins.lua"
assert_file "$LAZYTMUX_CONFIG/theme.lua"
assert_file "$LAZYTMUX_CONFIG/statusline.lua"

mkdir -p "$TEST_ROOT/copy-failure/bin"
cat > "$TEST_ROOT/copy-failure/bin/cp" <<'EOF'
#!/usr/bin/env sh
exit 1
EOF
chmod +x "$TEST_ROOT/copy-failure/bin/cp"
copy_failure=$(assert_fails env \
  LAZYTMUX_ROOT="$REPO_ROOT" \
  LAZYTMUX_CONFIG="$TEST_ROOT/copy-failure/config" \
  LAZYTMUX_DATA="$TEST_ROOT/copy-failure/data" \
  LAZYTMUX_PLUGIN_DIR="$TEST_ROOT/copy-failure/data/plugins" \
  PATH="$TEST_ROOT/copy-failure/bin:$PATH" \
  "$REPO_ROOT/bin/lazytmux" list)
assert_contains "$copy_failure" "copying default plugin spec failed"

quoted_root="$TEST_ROOT/root with ' quote"
ln -s "$REPO_ROOT" "$quoted_root"
quoted_list=$(env \
  LAZYTMUX_ROOT="$quoted_root" \
  LAZYTMUX_CONFIG="$TEST_ROOT/config with ' quote" \
  LAZYTMUX_DATA="$TEST_ROOT/data with ' quote" \
  LAZYTMUX_PLUGIN_DIR="$TEST_ROOT/data with ' quote/plugins" \
  "$REPO_ROOT/bin/lazytmux" list)
assert_contains "$quoted_list" "sensible"

run_cli theme
run_cli statusline
assert_file "$LAZYTMUX_DATA/theme.tmux"
assert_file "$LAZYTMUX_DATA/statusline.tmux"
run_cli theme catppuccin-mocha
assert_contains "$(cat "$LAZYTMUX_CONFIG/theme.lua")" 'name = "catppuccin-mocha"'
assert_contains "$(cat "$LAZYTMUX_DATA/theme.tmux")" '#1E1E2E'
unknown_theme=$(assert_fails run_cli theme absent)
assert_contains "$unknown_theme" "unknown bundled theme: absent"
assert_contains "$(cat "$LAZYTMUX_CONFIG/theme.lua")" 'name = "catppuccin-mocha"'

spec_before=$(cksum "$LAZYTMUX_CONFIG/plugins.lua")
run_cli toggle sensible
assert_contains "$(run_cli list)" "sensible                  no"
assert_contains "$(cat "$LAZYTMUX_DATA/plugin-overrides")" "sensible	false"
run_cli toggle sensible
[ ! -s "$LAZYTMUX_DATA/plugin-overrides" ] || fail "redundant override was retained"
assert_equal "$spec_before" "$(cksum "$LAZYTMUX_CONFIG/plugins.lua")"

printf '%s\n' 'return {{ "owner/quoted.git", desc = "single '\''quote", enabled = false }, { repo = "git@github.com:owner/scp.git" }, { repo = "ssh://git@example.com/owner/uri.git" }, { repo = "https://example.com/owner/https.git" }}' > "$LAZYTMUX_CONFIG/plugins.lua"
run_cli toggle quoted
assert_contains "$(cat "$LAZYTMUX_DATA/plugin-overrides")" "quoted	true"
unknown_toggle=$(assert_fails run_cli toggle absent)
assert_contains "$unknown_toggle" "unknown plugin: absent"

mkdir -p "$TEST_ROOT/fakebin"
export TRACE="$TEST_ROOT/trace"
cat > "$TEST_ROOT/fakebin/git" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' "$@" >> "$TRACE"
[ "${FAIL_GIT:-}" = 1 ] && exit 7
exit 0
EOF
chmod +x "$TEST_ROOT/fakebin/git"
old_path=$PATH
export PATH="$TEST_ROOT/fakebin:$PATH"
run_cli install
trace=$(cat "$TRACE")
assert_contains "$trace" "https://github.com/owner/quoted.git"
assert_contains "$trace" "git@github.com:owner/scp.git"
assert_contains "$trace" "ssh://git@example.com/owner/uri.git"
assert_contains "$trace" "https://example.com/owner/https.git"
export FAIL_GIT=1
failure=$(assert_fails run_cli install)
unset FAIL_GIT
assert_contains "$failure" "cloning plugin quoted failed"
export PATH=$old_path

printf '%s\n' 'return {{ "owner/repo", name = "updated", enabled = true }}' > "$LAZYTMUX_CONFIG/plugins.lua"
: > "$LAZYTMUX_DATA/plugin-overrides"
mkdir -p "$LAZYTMUX_PLUGIN_DIR/updated/.git"
export PATH="$TEST_ROOT/fakebin:$PATH"
export FAIL_GIT=1
update_failure=$(assert_fails run_cli update)
unset FAIL_GIT
assert_contains "$update_failure" "updating plugin updated failed"
export PATH=$old_path

printf '%s\n' 'return {{ "owner/repo", name = "../escape", enabled = false }}' > "$LAZYTMUX_CONFIG/plugins.lua"
mkdir -p "$TEST_ROOT/escape"
unsafe=$(assert_fails run_cli clean)
assert_contains "$unsafe" "unsafe name"
[ -d "$TEST_ROOT/escape" ] || fail "unsafe clean escaped test boundary"
printf '%s\n' 'return {{ "owner/repo", name = "nested/name", enabled = false }}' > "$LAZYTMUX_CONFIG/plugins.lua"
nested=$(assert_fails run_cli clean)
assert_contains "$nested" "unsafe name"
printf '%s\n' 'return {{ "owner/repo", name = ".", enabled = false }}' > "$LAZYTMUX_CONFIG/plugins.lua"
reserved=$(assert_fails run_cli clean)
assert_contains "$reserved" "unsafe name"
printf '%s\n' 'return {{ "owner/one", name = "same" }, { "owner/two", name = "same" }}' > "$LAZYTMUX_CONFIG/plugins.lua"
duplicate=$(assert_fails run_cli list)
assert_contains "$duplicate" "duplicate plugin name"

printf '%s\n' 'return {{ "owner/repo", name = "disabled", enabled = false }}' > "$LAZYTMUX_CONFIG/plugins.lua"
: > "$LAZYTMUX_DATA/plugin-overrides"
mkdir -p "$LAZYTMUX_PLUGIN_DIR/disabled"
mkdir -p "$TEST_ROOT/fakebin"
cat > "$TEST_ROOT/fakebin/rm" <<'EOF'
#!/usr/bin/env sh
exit 1
EOF
chmod +x "$TEST_ROOT/fakebin/rm"
export PATH="$TEST_ROOT/fakebin:$PATH"
remove_failure=$(assert_fails run_cli clean)
assert_contains "$remove_failure" "removing plugin disabled failed"
export PATH=$old_path

printf '%s\n' 'return {{ "owner/repo", name = "sourceable", enabled = true }}' > "$LAZYTMUX_CONFIG/plugins.lua"
mkdir -p "$LAZYTMUX_PLUGIN_DIR/sourceable/.git"
printf '%s\n' '# plugin entrypoint' > "$LAZYTMUX_PLUGIN_DIR/sourceable/entry.tmux"
cat > "$TEST_ROOT/fakebin/tmux" <<'EOF'
#!/usr/bin/env sh
exit 1
EOF
chmod +x "$TEST_ROOT/fakebin/tmux"
export PATH="$TEST_ROOT/fakebin:$PATH"
export TMUX=inside
source_failure=$(assert_fails run_cli source)
assert_contains "$source_failure" "sourcing plugin sourceable failed"
popup_failure=$(assert_fails run_cli popup)
assert_contains "$popup_failure" "opening tmux popup failed"
unset TMUX
export PATH=$old_path

cat > "$TEST_ROOT/fakebin/fzf" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' 'ctrl-e' 'missing yes sourceable editor test'
EOF
cat > "$TEST_ROOT/fakebin/editor" <<'EOF'
#!/usr/bin/env sh
exit 1
EOF
chmod +x "$TEST_ROOT/fakebin/fzf" "$TEST_ROOT/fakebin/editor"
export PATH="$TEST_ROOT/fakebin:$PATH"
editor_failure=$(EDITOR="$TEST_ROOT/fakebin/editor" assert_fails run_cli ui)
assert_contains "$editor_failure" "launching editor failed"
export PATH=$old_path

cat > "$TEST_ROOT/fakebin/fzf" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' 'tokyonight'
EOF
chmod +x "$TEST_ROOT/fakebin/fzf"
export PATH="$TEST_ROOT/fakebin:$PATH"
run_cli theme-picker
assert_contains "$(cat "$LAZYTMUX_CONFIG/theme.lua")" 'name = "tokyonight"'
export PATH=$old_path

mkdir -p "$TEST_ROOT/plain-bin"
ln -s "$(command -v sh)" "$TEST_ROOT/plain-bin/sh"
ln -s "$(command -v lua)" "$TEST_ROOT/plain-bin/lua"
ln -s "$(command -v mkdir)" "$TEST_ROOT/plain-bin/mkdir"
ln -s "$(command -v cp)" "$TEST_ROOT/plain-bin/cp"
ln -s "$(command -v find)" "$TEST_ROOT/plain-bin/find"
ln -s "$(command -v sort)" "$TEST_ROOT/plain-bin/sort"
cat > "$TEST_ROOT/plain-bin/clear" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF
chmod +x "$TEST_ROOT/plain-bin/clear"
plain_ui=$(printf 'q\n' | env PATH="$TEST_ROOT/plain-bin" "$REPO_ROOT/bin/lazytmux" ui)
assert_contains "$plain_ui" "LazyTmux plugins"
plain_theme_picker=$(printf '1\n' | env PATH="$TEST_ROOT/plain-bin" "$REPO_ROOT/bin/lazytmux" theme-picker)
assert_contains "$plain_theme_picker" "applied theme catppuccin-mocha"

printf '%s\n' 'return { styles = { status = {} } }' > "$LAZYTMUX_CONFIG/theme.lua"
printf '%s\n' 'known-theme' > "$LAZYTMUX_DATA/theme.tmux"
theme_failure=$(assert_fails run_cli theme)
assert_contains "$theme_failure" "theme style status must be a string"
assert_equal "known-theme" "$(cat "$LAZYTMUX_DATA/theme.tmux")"
printf '%s\n' 'return { left = {{ fg = "red" }}, right = {} }' > "$LAZYTMUX_CONFIG/statusline.lua"
printf '%s\n' 'known-statusline' > "$LAZYTMUX_DATA/statusline.tmux"
status_failure=$(assert_fails run_cli statusline)
assert_contains "$status_failure" "statusline block missing fg or bg"
assert_equal "known-statusline" "$(cat "$LAZYTMUX_DATA/statusline.tmux")"

printf '%s\n' 'return { styles = { status = "fg=red" } }' > "$LAZYTMUX_CONFIG/theme.lua"
rm "$LAZYTMUX_DATA/theme.tmux"
mkdir "$LAZYTMUX_DATA/theme.tmux"
rename_failure=$(assert_fails run_cli theme)
assert_contains "$rename_failure" "publishing"
[ -z "$(find "$LAZYTMUX_DATA" -name 'theme.tmux.tmp.*' -print)" ] || fail "atomic write left a temporary file"
rmdir "$LAZYTMUX_DATA/theme.tmux"

printf '%s\n' "cli tests passed"
