# Plan: Harden LazyTmux

## Goal

Make LazyTmux safe and predictable enough to serve as a LazyVim-style tmux
distribution: retain Lua as an intentional runtime requirement, enforce plugin
filesystem boundaries, report command failures accurately, make generated
configuration recoverable, ensure the documented tmux and starter workflows
work, and add automated behavioral coverage for the CLI and tmux entrypoint.

## Approach

The implementation will remain compatible with Lua 5.1 and LuaJIT and will keep
`bin/lazytmux` as the public executable. The command helpers in
`lua/lazytmux/cli.lua` will distinguish expected probes from commands that must
succeed, normalizing the different `os.execute` return shapes used by Lua 5.1,
LuaJIT, and newer Lua releases. Mutating commands such as clone, pull, copy,
remove, and tmux source operations will fail the CLI with an actionable error;
predicate checks such as directory existence and process liveness will remain
non-throwing.

Plugin specs will be validated when `load_specs()` normalizes them. A plugin
name must be a single safe directory basename, names must be unique, derived
names will have a trailing `.git` removed, and `clean` will only remove a path
that passed those checks. `normalize_url()` will pass through documented full
Git URL forms and SCP-style Git remotes while continuing to expand bare
`owner/repo` values to GitHub HTTPS URLs.

The fzf viewer will stop editing arbitrary Lua source text. UI toggles will be
stored as a generated override map under `LAZYTMUX_DATA`; the map will contain
only values that differ from the corresponding `enabled` value in
`plugins.lua`. Returning a plugin to its declared value removes its override.
An explicit `toggle <name>` CLI command will share this implementation with the
fzf UI and provide a stable black-box test surface. The override file will be a
simple, non-executable text format rather than another Lua file.

Theme, statusline, and plugin-override output will be rendered and validated in
memory, written to a temporary file beside the destination, and renamed only
after the write and close succeed. A bad user statusline must leave the previous
generated `statusline.tmux` untouched.

Lua remains a required dependency. `README.md` and `starter/README.md` will
state that requirement explicitly, while `starter/.tmux.conf` and
`lazytmux.tmux` will provide an early actionable message when neither `lua` nor
`luajit` is available. Because `extended-keys-format` is intentional,
`README.md` will raise the supported tmux version from 3.2 to 3.5 rather than
removing that option.

`prefix + R` will source `LAZYTMUX_ROOT/lazytmux.tmux`, matching its documented
purpose of reloading LazyTmux regardless of where the parent tmux configuration
lives. Its success message will only be displayed after a successful source.
The unshipped worktree-picker binding will be removed so `prefix + L` has one
unambiguous meaning: resize right, as documented.

Behavioral tests will use a dependency-light shell harness under `tests/`.
They will execute the public CLI with temporary config/data directories and
fake external commands, and start an isolated tmux server for entrypoint and
effective-keymap assertions. The tmux test sets the internal
`LAZYTMUX_NO_WATCH=1` switch so its server lifecycle is deterministic; normal
initialization still starts the watcher. `mise.toml` will expose one test command, and a
GitHub Actions workflow will run both the existing hk checks and the new tests.

The following are explicitly out of scope:

- Plugin revision locking and reproducible plugin upgrades.
- A `theme <name>` selection command.
- Redesigning the plugin discovery rule that selects the first `*.tmux` file.
- Publishing changes to the separate `LazyTmux-starter` repository; the local
  `starter/` template will be updated and can be synchronized separately.
- Replacing shell command execution with a native process library, which would
  add a dependency and weaken the small Lua 5.1-compatible footprint.

## Implementation Phases

### Phase 1: Establish behavioral verification

- Add `tests/helpers.sh` with temporary-directory setup, command assertions,
  fixture creation helpers, and cleanup that never operates outside the test
  directory.
- Add `tests/cli.sh` to characterize current working behavior for `list`,
  `doctor`, theme generation, statusline generation, and wrapper interpreter
  selection using isolated `LAZYTMUX_CONFIG`, `LAZYTMUX_DATA`,
  `LAZYTMUX_PLUGIN_DIR`, and spec paths.
- Add `tests/tmux.sh` to start a tmux server under an isolated `TMUX_TMPDIR`,
  source `lazytmux.tmux`, assert generated files exist, inspect effective key
  bindings, and terminate the server even when an assertion fails.
- Add `tests/run.sh` as the single local test entrypoint and a `test` task to
  `mise.toml`.
- Add `.github/workflows/ci.yml` to install the repository's mise tools and
  tmux, run `mise exec -- hk check --all`, and run the new test task.
- Document the local test command in the Development section of `README.md`.

  **Commit:** `test: add CLI and tmux integration coverage`

### Phase 2: Enforce command and plugin safety

- Replace the current `run()` result assumptions in
  `lua/lazytmux/cli.lua` with one Lua-version-neutral status normalizer, a
  checked command helper for required operations, and a non-throwing helper for
  probes such as `is_dir()`, `process_alive()`, and `command_exists()`.
- Make `capture()` inspect `io.popen():close()` and provide separate checked and
  optional-capture behavior for commands where empty output or a nonzero status
  is expected.
- Propagate failures from directory creation, default-file copying, plugin
  clone/update/removal, plugin sourcing, popup launch, editor launch, generated
  file replacement, and watcher reload operations to a nonzero CLI exit.
- Validate every normalized plugin name in `load_specs()` as a nonempty safe
  basename, reject reserved path components and separators, reject duplicate
  names, and strip a trailing `.git` when deriving a name from a repository.
- Keep `plugin_path()` as the only plugin-directory constructor and add a final
  containment assertion before the destructive operation in `M.clean()`.
- Expand `normalize_url()` so URI-scheme and SCP-style full Git remotes pass
  through unchanged while only bare `owner/repo` values receive the GitHub
  prefix and `.git` suffix.
- Extend `tests/cli.sh` with fake `git` and `tmux` executables to assert nonzero
  exits for failed clone, pull, copy, delete, and source commands; assert that
  unsafe or duplicate plugin names are rejected before deletion; and cover
  GitHub shorthand, HTTPS, SSH URI, and SCP-style URL normalization through
  observed clone arguments.

  **Commit:** `fix(plugins): enforce safe paths and command failures`

### Phase 3: Persist UI toggles without rewriting Lua

- Add a plugin-override path under `LAZYTMUX_DATA` and parsing/serialization
  helpers in `lua/lazytmux/cli.lua` for a simple name-to-boolean text format.
- Preserve each plugin's declared `enabled` value during `load_specs()`, then
  apply a matching persisted override to produce its effective value.
- Replace the textual `toggle_plugin()` implementation with `M.toggle(name)`.
  It will require an exact known plugin name, invert the effective state, remove
  an override when the new state equals the declared state, and otherwise write
  the differing override.
- Register `toggle <name>` in the command table and usage output, validate that
  exactly one name argument was supplied, and make the fzf Enter action call
  the same function.
- Update `README.md` to explain that `plugins.lua` remains user-owned source and
  UI toggles are persisted as effective-state overrides under the data
  directory.
- Extend `tests/cli.sh` to cover toggling specs with single quotes, reordered
  fields, computed tables, omitted `enabled`, repeated toggles, unknown names,
  and a later user edit that returns an override to its declared value.

  **Commit:** `fix(ui): persist plugin toggles without rewriting specs`

### Phase 4: Make generated configuration atomic

- Add one atomic-write helper in `lua/lazytmux/cli.lua` that creates a unique
  temporary file beside the destination, writes complete pre-rendered content,
  closes it successfully, renames it over the destination, and removes only its
  own temporary file on failure.
- Refactor `M.theme()` to render all tmux commands before opening an output file
  and publish `theme.tmux` through the atomic-write helper.
- Refactor `M.statusline()` to validate and render all window, left, and right
  blocks before publishing `statusline.tmux` through the same helper.
- Use the atomic-write helper for the plugin override map introduced in Phase 3.
- Extend `tests/cli.sh` to seed last-known-good generated files, supply malformed
  theme/statusline/override inputs and simulated write failures, and assert that
  the prior destination is unchanged and no temporary files remain.

  **Commit:** `fix(config): publish generated files atomically`

### Phase 5: Make runtime requirements explicit

- Raise the documented minimum to tmux 3.5 in `README.md` because
  `config/options.tmux` intentionally uses `extended-keys-format`.
- Document Lua 5.1 or newer, or LuaJIT, as a required part of the LazyVim-style
  configuration model in `README.md` and `starter/README.md`.
- Restructure `lazytmux.tmux` so initialization and generated-file sourcing run
  only when `lua` or `luajit` is available; otherwise display one actionable
  installation message and avoid secondary missing-file errors.
- Add the same Lua preflight to `starter/.tmux.conf` so a fresh starter clone
  fails before sourcing LazyTmux and identifies the missing prerequisite.
- Have `M.doctor()` report the active Lua implementation/version alongside
  tmux, git, and optional fzf results.
- Extend `tests/tmux.sh` with controlled `PATH` cases for available and missing
  Lua runtimes, and assert that the failure message is singular and that no
  generated files are sourced in the missing-runtime case.

  **Commit:** `fix(bootstrap): enforce supported tmux and Lua runtimes`

### Phase 6: Correct reload and key bindings

- Change the `prefix + R` binding in `config/keymaps.tmux` to source
  `#{E:LAZYTMUX_ROOT}/lazytmux.tmux`, report success only after a zero exit, and
  report a concise failure otherwise.
- Remove the unshipped `worktree-session-picker.sh` binding so the later
  documented `prefix + L` resize binding has no hidden predecessor.
- Extend `tests/tmux.sh` to verify the effective `P`, `I`, `R`, and `L`
  bindings, exercise reload with a starter-style home that has no
  `~/.tmux.conf`, and confirm a forced source failure does not display the
  success message.
- Reconcile the Keymaps, Requirements, Plugin Spec, Commands, and Development
  sections of `README.md` with the final behavior and update
  `starter/README.md` with the same runtime contract.
- Run the complete lint, CLI, and isolated-tmux suite on Lua 5.1 and LuaJIT
  before committing.

  **Commit:** `fix(keymaps): make reload and resize bindings reliable`

## Risks & Tradeoffs

- Lua 5.1 and newer Lua releases expose different process-status APIs. The
  status-normalization tests must execute both the mise-managed Lua 5.1 runtime
  and LuaJIT when available; CI must guarantee Lua 5.1 coverage.
- Restricting plugin names may reject an existing configuration that uses
  nested directories or whitespace. That behavior is intentionally unsupported
  because it conflicts with a safe destructive boundary; the validation error
  must identify the offending plugin and accepted format.
- Persisted UI overrides add state outside `plugins.lua`. Storing only deviations
  and removing redundant overrides limits surprise, while the README must state
  precedence clearly.
- A checked command helper may expose failures that were previously silent,
  especially optional probes. The implementation must classify each call site
  deliberately rather than mechanically making every nonzero result fatal.
- Atomic rename is reliable only when the temporary file is created beside the
  destination. The helper must not use a system temporary directory that may be
  on another filesystem.
- Raising the tmux floor to 3.5 drops the currently advertised 3.2–3.4 support.
  Keeping `extended-keys-format` and a clear version contract is preferable to
  silently loading a partially valid configuration.
- tmux configuration conditionals and command blocks are smoke-tested against
  the installed local tmux (currently 3.7b). The documented 3.5 minimum remains
  a compatibility contract, but this plan does not download or build another
  tmux version solely for verification.
- The CI workflow introduces network-dependent tool installation. Local
  `tests/run.sh` must remain usable with already-installed Lua, git, and tmux.

## Open Questions

- None blocking. Lua is intentionally required, the tmux minimum will be raised
  to 3.5, and the two roadmap suggestions from the audit remain out of scope.
