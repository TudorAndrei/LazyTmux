local M = {}

local unpack = rawget(table, "unpack") or rawget(_G, "unpack")

local root = os.getenv("LAZYTMUX_ROOT")
  or debug.getinfo(1, "S").source:sub(2):match("^(.*)/lua/lazytmux/cli%.lua$")
local home = os.getenv("HOME")
local config_dir = os.getenv("LAZYTMUX_CONFIG") or (home .. "/.config/lazytmux")
local data_dir = os.getenv("LAZYTMUX_DATA") or (home .. "/.local/share/lazytmux")
local spec_file = os.getenv("LAZYTMUX_SPEC") or (config_dir .. "/plugins.lua")
local theme_file = os.getenv("LAZYTMUX_THEME") or (config_dir .. "/theme.lua")
local statusline_file = os.getenv("LAZYTMUX_STATUSLINE") or (config_dir .. "/statusline.lua")
local plugin_dir = os.getenv("LAZYTMUX_PLUGIN_DIR") or (data_dir .. "/plugins")

local function q(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function run(...)
  local parts = { ... }
  local cmd = table.concat(parts, " ")
  return os.execute(cmd)
end

local function capture(cmd)
  local handle = io.popen(cmd)
  if not handle then
    return ""
  end
  local out = handle:read("*a") or ""
  handle:close()
  return out:gsub("%s+$", "")
end

local function exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function is_dir(path)
  return run("test -d", q(path)) == true or run("test -d", q(path)) == 0
end

local function mkdir(path)
  run("mkdir -p", q(path))
end

local function process_alive(pid)
  return run("kill -0", q(pid), "2>/dev/null") == true
    or run("kill -0", q(pid), "2>/dev/null") == 0
end

local function copy_default_spec()
  mkdir(config_dir)
  mkdir(plugin_dir)
  if not exists(spec_file) then
    run("cp", q(root .. "/plugins/default.lua"), q(spec_file))
  end
  if not exists(theme_file) then
    run("cp", q(root .. "/themes/default.lua"), q(theme_file))
  end
  if not exists(statusline_file) then
    run("cp", q(root .. "/statusline/default.lua"), q(statusline_file))
  end
end

local function usage()
  print([[
Usage: lazytmux <command>

Commands:
  list      Show plugin status
  sync      Install missing enabled plugins and update installed ones
  install   Install missing enabled plugins
  update    Update installed enabled plugins
  clean     Remove disabled plugins from the plugin directory
  source    Source installed tmux plugins
  ui        Open the plugin viewer in the current terminal
  popup     Open the plugin viewer in a tmux popup
  theme     Generate tmux theme styles from theme.lua
  themes    List bundled themes
  statusline
            Generate the tmux statusline from statusline.lua
  watch     Auto-reload LazyTmux when config files change
  doctor    Check local requirements
]])
end

local function normalize_url(repo)
  if repo:match("^https?://") or repo:match("^git@") then
    return repo
  end
  return "https://github.com/" .. repo .. ".git"
end

local function plugin_path(plugin)
  return plugin_dir .. "/" .. plugin.name
end

local function load_specs()
  copy_default_spec()

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

  for i, plugin in ipairs(specs) do
    if type(plugin) ~= "table" then
      error("plugin #" .. i .. " must be a table")
    end
    plugin.repo = plugin[1] or plugin.repo
    plugin.name = plugin.name or (plugin.repo and plugin.repo:match("/([^/]+)$"))
    plugin.desc = plugin.desc or ""
    if plugin.enabled == nil then
      plugin.enabled = true
    end
    if not plugin.repo or not plugin.name then
      error("plugin #" .. i .. " needs a repo and name")
    end
  end

  return specs
end

local function installed(plugin)
  return is_dir(plugin_path(plugin) .. "/.git")
end

local function status(plugin)
  if installed(plugin) then
    return "installed"
  end
  return "missing"
end

function M.list()
  local specs = load_specs()
  print(string.format("%-12s  %-24s  %-7s  %s", "STATUS", "PLUGIN", "ENABLED", "DESCRIPTION"))
  for _, plugin in ipairs(specs) do
    print(string.format(
      "%-12s  %-24s  %-7s  %s",
      status(plugin),
      plugin.name,
      plugin.enabled and "yes" or "no",
      plugin.desc
    ))
  end
end

function M.install()
  for _, plugin in ipairs(load_specs()) do
    if plugin.enabled then
      local path = plugin_path(plugin)
      if installed(plugin) then
        print("ok      " .. plugin.name .. " already installed")
      else
        print("install " .. plugin.name)
        run("git clone --depth 1", q(normalize_url(plugin.repo)), q(path))
      end
    end
  end
end

function M.update()
  for _, plugin in ipairs(load_specs()) do
    if plugin.enabled then
      local path = plugin_path(plugin)
      if installed(plugin) then
        print("update  " .. plugin.name)
        run("git -C", q(path), "pull --ff-only")
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
      local path = plugin_path(plugin)
      if is_dir(path) then
        print("remove  " .. plugin.name)
        run("rm -rf", q(path))
      end
    end
  end
end

function M.source()
  if not os.getenv("TMUX") then
    return
  end

  for _, plugin in ipairs(load_specs()) do
    if plugin.enabled and is_dir(plugin_path(plugin)) then
      local entry = capture(
        "find " .. q(plugin_path(plugin)) .. " -maxdepth 2 -type f -name '*.tmux' | sort | head -n 1"
      )
      if entry ~= "" then
        run("tmux source-file", q(entry))
      end
    end
  end
end

local function command_exists(name)
  return run("command -v", q(name), ">/dev/null 2>&1") == true
    or run("command -v", q(name), ">/dev/null 2>&1") == 0
end

function M.doctor()
  local failed = false
  for _, cmd in ipairs({ "tmux", "git" }) do
    if command_exists(cmd) then
      print("ok      " .. cmd)
    else
      print("missing " .. cmd)
      failed = true
    end
  end

  if command_exists("fzf") then
    print("ok      fzf")
  else
    print("optional fzf, needed for the richer plugin viewer")
  end

  if failed then
    os.exit(1)
  end
end

local function render_rows()
  local rows = {}
  for _, plugin in ipairs(load_specs()) do
    rows[#rows + 1] = string.format(
      "%-11s %-7s %-24s %s",
      status(plugin),
      plugin.enabled and "yes" or "no",
      plugin.name,
      plugin.desc
    )
  end
  return rows
end

local function toggle_plugin(name)
  local f = assert(io.open(spec_file, "r"))
  local lines = {}
  local in_target = false
  for line in f:lines() do
    if line:find('name%s*=%s*"' .. name:gsub("%-", "%%-") .. '"') then
      in_target = true
    end
    if in_target and line:find("enabled%s*=") then
      if line:find("enabled%s*=%s*true") then
        line = line:gsub("enabled%s*=%s*true", "enabled = false")
      elseif line:find("enabled%s*=%s*false") then
        line = line:gsub("enabled%s*=%s*false", "enabled = true")
      end
      in_target = false
    end
    if in_target and line:find("^%s*},?%s*$") then
      in_target = false
    end
    lines[#lines + 1] = line
  end
  f:close()

  f = assert(io.open(spec_file, "w"))
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()
end

local function fzf_ui()
  while true do
    local list_file = os.tmpname()
    local f = assert(io.open(list_file, "w"))
    f:write(table.concat(render_rows(), "\n"))
    f:write("\n")
    f:close()

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
    local fzf_cmd = table.concat({
      "fzf",
      "--ansi",
      "--height=100%",
      "--border=rounded",
      "--layout=reverse",
      "--prompt='LazyTmux plugins > '",
      "--header=" .. q(
        "enter: toggle  ctrl-i: install  ctrl-u: update  ctrl-s: sync  ctrl-r: source  ctrl-e: edit  esc: quit"
      ),
      "--expect=enter,ctrl-i,ctrl-u,ctrl-s,ctrl-r,ctrl-e",
      "--preview=" .. q(preview),
      "--preview-window=down,35%,wrap",
      "< " .. q(list_file),
    }, " ")

    local output = capture(fzf_cmd)
    os.remove(list_file)
    if output == "" then
      return
    end

    local lines = {}
    for line in output:gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end
    local key = lines[1]
    local selected = lines[2] or ""
    local name = selected:match("^%S+%s+%S+%s+(%S+)")

    if key == "enter" and name then
      toggle_plugin(name)
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
      run(q(os.getenv("EDITOR") or "vi"), q(spec_file))
    else
      return
    end
  end
end

local function plain_ui()
  while true do
    run("clear")
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
      run(q(os.getenv("EDITOR") or "vi"), q(spec_file))
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
    M.ui()
    return
  end
  run("tmux display-popup -E -w 86% -h 82% -T", q(" LazyTmux "), q(root .. "/bin/lazytmux ui"))
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
  copy_default_spec()
  local theme = load_lua_table(theme_file, "theme")
  theme.colors = theme.colors or {}
  theme.styles = theme.styles or {}
  return theme
end

function M.theme()
  local theme = load_theme()
  local styles = theme.styles
  mkdir(data_dir)

  local output = data_dir .. "/theme.tmux"
  local f = assert(io.open(output, "w"))
  f:write("# Generated from ", theme_file, "\n")

  if styles.status then
    f:write("set-option -g status-style ", q(styles.status), "\n")
  end
  if styles.pane_border then
    f:write("set-option -g pane-border-style ", q(styles.pane_border), "\n")
  end
  if styles.pane_active_border then
    f:write("set-option -g pane-active-border-style ", q(styles.pane_active_border), "\n")
  end
  if styles.display_panes then
    f:write("set-option -g display-panes-colour ", q(styles.display_panes), "\n")
  end
  if styles.display_panes_active then
    f:write("set-option -g display-panes-active-colour ", q(styles.display_panes_active), "\n")
  end
  if styles.clock then
    f:write("set-window-option -g clock-mode-colour ", q(styles.clock), "\n")
  end
  if styles.message then
    f:write("set-option -g message-style ", q(styles.message), "\n")
  end
  if styles.message_command then
    f:write("set-option -g message-command-style ", q(styles.message_command), "\n")
  end
  if styles.mode then
    f:write("set-option -g mode-style ", q(styles.mode), "\n")
  end

  f:close()
end

function M.themes()
  print("Bundled themes:")
  local out = capture("find " .. q(root .. "/themes") .. " -maxdepth 1 -type f -name '*.lua' | sort")
  for file in out:gmatch("[^\n]+") do
    local name = file:match("([^/]+)%.lua$")
    if name ~= "default" then
      print("  " .. name)
    end
  end
  print("\nUse one by copying it to " .. theme_file)
end

local function load_statusline()
  copy_default_spec()
  _G.LazyTmuxTheme = load_theme()
  local spec = load_lua_table(statusline_file, "statusline")
  return spec
end

local function style(block)
  local attrs = {}
  attrs[#attrs + 1] = "fg=" .. assert(block.fg, "statusline block missing fg")
  attrs[#attrs + 1] = "bg=" .. assert(block.bg, "statusline block missing bg")
  if block.attr and block.attr ~= "" then
    attrs[#attrs + 1] = block.attr
  end
  return "#[" .. table.concat(attrs, ",") .. "]" .. (block.text or "")
end

local function render_blocks(blocks)
  local out = {}
  for _, block in ipairs(blocks or {}) do
    out[#out + 1] = style(block)
  end
  return table.concat(out, "")
end

function M.statusline()
  local spec = load_statusline()
  mkdir(data_dir)

  local output = data_dir .. "/statusline.tmux"
  local f = assert(io.open(output, "w"))

  if spec.window then
    if spec.window.normal then
      f:write("set-window-option -g window-status-format ", q(style(spec.window.normal)), "\n")
    end
    if spec.window.current then
      f:write("set-window-option -g window-status-current-format ", q(style(spec.window.current)), "\n")
    end
  end

  f:write("set-option -g status-left ", q(render_blocks(spec.left)), "\n")
  f:write("set-option -g status-right ", q(render_blocks(spec.right)), "\n")
  f:close()
end

local function mtime(path)
  if not exists(path) then
    return "-"
  end
  local mac = capture("stat -f %m " .. q(path) .. " 2>/dev/null")
  if mac ~= "" then
    return mac
  end
  local linux = capture("stat -c %Y " .. q(path) .. " 2>/dev/null")
  if linux ~= "" then
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
  copy_default_spec()
  mkdir(data_dir)

  local lock = data_dir .. "/watch.pid"
  if exists(lock) then
    local f = io.open(lock, "r")
    local pid = f and f:read("*l")
    if f then
      f:close()
    end
    if pid and pid ~= "" and process_alive(pid) then
      return
    end
  end

  local pid = capture("sh -c 'echo $PPID'")
  local f = assert(io.open(lock, "w"))
  f:write(pid)
  f:write("\n")
  f:close()

  local last = watch_signature()
  while true do
    run("sleep 1")
    if server_pid and server_pid ~= "" then
      if not process_alive(server_pid) then
        os.remove(lock)
        return
      end
    end

    local current = watch_signature()
    if current ~= last then
      last = current
      M.theme()
      M.statusline()
      run("tmux source-file", q(root .. "/lazytmux.tmux"))
      run("tmux display-message", q("LazyTmux auto-reloaded"))
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
  ui = M.ui,
  popup = M.popup,
  theme = M.theme,
  themes = M.themes,
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

commands[command](unpack(arg, 2))
