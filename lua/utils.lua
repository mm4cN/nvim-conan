--- Public utility facade kept for compatibility with existing integrations.
local M = {}

local function delegate(module, name)
  return function(...)
    return require(module)[name](...)
  end
end

M.file_exists = delegate("conan.utils.config", "file_exists")
M.find_config = delegate("conan.utils.config", "find_config")
M.write_json_file = delegate("conan.utils.config", "write_json_file")
M.encode_json = delegate("conan.utils.config", "encode_json")
M.ensure_config = delegate("conan.utils.config", "ensure_config")
M.get_major_version = delegate("conan.utils.config", "get_major_version")
M.check_version_compat = delegate("conan.utils.config", "check_version_compat")

M.open_floating_terminal = delegate("conan.utils.terminal", "open_floating_terminal")

M.get_conan_remotes_from_cli = delegate("conan.utils.selectors", "get_conan_remotes_from_cli")
M.get_cached_package_refs = delegate("conan.utils.selectors", "get_cached_package_refs")
M.get_conan_profiles = delegate("conan.utils.selectors", "get_conan_profiles")
M.pick_conan_profile = delegate("conan.utils.selectors", "pick_conan_profile")
M.pick_recipe = delegate("conan.utils.selectors", "pick_recipe")

M.find_latest_compile_commands = delegate("conan.utils.compile_commands", "find_latest_compile_commands")
M.link_compile_commands = delegate("conan.utils.compile_commands", "link_compile_commands")

local function configuration_dependencies()
  return {
    default_config_path = require("conan.utils.config").default_path,
    write_json_file = M.write_json_file,
    check_version_compat = M.check_version_compat,
    pick_conan_profile = M.pick_conan_profile,
    pick_recipe = M.pick_recipe,
  }
end

function M.configure()
  require("conan.utils.configuration").run(configuration_dependencies(), {
    prompt_for_build_policy = false,
  })
end

function M.reconfigure()
  local config = require("conan.utils.config")
  local config_path = M.find_config(vim.fn.getcwd()) or config.default_path()
  require("conan.utils.configuration").run(configuration_dependencies(), {
    prompt_for_build_policy = true,
    config_path = config_path,
  })
end

return M
