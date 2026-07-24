local M = {}

local unpack = rawget(table, "unpack") or rawget(_G, "unpack")
local root = os.getenv("LAZYTMUX_ROOT") or debug.getinfo(1, "S").source:sub(2):match("^(.*)/lua/lazytmux/cli%.lua$")
local home = os.getenv("HOME") or ""
local config_dir = os.getenv("LAZYTMUX_CONFIG") or (home .. "/.config/lazytmux")
local data_dir = os.getenv("LAZYTMUX_DATA") or (home .. "/.local/share/lazytmux")
local spec_file = os.getenv("LAZYTMUX_SPEC") or (config_dir .. "/plugins.lua")
local theme_file = os.getenv("LAZYTMUX_THEME") or (config_dir .. "/theme.lua")
local statusline_file = os.getenv("LAZYTMUX_STATUSLINE") or (config_dir .. "/statusline.lua")
local plugin_dir = os.getenv("LAZYTMUX_PLUGIN_DIR") or (data_dir .. "/plugins")
local override_file = data_dir .. "/plugin-overrides"

local function q(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- Lua 5.1/LuaJIT return a numeric status from os.execute, while newer Lua
-- versions return (true|nil, "exit", code). io.popen():close has the same
-- variation, so every external command goes through this one normalizer.
local function command_succeeded(first, kind, code)
  if first == true then
    return true
  end
  if type(first) == "number" then
    return first == 0
  end
  return first == nil and kind == "exit" and code == 0
end

local function run(...)
  return command_succeeded(os.execute(table.concat({ ... }, " ")))
end

local function run_checked(label, ...)
  if not run(...) then
    error(label .. " failed")
  end
end

local function capture_optional(command)
  local handle, err = io.popen(command)
  if not handle then
    return "", false, err
  end
  local output = handle:read("*a") or ""
  local ok = command_succeeded(handle:close())
  return output:gsub("%s+$", ""), ok
end

local function capture_checked(label, command)
  local output, ok, err = capture_optional(command)
  if not ok then
    error(label .. " failed" .. (err and ": " .. err or ""))
  end
  return output
end

local function exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

local function is_dir(path)
  return run("test -d", q(path))
end

local function mkdir(path)
  run_checked("creating directory " .. path, "mkdir -p", q(path))
end

local function process_alive(pid)
  return run("kill -0", q(pid), "2>/dev/null")
end

local function command_exists(name)
  return run("command -v", q(name), ">/dev/null 2>&1")
end

local function ensure_user_files()
  mkdir(config_dir)
  mkdir(plugin_dir)
  if not exists(spec_file) then
    run_checked("copying default plugin spec", "cp", q(root .. "/plugins/default.lua"), q(spec_file))
  end
  if not exists(theme_file) then
    run_checked("copying default theme", "cp", q(root .. "/themes/default.lua"), q(theme_file))
  end
  if not exists(statusline_file) then
    run_checked("copying default statusline", "cp", q(root .. "/statusline/default.lua"), q(statusline_file))
  end
end

local function valid_plugin_name(name)
  return type(name) == "string" and name:match("^[A-Za-z0-9][A-Za-z0-9._-]*$") ~= nil and name ~= "." and name ~= ".."
end

local function derive_name(repo)
  local name = repo:match("([^/:]+)$")
  if name then
    name = name:gsub("%.git$", "")
  end
  return name
end

local function normalize_url(repo)
  if repo:match("^[%a][%w+.-]*://") or repo:match("^[^/@:%s]+@[^:%s]+:.+") then
    return repo
  end
  return "https://github.com/" .. repo .. ".git"
end

local function plugin_path(plugin)
  return plugin_dir .. "/" .. plugin.name
end

local function assert_plugin_path(plugin)
  if not valid_plugin_name(plugin.name) then
    error("unsafe plugin name: " .. tostring(plugin.name))
  end
  local path = plugin_path(plugin)
  local prefix = plugin_dir .. "/"
  if path:sub(1, #prefix) ~= prefix or path:sub(#prefix + 1) ~= plugin.name then
    error("plugin path escapes plugin directory: " .. tostring(plugin.name))
  end
  return path
end

local function atomic_write(path, content)
  local directory = path:match("^(.*)/[^/]+$")
  if not directory then
    error("output path must have a parent directory: " .. path)
  end
  mkdir(directory)

  local pid = capture_optional("sh -c 'echo $PPID'")
  local temporary = path .. ".tmp." .. (pid ~= "" and pid or "0") .. "." .. tostring(math.random(1, 2147483646))
  local file, err = io.open(temporary, "wx")
  if not file then
    -- Lua 5.1 may not support x mode; the unique name still makes this safe.
    file, err = io.open(temporary, "w")
  end
  if not file then
    error("opening temporary output for " .. path .. " failed: " .. tostring(err))
  end

  local ok, write_err = file:write(content)
  if not ok then
    file:close()
    os.remove(temporary)
    error("writing temporary output for " .. path .. " failed: " .. tostring(write_err))
  end
  local closed, close_err = file:close()
  if not closed then
    os.remove(temporary)
    error("closing temporary output for " .. path .. " failed: " .. tostring(close_err))
  end
  local renamed, rename_err = os.rename(temporary, path)
  if not renamed then
    os.remove(temporary)
    error("publishing " .. path .. " failed: " .. tostring(rename_err))
  end
end

local function load_overrides()
  if not exists(override_file) then
    return {}
  end
  local file, err = io.open(override_file, "r")
  if not file then
    error("reading plugin overrides failed: " .. tostring(err))
  end
  local overrides = {}
  local line_number = 0
  for line in file:lines() do
    line_number = line_number + 1
    local name, value = line:match("^([A-Za-z0-9][A-Za-z0-9._-]*)\t(true)$")
    if not name then
      name, value = line:match("^([A-Za-z0-9][A-Za-z0-9._-]*)\t(false)$")
    end
    if not name then
      file:close()
      error("invalid plugin override at line " .. line_number)
    end
    if overrides[name] ~= nil then
      file:close()
      error("duplicate plugin override: " .. name)
    end
    overrides[name] = value == "true"
  end
  file:close()
  return overrides
end

local function save_overrides(overrides)
  local names = {}
  for name in pairs(overrides) do
    names[#names + 1] = name
  end
  table.sort(names)
  local lines = {}
  for _, name in ipairs(names) do
    if not valid_plugin_name(name) or type(overrides[name]) ~= "boolean" then
      error("invalid plugin override: " .. tostring(name))
    end
    lines[#lines + 1] = name .. "\t" .. tostring(overrides[name])
  end
  atomic_write(override_file, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function load_specs()
  ensure_user_files()
  local chunk, err = loadfile(spec_file)
  if not chunk then
    error(err)
  end
  local ok, specs = pcall(chunk)
  if not ok then
    error(specs)
  end
  if type(specs) ~= "table" then
    error(spec_file .. " must return a plugin table")
  end

  local names = {}
  for index, plugin in ipairs(specs) do
    if type(plugin) ~= "table" then
      error("plugin #" .. index .. " must be a table")
    end
    plugin.repo = plugin[1] or plugin.repo
    if type(plugin.repo) ~= "string" or plugin.repo == "" then
      error("plugin #" .. index .. " needs a repo")
    end
    plugin.name = plugin.name or derive_name(plugin.repo)
    if not valid_plugin_name(plugin.name) then
      error(
        "plugin #" .. index .. " has unsafe name " .. tostring(plugin.name) .. "; use a single safe directory basename"
      )
    end
    if names[plugin.name] then
      error("duplicate plugin name: " .. plugin.name)
    end
    names[plugin.name] = true
    if plugin.enabled == nil then
      plugin.enabled = true
    elseif type(plugin.enabled) ~= "boolean" then
      error("plugin " .. plugin.name .. " enabled must be boolean")
    end
    plugin.declared_enabled = plugin.enabled
    plugin.desc = plugin.desc or ""
    if type(plugin.desc) ~= "string" then
      error("plugin " .. plugin.name .. " desc must be a string")
    end
  end

  local overrides = load_overrides()
  for name in pairs(overrides) do
    if not names[name] then
      error("plugin override references unknown plugin: " .. name)
    end
  end
  for _, plugin in ipairs(specs) do
    if overrides[plugin.name] ~= nil then
      plugin.enabled = overrides[plugin.name]
    end
  end
  return specs, overrides
end

local function installed(plugin)
  return is_dir(assert_plugin_path(plugin) .. "/.git")
end

local function status(plugin)
  return installed(plugin) and "installed" or "missing"
end

local function usage()
  print([[Usage: lazytmux <command>

Commands:
  list                  Show plugin status
  sync                  Install missing enabled plugins and update installed ones
  install               Install missing enabled plugins
  update                Update installed enabled plugins
  clean                 Remove disabled plugins from the plugin directory
  source                Source installed tmux plugins
  toggle <name>         Toggle a plugin without editing plugins.lua
  ui                    Open the plugin viewer in the current terminal
  popup                 Open the plugin viewer in a tmux popup
  theme [name]          Generate styles or apply a bundled theme
  themes                List bundled themes
  theme-picker          Choose and apply a bundled theme
  theme-popup           Open the theme picker in a tmux popup
  statusline            Generate the tmux statusline from statusline.lua
  watch                 Auto-reload LazyTmux when config files change
  doctor                Check local requirements]])
end

function M.list()
  local specs = load_specs()
  print(string.format("%-12s  %-24s  %-7s  %s", "STATUS", "PLUGIN", "ENABLED", "DESCRIPTION"))
  for _, plugin in ipairs(specs) do
    print(
      string.format(
        "%-12s  %-24s  %-7s  %s",
        status(plugin),
        plugin.name,
        plugin.enabled and "yes" or "no",
        plugin.desc
      )
    )
  end
end

function M.install()
  for _, plugin in ipairs(load_specs()) do
    if plugin.enabled then
      local path = assert_plugin_path(plugin)
      if installed(plugin) then
        print("ok      " .. plugin.name .. " already installed")
      else
        print("install " .. plugin.name)
        run_checked("cloning plugin " .. plugin.name, "git clone --depth 1", q(normalize_url(plugin.repo)), q(path))
      end
    end
  end
end

function M.update()
  for _, plugin in ipairs(load_specs()) do
    if plugin.enabled then
      local path = assert_plugin_path(plugin)
      if installed(plugin) then
        print("update  " .. plugin.name)
        run_checked("updating plugin " .. plugin.name, "git -C", q(path), "pull --ff-only")
      else
        print("skip    " .. plugin.name .. " is not installed")
      end
    end
  end
end

function M.sync()
  M.install()
  M.update()
end

function M.clean()
  for _, plugin in ipairs(load_specs()) do
    if not plugin.enabled then
      local path = assert_plugin_path(plugin)
      if is_dir(path) then
        print("remove  " .. plugin.name)
        run_checked("removing plugin " .. plugin.name, "rm -rf", q(path))
      end
    end
  end
end

function M.source()
  if not os.getenv("TMUX") then
    return
  end
  for _, plugin in ipairs(load_specs()) do
    if plugin.enabled and is_dir(assert_plugin_path(plugin)) then
      local entry = capture_checked(
        "finding tmux entrypoint for " .. plugin.name,
        "find " .. q(assert_plugin_path(plugin)) .. " -maxdepth 2 -type f -name '*.tmux' | sort | head -n 1"
      )
      if entry ~= "" then
        run_checked("sourcing plugin " .. plugin.name, "tmux source-file", q(entry))
      end
    end
  end
end

function M.toggle(name)
  if not valid_plugin_name(name) then
    error("toggle requires one known plugin name")
  end
  local specs, overrides = load_specs()
  local selected
  for _, plugin in ipairs(specs) do
    if plugin.name == name then
      selected = plugin
      break
    end
  end
  if not selected then
    error("unknown plugin: " .. name)
  end
  local next_enabled = not selected.enabled
  if next_enabled == selected.declared_enabled then
    overrides[name] = nil
  else
    overrides[name] = next_enabled
  end
  save_overrides(overrides)
  print(string.format("%s %s", next_enabled and "enabled" or "disabled", name))
end

function M.doctor()
  local failed = false
  for _, command in ipairs({ "tmux", "git" }) do
    if command_exists(command) then
      print("ok      " .. command)
    else
      print("missing " .. command)
      failed = true
    end
  end
  local lua = command_exists("luajit") and "luajit" or (command_exists("lua") and "lua" or nil)
  if lua then
    local version = capture_checked("checking " .. lua .. " version", lua .. " -v 2>&1")
    print("ok      " .. lua .. " " .. version)
  else
    print("missing lua or luajit")
    failed = true
  end
  if command_exists("fzf") then
    print("ok      fzf")
  else
    print("optional fzf, needed for the richer plugin viewer")
  end
  if failed then
    error("required dependencies are missing")
  end
end

local function render_rows()
  local rows = {}
  for _, plugin in ipairs(load_specs()) do
    rows[#rows + 1] =
      string.format("%-11s %-7s %-24s %s", status(plugin), plugin.enabled and "yes" or "no", plugin.name, plugin.desc)
  end
  return rows
end

local function fzf_ui()
  while true do
    local list_file = os.tmpname()
    atomic_write(list_file, table.concat(render_rows(), "\n") .. "\n")
    local preview = table.concat({
      "name=$(awk '{print $3}' <<< {});",
      "path=" .. q(plugin_dir) .. "/$name;",
      'if [ -d "$path/.git" ]; then',
      'git -C "$path" log -1 --oneline;',
      'printf "\\n";',
      'git -C "$path" remote -v;',
      "else",
      'printf "Not installed\\n";',
      "fi",
    }, " ")
    local output = capture_optional(table.concat({
      "fzf",
      "--ansi",
      "--height=100%",
      "--border=rounded",
      "--layout=reverse",
      "--prompt='LazyTmux plugins > '",
      "--header="
        .. q("enter: toggle  ctrl-i: install  ctrl-u: update  ctrl-s: sync  ctrl-r: source  ctrl-e: edit  esc: quit"),
      "--expect=enter,ctrl-i,ctrl-u,ctrl-s,ctrl-r,ctrl-e",
      "--preview=" .. q(preview),
      "--preview-window=down,35%,wrap",
      "< " .. q(list_file),
    }, " "))
    os.remove(list_file)
    if output == "" then
      return
    end
    local lines = {}
    for line in output:gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end
    local key, selected = lines[1], lines[2] or ""
    local name = selected:match("^%S+%s+%S+%s+(%S+)")
    if key == "enter" and name then
      M.toggle(name)
    elseif key == "ctrl-i" then
      M.install()
    elseif key == "ctrl-u" then
      M.update()
    elseif key == "ctrl-s" then
      M.sync()
      M.source()
    elseif key == "ctrl-r" then
      M.source()
    elseif key == "ctrl-e" then
      run_checked("launching editor", q(os.getenv("EDITOR") or "vi"), q(spec_file))
    else
      return
    end
  end
end

local function plain_ui()
  while true do
    run_checked("clearing terminal", "clear")
    print("LazyTmux plugins\n")
    M.list()
    io.write("\n[i] install  [u] update  [s] sync  [r] source  [e] edit  [q] quit\n> ")
    local choice = io.read("*l")
    if choice == "i" then
      M.install()
    elseif choice == "u" then
      M.update()
    elseif choice == "s" then
      M.sync()
      M.source()
    elseif choice == "r" then
      M.source()
    elseif choice == "e" then
      run_checked("launching editor", q(os.getenv("EDITOR") or "vi"), q(spec_file))
    elseif choice == "q" then
      return
    end
    io.write("\nPress enter to continue...")
    io.read("*l")
  end
end

function M.ui()
  if command_exists("fzf") then
    fzf_ui()
  else
    plain_ui()
  end
end

function M.popup()
  if not os.getenv("TMUX") then
    return M.ui()
  end
  run_checked(
    "opening tmux popup",
    "tmux display-popup -E -w 86% -h 82% -T",
    q(" LazyTmux "),
    q(root .. "/bin/lazytmux ui")
  )
end

local function load_lua_table(path, label)
  local chunk, err = loadfile(path)
  if not chunk then
    error(err)
  end
  local ok, spec = pcall(chunk)
  if not ok then
    error(spec)
  end
  if type(spec) ~= "table" then
    error(path .. " must return a " .. label .. " table")
  end
  return spec
end

local function load_theme()
  ensure_user_files()
  local theme = load_lua_table(theme_file, "theme")
  theme.colors, theme.styles = theme.colors or {}, theme.styles or {}
  if type(theme.colors) ~= "table" or type(theme.styles) ~= "table" then
    error("theme colors and styles must be tables")
  end
  return theme
end

local function optional_string(value, label)
  if value ~= nil and type(value) ~= "string" then
    error(label .. " must be a string")
  end
  return value
end

function M.theme(name)
  if name then
    return M.apply_theme(name)
  end
  local theme = load_theme()
  local styles, lines = theme.styles, { "# Generated from " .. theme_file }
  local settings = {
    { "status", "set-option -g status-style " },
    { "pane_border", "set-option -g pane-border-style " },
    { "pane_active_border", "set-option -g pane-active-border-style " },
    { "display_panes", "set-option -g display-panes-colour " },
    { "display_panes_active", "set-option -g display-panes-active-colour " },
    { "clock", "set-window-option -g clock-mode-colour " },
    { "message", "set-option -g message-style " },
    { "message_command", "set-option -g message-command-style " },
    { "mode", "set-option -g mode-style " },
  }
  for _, setting in ipairs(settings) do
    local value = optional_string(styles[setting[1]], "theme style " .. setting[1])
    if value then
      lines[#lines + 1] = setting[2] .. q(value)
    end
  end
  atomic_write(data_dir .. "/theme.tmux", table.concat(lines, "\n") .. "\n")
end

function M.themes()
  print("Bundled themes:")
  local output = capture_checked(
    "listing bundled themes",
    "find " .. q(root .. "/themes") .. " -maxdepth 1 -type f -name '*.lua' | sort"
  )
  for file in output:gmatch("[^\n]+") do
    local name = file:match("([^/]+)%.lua$")
    print("  " .. name)
  end
  print("\nApply one with: lazytmux theme <name>")
end

local function bundled_theme_path(name)
  if type(name) ~= "string" or not name:match("^[A-Za-z0-9][A-Za-z0-9._-]*$") then
    error("theme name must be a safe bundled theme name")
  end
  local path = root .. "/themes/" .. name .. ".lua"
  if not exists(path) then
    error("unknown bundled theme: " .. name)
  end
  return path
end

local function bundled_theme_names()
  local output = capture_checked(
    "listing bundled themes",
    "find " .. q(root .. "/themes") .. " -maxdepth 1 -type f -name '*.lua' | sort"
  )
  local names = {}
  for file in output:gmatch("[^\n]+") do
    names[#names + 1] = file:match("([^/]+)%.lua$")
  end
  return names
end

local function read_file(path)
  local file, err = io.open(path, "r")
  if not file then
    error("reading bundled theme failed: " .. tostring(err))
  end
  local content = file:read("*a")
  file:close()
  return content
end

function M.apply_theme(name)
  local source = bundled_theme_path(name)
  atomic_write(theme_file, read_file(source))
  M.theme()
  M.statusline()
  if os.getenv("TMUX") then
    run_checked("applying theme", "tmux source-file", q(data_dir .. "/theme.tmux"))
    run_checked("applying statusline", "tmux source-file", q(data_dir .. "/statusline.tmux"))
  end
  print("applied theme " .. name)
end

function M.theme_picker()
  local names = bundled_theme_names()
  if command_exists("fzf") then
    local list_file = os.tmpname()
    atomic_write(list_file, table.concat(names, "\n") .. "\n")
    local output = capture_optional(table.concat({
      "fzf",
      "--height=100%",
      "--border=rounded",
      "--layout=reverse",
      "--prompt='LazyTmux themes > '",
      "--header=" .. q("enter: apply theme  esc: cancel"),
      "--preview=" .. q("sed -n '1,160p' " .. root .. "/themes/{}.lua"),
      "--preview-window=right,60%,wrap",
      "< " .. q(list_file),
    }, " "))
    os.remove(list_file)
    if output ~= "" then
      M.apply_theme(output:match("^[^\n]+"))
    end
    return
  end

  print("LazyTmux themes\n")
  for index, name in ipairs(names) do
    print(string.format("  %d. %s", index, name))
  end
  io.write("\nChoose a theme number, or q to cancel: ")
  local choice = io.read("*l") or "q"
  if choice == "q" then
    return
  end
  local index = tonumber(choice)
  if not index or index % 1 ~= 0 or not names[index] then
    error("theme selection must be one of the listed numbers")
  end
  M.apply_theme(names[index])
end

function M.theme_popup()
  if not os.getenv("TMUX") then
    return M.theme_picker()
  end
  run_checked(
    "opening theme picker",
    "tmux display-popup -E -w 70% -h 70% -T",
    q(" LazyTmux themes "),
    q(root .. "/bin/lazytmux theme-picker")
  )
end

local function load_statusline()
  _G.LazyTmuxTheme = load_theme()
  return load_lua_table(statusline_file, "statusline")
end

local function style(block)
  if type(block) ~= "table" then
    error("statusline block must be a table")
  end
  local fg, bg = optional_string(block.fg, "statusline block fg"), optional_string(block.bg, "statusline block bg")
  if not fg or not bg then
    error("statusline block missing fg or bg")
  end
  local attr, text =
    optional_string(block.attr, "statusline block attr"), optional_string(block.text, "statusline block text")
  local attrs = { "fg=" .. fg, "bg=" .. bg }
  if attr and attr ~= "" then
    attrs[#attrs + 1] = attr
  end
  return "#[" .. table.concat(attrs, ",") .. "]" .. (text or "")
end

local function render_blocks(blocks)
  if blocks == nil then
    return ""
  end
  if type(blocks) ~= "table" then
    error("statusline blocks must be a table")
  end
  local output = {}
  for _, block in ipairs(blocks) do
    output[#output + 1] = style(block)
  end
  return table.concat(output, "")
end

function M.statusline()
  local spec, lines = load_statusline(), {}
  if spec.window ~= nil and type(spec.window) ~= "table" then
    error("statusline window must be a table")
  end
  if spec.window and spec.window.normal then
    lines[#lines + 1] = "set-window-option -g window-status-format " .. q(style(spec.window.normal))
  end
  if spec.window and spec.window.current then
    lines[#lines + 1] = "set-window-option -g window-status-current-format " .. q(style(spec.window.current))
  end
  lines[#lines + 1] = "set-option -g status-left " .. q(render_blocks(spec.left))
  lines[#lines + 1] = "set-option -g status-right " .. q(render_blocks(spec.right))
  atomic_write(data_dir .. "/statusline.tmux", table.concat(lines, "\n") .. "\n")
end

local function mtime(path)
  if not exists(path) then
    return "-"
  end
  local mac, mac_ok = capture_optional("stat -f %m " .. q(path) .. " 2>/dev/null")
  if mac_ok and mac ~= "" then
    return mac
  end
  local linux, linux_ok = capture_optional("stat -c %Y " .. q(path) .. " 2>/dev/null")
  if linux_ok and linux ~= "" then
    return linux
  end
  return "-"
end

local function watch_signature()
  local paths = {
    root .. "/lazytmux.tmux",
    root .. "/config/options.tmux",
    root .. "/config/keymaps.tmux",
    root .. "/lua/lazytmux/cli.lua",
    spec_file,
    theme_file,
    statusline_file,
  }
  local parts = {}
  for _, path in ipairs(paths) do
    parts[#parts + 1] = path .. "=" .. mtime(path)
  end
  return table.concat(parts, "\n")
end

function M.watch(server_pid)
  ensure_user_files()
  mkdir(data_dir)
  local lock = data_dir .. "/watch.pid"
  if exists(lock) then
    local file = io.open(lock, "r")
    local pid = file and file:read("*l")
    if file then
      file:close()
    end
    if pid and pid ~= "" and process_alive(pid) then
      return
    end
  end
  atomic_write(lock, capture_checked("finding watcher process", "sh -c 'echo $PPID'") .. "\n")
  local last = watch_signature()
  while true do
    run_checked("waiting for configuration change", "sleep 1")
    if server_pid and server_pid ~= "" and not process_alive(server_pid) then
      os.remove(lock)
      return
    end
    local current = watch_signature()
    if current ~= last then
      last = current
      M.theme()
      M.statusline()
      run_checked("reloading LazyTmux", "tmux source-file", q(root .. "/lazytmux.tmux"))
      run_checked("displaying reload message", "tmux display-message", q("LazyTmux auto-reloaded"))
    end
  end
end

local commands = {
  list = M.list,
  sync = M.sync,
  install = M.install,
  update = M.update,
  clean = M.clean,
  source = M.source,
  toggle = M.toggle,
  ui = M.ui,
  popup = M.popup,
  theme = M.theme,
  themes = M.themes,
  ["theme-picker"] = M.theme_picker,
  ["theme-popup"] = M.theme_popup,
  statusline = M.statusline,
  watch = M.watch,
  doctor = M.doctor,
}
local command = arg[1]
if not command or command == "-h" or command == "--help" or command == "help" then
  usage()
  os.exit(0)
end
if not commands[command] then
  io.stderr:write("Unknown command: " .. command .. "\n\n")
  usage()
  os.exit(2)
end
if command == "toggle" and (not arg[2] or arg[3]) then
  error("toggle requires exactly one plugin name")
end
if command == "theme" and arg[3] then
  error("theme accepts at most one bundled theme name")
end
if (command == "theme-picker" or command == "theme-popup") and arg[2] then
  error(command .. " does not accept arguments")
end
commands[command](unpack(arg, 2))
