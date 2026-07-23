#!/usr/bin/env sh

set -eu

"$(dirname "$0")/cli.sh"
"$(dirname "$0")/tmux.sh"
"$(dirname "$0")/smoke.sh"
