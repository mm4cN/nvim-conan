local M = {}
local completion = require("conan.completion")

local function conan_check_or_install()
  if vim.fn.executable("conan") == 1 then
    return
  end

  vim.notify(
    "'conan' executable is missing. Install Conan 2.x manually and ensure it is available on your PATH.",
    vim.log.levels.ERROR
  )
end

---@class ConanSubCommand
---@field impl fun(args:string[], opts: table)

---@type table<string, ConanSubCommand>
local subcommand_tbl = {
  install = {
    impl = require("commands").install,
  },
  build = {
    impl = require("commands").build,
  },
  lock = {
    impl = require("commands").lock,
  },
  sbom = {
    impl = require("commands").sbom,
  },
  search = {
    impl = require("commands").search,
  },
  create = {
    impl = require("commands").create,
  },
  export = {
    impl = require("commands").export,
  },
  export_package = {
    impl = require("commands").export_package,
  },
  upload = {
    impl = require("commands").upload,
  },
  reconfigure = {
    impl = require("utils").reconfigure,
  },
}

---@param opts table :h lua-guide-commands-create
local function ConanCmd(opts)
  local fargs = opts.fargs
  local subcommand_key = fargs[1]
  local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
  local subcommand = subcommand_tbl[subcommand_key]
  if not subcommand then
    vim.notify("Conan: Unknown command: " .. subcommand_key, vim.log.levels.ERROR)
    return
  end
  subcommand.impl(args, opts)
end

vim.api.nvim_create_user_command("Conan", ConanCmd, {
  nargs = "+",
  desc = "Conan commands completions",
  complete = function(arg_lead, cmdline, cursor_position)
    local context = completion.context(cmdline, cursor_position)
    if context and subcommand_tbl[context.subcommand] and context.argument_index > 0 then
      return completion.complete(context, arg_lead)
    end
    if cmdline:match("^['<,'>]*Conan[!]*%s+[%w_]*$") then
      local subcommand_keys = vim.tbl_keys(subcommand_tbl)
      local matches = vim
        .iter(subcommand_keys)
        :filter(function(key)
          return key:sub(1, #arg_lead) == arg_lead
        end)
        :totable()
      table.sort(matches)
      return matches
    end
    return {}
  end,
  bang = true,
})

---Setup the Conan plugin
M.setup = function()
  if vim.g.conan_did_setup then
    return
  end
  vim.g.conan_did_setup = true
  conan_check_or_install()

  local ok_cmd = pcall(require, "commands")
  if not ok_cmd then
    vim.notify("Conan: failed to load commands module", vim.log.levels.ERROR)
    return
  end

  local utils = require("utils")
  local version = require("version")
  local cwd = vim.fn.getcwd()

  local has_py = vim.fn.empty(vim.fn.glob(cwd .. "/conanfile*.py")) == 0
  local has_txt = vim.fn.empty(vim.fn.glob(cwd .. "/conanfile*.txt")) == 0
  if not (has_py or has_txt) then
    return
  end

  local config_path = utils.find_config(cwd)
  if not config_path then
    vim.schedule(function()
      utils.configure()
    end)
    return
  end

  local ok, config = pcall(function()
    local file = io.open(config_path, "r")
    if not file then
      return nil
    end
    local content = file:read("*a")
    file:close()
    return vim.json.decode(content)
  end)

  if ok and config then
    utils.check_version_compat(config.version, version)
  else
    vim.notify("⚠️ Failed to read existing config at " .. config_path, vim.log.levels.WARN)
  end
end

return M
