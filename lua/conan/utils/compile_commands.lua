local M = {}

function M.find_latest_compile_commands()
  local cwd = vim.fn.getcwd()
  local files = vim.fn.glob(cwd .. "/**/compile_commands.json", true, true)
  if type(files) ~= "table" or #files == 0 then
    return nil
  end

  local newest, newest_mtime = nil, -1
  for _, path in ipairs(files) do
    local stat = vim.loop.fs_stat(path)
    if stat and stat.mtime and stat.mtime.sec and stat.mtime.sec > newest_mtime then
      newest = path
      newest_mtime = stat.mtime.sec
    end
  end
  return newest
end

function M.link_compile_commands(path)
  if type(path) ~= "string" or path == "" then
    return
  end

  local target = vim.fn.getcwd() .. "/compile_commands.json"
  vim.system({ "ln", "-sf", path, target }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify("🔗 Linked compile_commands.json", vim.log.levels.INFO)
      else
        vim.notify(result.stderr or "Failed to link compile_commands.json", vim.log.levels.WARN)
      end
    end)
  end)
end

return M
