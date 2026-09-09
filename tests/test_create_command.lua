local test_set = MiniTest.new_set()
local expect = MiniTest.expect

test_set["Conan create propagates dispatcher arguments through the handler"] = function()
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

  vim.fn.mkdir(project_dir, "p")
  local config_file = assert(io.open(project_dir .. "/conan-config.json", "w"))
  assert(config_file:write(vim.json.encode({
    recipe = "recipes/conanfile.py",
    profile_build = "build-profile",
    profile_host = "host-profile",
    build_policy = "missing",
  })))
  assert(config_file:close())

  local ok, err = xpcall(function()
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

    dispatcher({
      fargs = { "create", "--version=1.2.3", "--user=alice", "--channel=testing" },
    })

    expect.equality(captured_argv, {
      "conan",
      "create",
      "recipes/conanfile.py",
      "-pr:b",
      "build-profile",
      "-pr:h",
      "host-profile",
      "--build=missing",
      "--version=1.2.3",
      "--user=alice",
      "--channel=testing",
    })
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

return test_set
