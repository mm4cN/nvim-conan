local M = {
  config_file = vim.fn.getcwd() .. "/" .. ".nvim-conan.json"
}

local utils = require("utils")
local reference = vim.fn.getcwd() .. "/conanfile.py"

local function read_config()
  local ok, config = pcall(function()
    local file = io.open(M.config_file, "r")
    if not file then
      return nil
    end
    local content = file:read("*a")
    file:close()
    return vim.fn.json_decode(content)
  end)
  if not ok or config == nil then
    return nil
  end
  return config
end

M.install = function()
  local config = read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
  end
  local cmd = string.format(
    "conan install %s -pr:b %s -pr:h %s --build=%s",
    reference,
    config.profile_build,
    config.profile_host,
    config.opts.build_policy
  )
  utils.open_floating_terminal(cmd, "🔧 Conan Install")
end

M.build = function()
end

M.lock = function()
end

M.version = function()
end

M.create = function()
end

M.export = function()
end

M.export_package = function()
end

M.upload = function()
end

return M

