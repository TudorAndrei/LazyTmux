# TODO: Harden LazyTmux

## Phase 1: Establish behavioral verification

- [x] Add safe temporary-directory and assertion helpers in `tests/helpers.sh`.
- [x] Add CLI happy-path coverage in `tests/cli.sh`.
- [x] Add isolated entrypoint and keymap coverage in `tests/tmux.sh`.
- [x] Add the single test entrypoint `tests/run.sh`.
- [x] Add the `test` task to `mise.toml`.
- [x] Add `.github/workflows/ci.yml` for hk and behavioral tests on tmux 3.7b.
- [x] Document the test command in `README.md`.
- [x] Commit: `test: add CLI and tmux integration coverage`

## Phase 2: Enforce command and plugin safety

- [x] Normalize Lua 5.1, LuaJIT, and newer-Lua command statuses in `lua/lazytmux/cli.lua`.
- [x] Separate checked commands and captures from expected-failure probes.
- [x] Propagate required command failures to a nonzero CLI exit.
- [x] Validate plugin names as unique safe basenames in `load_specs()`.
- [x] Strip `.git` from derived plugin names.
- [x] Add a final containment guard to `M.clean()`.
- [x] Support documented full Git URL forms in `normalize_url()`.
- [x] Test failed clone, pull, copy, delete, tmux source, popup, and editor commands.
- [x] Test unsafe and duplicate plugin-name rejection before filesystem mutation.
- [x] Test GitHub shorthand, HTTPS, SSH URI, and SCP-style clone arguments.
- [x] Commit: `fix(plugins): enforce safe paths and command failures`

## Phase 3: Persist UI toggles without rewriting Lua

- [x] Add the non-executable plugin-override file and parsing helpers under `LAZYTMUX_DATA`.
- [x] Preserve declared enabled state and apply overrides in `load_specs()`.
- [x] Replace textual source rewriting with `M.toggle(name)`.
- [x] Remove redundant overrides when effective state returns to declared state.
- [x] Add and validate the `toggle <name>` CLI command.
- [x] Route the fzf Enter action through `M.toggle(name)`.
- [x] Document override location and precedence in `README.md`.
- [x] Test valid Lua spec layouts that the old textual toggler could not handle.
- [x] Test repeated toggles, unknown names, omitted `enabled`, and override cleanup.
- [x] Commit: `fix(ui): persist plugin toggles without rewriting specs`

## Phase 4: Make generated configuration atomic

- [x] Add a same-directory atomic-write helper with scoped failure cleanup.
- [x] Render and validate all theme output before publishing `theme.tmux`.
- [x] Render and validate all statusline output before publishing `statusline.tmux`.
- [x] Publish the plugin override map atomically.
- [x] Test preservation of last-known-good files after malformed input.
- [x] Test simulated write/rename failures and removal of only owned temporary files.
- [x] Commit: `fix(config): publish generated files atomically`

## Phase 5: Make runtime requirements explicit

- [x] Raise the documented tmux minimum from 3.2 to 3.7b.
- [x] Document Lua 5.1+ or LuaJIT as an intentional required runtime.
- [x] Add an early Lua preflight around initialization in `lazytmux.tmux`.
- [x] Add an early Lua preflight to `starter/.tmux.conf`.
- [x] Report the active Lua implementation/version from `M.doctor()`.
- [x] Test tmux initialization with and without a Lua runtime on `PATH`.
- [x] Confirm the missing-runtime path emits one actionable message and no secondary source errors.
- [x] Commit: `fix(bootstrap): enforce supported tmux and Lua runtimes`

## Phase 6: Correct reload and key bindings

- [x] Reload `#{E:LAZYTMUX_ROOT}/lazytmux.tmux` from `prefix + R`.
- [x] Display reload success only after a successful source and report failure otherwise.
- [x] Remove the unshipped worktree-picker binding.
- [x] Assert one effective meaning for `prefix + L`.
- [x] Test effective `P`, `I`, `R`, and `L` bindings in an isolated tmux server.
- [x] Test reload from a starter-style home without `~/.tmux.conf`.
- [x] Reconcile `README.md` and `starter/README.md` with final requirements and behavior.
- [x] Run the full suite with Lua 5.1 and LuaJIT.
- [x] Commit: `fix(keymaps): make reload and resize bindings reliable`

## Phase 7: Align the maintained tmux baseline

- [x] Update LazyTmux and starter requirements to tmux 3.7b or newer.
- [x] Build tmux 3.7b in GitHub Actions before lint and behavioral tests.
- [x] Run the behavioral suite with tmux 3.7b.
- [x] Commit: `chore(compat): align tmux baseline with 3.7b`

## Verification

- [x] `mise exec -- hk check --all` passes with zero formatting or luacheck errors.
- [x] `mise run test` passes from a clean checkout.
- [x] CLI tests verify nonzero exits and actionable errors for every required external-command failure.
- [x] `clean` tests prove invalid, reserved, nested, and duplicate plugin names cannot reach `rm`.
- [x] URL tests cover GitHub shorthand and the documented full Git remote forms.
- [x] Toggle tests prove `plugins.lua` is byte-for-byte unchanged after UI/CLI toggles.
- [x] Toggle tests prove the override file stores only differences from declared plugin state.
- [x] Generation tests prove invalid theme or statusline input preserves the last-known-good tmux file.
- [x] Isolated tmux tests prove first load creates config and generated files with Lua available.
- [x] Isolated tmux tests prove missing Lua stops initialization with one clear prerequisite message.
- [x] Compatibility checks run with Lua 5.1 and LuaJIT.
- [x] The tmux configuration syntax and behavioral suite are smoke-tested with tmux 3.7b.
- [x] Effective keymaps contain one `prefix + L` resize binding and working `P`, `I`, and `R` bindings.
- [x] Manual smoke test: start from an empty temporary home, source `starter/.tmux.conf`, run `doctor`, sync one local fixture plugin, toggle it twice, generate theme/statusline files, reload with `prefix + R`, and clean the disabled fixture.
- [x] Edge cases tested: spaces in filesystem roots, single quotes in filesystem roots, missing optional fzf, malformed specs, duplicate plugin names, failed Git operations, malformed status blocks, and interrupted output replacement.
- [x] Existing plugin list, theme rendering, statusline rendering, watcher locking, popup fallback, and Lua 5.1 compatibility have no regressions.

## Review

- [x] Code reviewed with special attention to command classification and deletion containment.
- [x] PLAN.md updated if the approach changes during implementation.
- [x] All phase commits are clean and use the exact drafted messages.
- [x] Every phase leaves lint and tests passing before the next phase begins.
- [x] TODO.md items are all checked off.
