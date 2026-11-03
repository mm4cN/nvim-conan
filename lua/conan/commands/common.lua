local M = {}

local conan_status = require("conan_status")

--- Reads and decodes `conan-config.json` from cwd or `.vscode/` subdirectory.
---@return table|nil
function M.read_config()
  return require("conan.utils.config").read_config(vim.fn.getcwd())
end

---@param config table
---@return string|nil
function M.resolve_lockfile(config)
  if config.lockfile and config.lockfile ~= "" then
    return config.lockfile
  end
  if vim.loop.fs_stat(vim.fn.getcwd() .. "/conan.lock") ~= nil then
    return "conan.lock"
  end
  return nil
end

--- Runs a command in a terminal panel and tracks it in the statusline.
---@param text string
---@param argv string[]
---@param title string
---@param close_term boolean
---@param opts? {on_exit?: fun(code: integer), buffer_name?: string}
function M.run_terminal_with_status(text, argv, title, close_term, opts)
  local utils = require("utils")
  opts = opts or {}
  conan_status.start(text)

  utils.open_floating_terminal(argv, title, close_term, {
    buffer_name = opts.buffer_name,
    on_exit = function(code)
      conan_status.stop()

      if type(opts.on_exit) == "function" then
        pcall(opts.on_exit, code)
      end

      if code ~= 0 then
        vim.notify(("Conan command failed (exit %d)"):format(code), vim.log.levels.ERROR)
      end
    end,
  })
end

return M
