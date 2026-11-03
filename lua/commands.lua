--- Public command facade kept for compatibility with the plugin dispatcher.
local function command(module, name)
  return function(...)
    return require(module)[name](...)
  end
end

return {
  install = command("conan.commands.terminal", "install"),
  build = command("conan.commands.terminal", "build"),
  lock = command("conan.commands.terminal", "lock"),
  sbom = command("conan.commands.terminal", "sbom"),
  create = command("conan.commands.terminal", "create"),
  export = command("conan.commands.terminal", "export"),
  export_package = command("conan.commands.terminal", "export_package"),
  search = command("conan.commands.search", "search"),
  upload = command("conan.commands.upload", "upload"),
}
