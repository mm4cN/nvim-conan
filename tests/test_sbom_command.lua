local test_set = MiniTest.new_set()
local expect = MiniTest.expect

test_set["Conan sbom dispatches graph generation and reports the output file"] = function()
  local utils = require("utils")
  local conan_status = require("conan_status")
  local plugin_root = vim.fn.getcwd()
  local original = {
    cwd = vim.fn.getcwd(),
    create_user_command = vim.api.nvim_create_user_command,
    notify = vim.notify,
    open_floating_terminal = utils.open_floating_terminal,
    status_start = conan_status.start,
    status_stop = conan_status.stop,
  }
  local project_dir = vim.fn.tempname()
  local captured_argv
  local captured_terminal_options
  local dispatcher
  local notifications = {}

  vim.fn.mkdir(project_dir, "p")
  local config_file = assert(io.open(project_dir .. "/conan-config.json", "w"))
  assert(config_file:write(vim.json.encode({
    recipe = "recipes/conanfile.py",
    profile_build = "build-profile",
    profile_host = "host-profile",
    lockfile = "locks/project.lock",
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
    vim.notify = function(message)
      notifications[#notifications + 1] = message
    end
    conan_status.start = function() end
    conan_status.stop = function() end
    utils.open_floating_terminal = function(argv, _, _, options)
      captured_argv = argv
      captured_terminal_options = options
    end

    dispatcher({ fargs = { "sbom", "1.4", "artifacts/sbom" } })

    expect.equality(captured_argv, {
      "conan",
      "graph",
      "info",
      "recipes/conanfile.py",
      "-pr:b",
      "build-profile",
      "-pr:h",
      "host-profile",
      "--lockfile",
      "locks/project.lock",
      "--deployer=cyclone_1.4",
      "--deployer-folder",
      "artifacts/sbom",
    })

    captured_terminal_options.on_exit(0)
    expect.equality(notifications[#notifications], "Generated SBOM: artifacts/sbom/sbom-cyclonedx-1.4.json")
  end, debug.traceback)

  vim.api.nvim_create_user_command = original.create_user_command
  vim.notify = original.notify
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
