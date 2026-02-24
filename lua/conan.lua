local M = {}

local function conan_check_or_install()
  if vim.fn.executable("conan") == 1 then
    return
  end

  local py = vim.g.python3_host_prog or "python3"
  vim.fn.system(py .. " -m pip --version")
  local pip_available = vim.v.shell_error == 0

  if not pip_available then
    vim.notify("'conan' executable is missing and pip is unavailable to install it.\nCheck your Python provider or install manually.", vim.log.levels.ERROR)
    return
  end

  local choice = vim.fn.input("'conan' not found. Install with pip? [y/N]: ")
  if choice:lower() ~= "y" then
    vim.notify("'conan' is required but not installed.", vim.log.levels.ERROR)
    return
  end

  vim.fn.system(py .. " -m pip install --user conan")
  if vim.v.shell_error == 0 then
    vim.notify("✅ Installed 'conan' using pip", vim.log.levels.INFO)
    return
  end

  vim.notify("❌ Failed to install 'conan' using pip", vim.log.levels.ERROR)
end

---@class ConanSubCommand
---@field impl fun(args:string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, ConanSubCommand>
local subcommand_tbl = {
  install = {
    impl = require("commands").install,
  },
  build = {
    impl = require("commands").build
  },
  lock = {
    impl = require("commands").lock
  },
  search = {
    impl = require("commands").search
  },
  create = {
    impl = require("commands").create
  },
  export = {
    impl = require("commands").export
  },
  export_package = {
    impl = require("commands").export_package
  },
  upload = {
    impl = require("commands").upload
  },
  reconfigure = {
    impl = require("utils").reconfigure
  }
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
    complete = function(arg_lead, cmdline, _)
        local subcmd_key, subcmd_arg_lead = cmdline:match("^['<,'>]*Conan[!]*%s(%S+)%s(.*)$")
        if subcmd_key
            and subcmd_arg_lead
            and subcommand_tbl[subcmd_key]
            and subcommand_tbl[subcmd_key].complete
        then
            return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
        end
        if cmdline:match("^['<,'>]*Conan[!]*%s+%w*$") then
            local subcommand_keys = vim.tbl_keys(subcommand_tbl)
            return vim.iter(subcommand_keys)
                :filter(function(key)
                    return key:find(arg_lead) ~= nil
                end)
                :totable()
        end
    end,
    bang = true,
})

---Setup the Conan plugin
---Setup the Conan plugin
M.setup = function()
  conan_check_or_install()

  local ok_cmd, commands = pcall(require, "commands")
  if not ok_cmd then
    vim.notify("Conan: failed to load commands module", vim.log.levels.ERROR)
    return
  end

  local utils = require("utils")
  local version = require("version")
  local cwd = vim.fn.getcwd()

  -- Detect Conan recipe in CWD (py OR txt)
  local has_py = vim.fn.empty(vim.fn.glob(cwd .. "/conanfile*.py")) == 0
  local has_txt = vim.fn.empty(vim.fn.glob(cwd .. "/conanfile*.txt")) == 0
  if not (has_py or has_txt) then
    return
  end

  -- Resolve config file path (be defensive)
  local config_file = nil
  if type(commands.config_path) == "function" then
    config_file = commands.config_path()
  end

  -- Fallback if commands.config_path() is missing or returned nil/empty
  if type(config_file) ~= "string" or config_file == "" then
    config_file = ".nvim-conan.json"
  end

  local config_path = config_file:match("^/") and config_file or (cwd .. "/" .. config_file)

  if utils.file_exists(config_path) then
    local ok, config = pcall(function()
      local file = io.open(config_path, "r")
      if not file then return nil end
      local content = file:read("*a")
      file:close()
      return vim.json.decode(content)
    end)

    if ok and config then
      -- guard: config.version may be missing
      utils.check_version_compat(config.version, version)
    else
      vim.notify("⚠️ Failed to read existing config at " .. config_path, vim.log.levels.WARN)
    end

    return
  end

  vim.schedule(function()
    utils.reconfigure()
  end)
end

return M
