local test_set = MiniTest.new_set()
local expect = MiniTest.expect

local commands = {
  {
    public_name = "export",
    executable_subcommand = "export",
    args = { "--user=alice", "--channel=stable" },
  },
  {
    public_name = "export_package",
    executable_subcommand = "export-pkg",
    args = { "--output-folder=build/package", "--user=alice", "--channel=stable" },
  },
}

local function test_command(command)
  local utils = require("utils")
  local conan_status = require("conan_status")
  local plugin_root = vim.fn.getcwd()
  local original = {
    cwd = vim.fn.getcwd(),
    create_user_command = vim.api.nvim_create_user_command,
    open_floating_terminal = utils.open_floating_terminal,
    status_start = conan_status.start,
    status_stop = conan_status.stop,
  }
  local project_dir = vim.fn.tempname()
  local captured_argv
  local dispatcher

  local ok, err = xpcall(function()
    vim.fn.mkdir(project_dir, "p")
    local config_file = assert(io.open(project_dir .. "/conan-config.json", "w"))
    assert(config_file:write(vim.json.encode({ recipe = "recipes/conanfile.py" })))
    assert(config_file:close())

    vim.api.nvim_create_user_command = function(name, callback)
      if name == "Conan" then
        dispatcher = callback
      end
    end
    dofile(plugin_root .. "/lua/conan.lua")
    vim.api.nvim_create_user_command = original.create_user_command

    vim.fn.chdir(project_dir)
    conan_status.start = function() end
    conan_status.stop = function() end
    utils.open_floating_terminal = function(argv)
      captured_argv = argv
    end

    local fargs = { command.public_name }
    vim.list_extend(fargs, command.args)
    dispatcher({ fargs = fargs })

    local expected = { "conan", command.executable_subcommand, "recipes/conanfile.py" }
    vim.list_extend(expected, command.args)
    expect.equality(captured_argv, expected)
  end, debug.traceback)

  vim.api.nvim_create_user_command = original.create_user_command
  utils.open_floating_terminal = original.open_floating_terminal
  conan_status.start = original.status_start
  conan_status.stop = original.status_stop
  vim.fn.chdir(original.cwd)
  vim.fn.delete(project_dir, "rf")

  if not ok then
    error(err)
  end
end

for _, command in ipairs(commands) do
  test_set[command.public_name .. " propagates dispatcher arguments through the handler and builder"] = function()
    test_command(command)
  end
end

return test_set
