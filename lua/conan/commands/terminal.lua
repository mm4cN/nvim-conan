local M = {}

local command_builder = require("conan.command_builder")
local common = require("conan.commands.common")

local function require_config()
  local config = common.read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
  end
  return config
end

--- Runs `conan install` using the project configuration.
function M.install()
  local config = require_config()
  if not config then
    return
  end

  local argv = command_builder.install(config, common.resolve_lockfile(config))
  common.run_terminal_with_status("📦 Conan: install", argv, "📦 Conan Install", true)
end

--- Runs `conan build` and links the newest compile database on success.
function M.build()
  local config = require_config()
  if not config then
    return
  end

  local argv = command_builder.build(config, common.resolve_lockfile(config))
  common.run_terminal_with_status("🔨 Conan: build", argv, "🔨 Conan Build", true, {
    buffer_name = "conan-build",
    on_exit = function(code)
      if code ~= 0 then
        return
      end

      local utils = require("utils")
      local compile_commands = utils.find_latest_compile_commands()
      if compile_commands then
        utils.link_compile_commands(compile_commands)
      end
    end,
  })
end

--- Runs `conan lock create` for the configured recipe.
function M.lock()
  local config = require_config()
  if not config then
    return
  end

  local argv = command_builder.lock(config)
  common.run_terminal_with_status("🔒 Conan: lock", argv, "🔒 Conan Lock", true)
end

--- Generates a CycloneDX SBOM from the resolved dependency graph.
---@param args string[]|nil
function M.sbom(args)
  args = args or {}
  if #args > 2 then
    vim.notify("Usage: :Conan sbom [1.4|1.6] [output-folder]", vim.log.levels.ERROR)
    return
  end

  local format = args[1] or "1.6"
  if format ~= "1.4" and format ~= "1.6" then
    vim.notify("SBOM format must be 1.4 or 1.6", vim.log.levels.ERROR)
    return
  end

  local output_folder = args[2] or "build/sbom"
  if output_folder == "" then
    vim.notify("SBOM output folder must not be empty", vim.log.levels.ERROR)
    return
  end

  local config = require_config()
  if not config then
    return
  end

  local argv = command_builder.sbom(config, common.resolve_lockfile(config), format, output_folder)
  local output_file = output_folder .. "/sbom-cyclonedx-" .. format .. ".json"
  common.run_terminal_with_status("📋 Conan: SBOM", argv, "📋 Conan SBOM", true, {
    on_exit = function(code)
      if code == 0 then
        vim.notify("Generated SBOM: " .. output_file, vim.log.levels.INFO)
      end
    end,
  })
end

--- Runs `conan create` with additional literal arguments.
---@param args string[]|nil
function M.create(args)
  local config = require_config()
  if not config then
    return
  end

  local argv = command_builder.create(config, args)
  common.run_terminal_with_status("📦 Conan: create", argv, "📦 Conan Create", true)
end

--- Runs `conan export` with additional literal arguments.
---@param args string[]|nil
function M.export(args)
  local config = require_config()
  if not config then
    return
  end

  local argv = command_builder.export(config, args)
  common.run_terminal_with_status("📤 Conan: export", argv, "📤 Conan Export", true)
end

--- Runs `conan export-pkg` with additional literal arguments.
---@param args string[]|nil
function M.export_package(args)
  local config = require_config()
  if not config then
    return
  end

  local argv = command_builder.export_package(config, args)
  common.run_terminal_with_status("📦 Conan: export-pkg", argv, "📦 Conan Export-Pkg", true)
end

return M
