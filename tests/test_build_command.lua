local test_set = MiniTest.new_set()
local expect = MiniTest.expect

test_set["Conan build opens a named terminal buffer"] = function()
  local commands = require("commands")
  local utils = require("utils")
  local conan_status = require("conan_status")
  local original = {
    cwd = vim.fn.getcwd(),
    open_floating_terminal = utils.open_floating_terminal,
    status_start = conan_status.start,
    status_stop = conan_status.stop,
  }
  local project_dir = vim.fn.tempname()
  local terminal_options

  vim.fn.mkdir(project_dir, "p")
  local config_file = assert(io.open(project_dir .. "/conan-config.json", "w"))
  assert(config_file:write(vim.json.encode({
    recipe = "recipes/conanfile.py",
    profile_build = "build-profile",
    profile_host = "host-profile",
  })))
  assert(config_file:close())

  local ok, err = xpcall(function()
    vim.fn.chdir(project_dir)
    conan_status.start = function() end
    conan_status.stop = function() end
    utils.open_floating_terminal = function(_, _, _, options)
      terminal_options = options
    end

    commands.build()

    expect.equality(terminal_options.buffer_name, "conan-build")
  end, debug.traceback)

  utils.open_floating_terminal = original.open_floating_terminal
  conan_status.start = original.status_start
  conan_status.stop = original.status_stop
  vim.fn.chdir(original.cwd)
  vim.fn.delete(project_dir, "rf")

  if not ok then
    error(err)
  end
end

return test_set
