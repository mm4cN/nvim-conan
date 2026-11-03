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

return test_set
