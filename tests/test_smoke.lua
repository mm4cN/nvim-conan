local test_set = MiniTest.new_set()
local expect = MiniTest.expect

test_set["loads conan with its runtime dependencies"] = function()
  local conan = require("conan")

  expect.equality(type(conan), "table")
  expect.equality(type(conan.setup), "function")
end

test_set["loads split command modules through the public facade"] = function()
  local commands = require("commands")

  for _, name in ipairs({
    "install",
    "build",
    "lock",
    "sbom",
    "create",
    "export",
    "export_package",
    "search",
    "upload",
  }) do
    expect.equality(type(commands[name]), "function")
  end

  expect.equality(type(require("conan.commands.common")), "table")
  expect.equality(type(require("conan.commands.terminal")), "table")
  expect.equality(type(require("conan.commands.search")), "table")
  expect.equality(type(require("conan.commands.upload")), "table")
end

test_set["loads split utility modules through the public facade"] = function()
  local utils = require("utils")

  for _, name in ipairs({
    "file_exists",
    "find_config",
    "write_json_file",
    "encode_json",
    "ensure_config",
    "get_major_version",
    "check_version_compat",
    "open_floating_terminal",
    "get_conan_remotes_from_cli",
    "get_cached_package_refs",
    "get_conan_profiles",
    "pick_conan_profile",
    "pick_recipe",
    "find_latest_compile_commands",
    "link_compile_commands",
    "configure",
    "reconfigure",
  }) do
    expect.equality(type(utils[name]), "function")
  end

  expect.equality(type(require("conan.utils.config")), "table")
  expect.equality(type(require("conan.utils.configuration")), "table")
  expect.equality(type(require("conan.utils.selectors")), "table")
  expect.equality(type(require("conan.utils.terminal")), "table")
  expect.equality(type(require("conan.utils.compile_commands")), "table")
end

return test_set
