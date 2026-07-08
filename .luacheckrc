std = "lua51"

files["plugins/default.lua"] = {
  read_globals = {
    "LazyTmuxPluginSpec",
  },
}

files["statusline/default.lua"] = {
  globals = {
    "LazyTmuxTheme",
  },
  read_globals = {
    "LazyTmuxColor",
    "LazyTmuxAttr",
    "LazyTmuxStatusBlock",
    "LazyTmuxWindowStatus",
    "LazyTmuxStatuslineSpec",
  },
}

files["themes/*.lua"] = {
  read_globals = {
    "LazyTmuxColor",
    "LazyTmuxThemeStyles",
    "LazyTmuxTheme",
  },
}

