#!/usr/bin/env sh

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

setup_test() {
  TEST_ROOT=$(mktemp -d "/private/tmp/lazytmux-test.XXXXXX")
  export TEST_ROOT
  export LAZYTMUX_ROOT="$REPO_ROOT"
  export LAZYTMUX_CONFIG="$TEST_ROOT/config"
  export LAZYTMUX_DATA="$TEST_ROOT/data"
  export LAZYTMUX_PLUGIN_DIR="$TEST_ROOT/data/plugins"
}

cleanup_test() {
  case ${TEST_ROOT:-} in
    /private/tmp/lazytmux-test.*) rm -rf "$TEST_ROOT" ;;
    *) printf '%s\n' "refusing to remove unexpected test directory" >&2; return 1 ;;
  esac
}

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_contains() {
  printf '%s' "$1" | grep -F -- "$2" >/dev/null || fail "expected output to contain: $2"
}

assert_not_contains() {
  if printf '%s' "$1" | grep -F -- "$2" >/dev/null; then
    fail "did not expect output to contain: $2"
  fi
}

assert_equal() {
  [ "$1" = "$2" ] || fail "expected '$1', got '$2'"
}

run_cli() {
  "$REPO_ROOT/bin/lazytmux" "$@"
}

assert_fails() {
  output=$("$@" 2>&1) && fail "expected command to fail: $*"
  printf '%s' "$output"
}
