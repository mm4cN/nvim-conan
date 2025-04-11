local M = {}

function M.file_exists(path)
  return vim.loop.fs_stat(path) ~= nil
end

function M.write_json_file(path, tbl)
  local file = io.open(path, "w")
  if not file then
    vim.notify("❌ Failed to open " .. path .. " for writing", vim.log.levels.ERROR)
    return false
  end

  file:write(M.encode_json(tbl, 0))
  file:close()
  return true
end

function M.encode_json(tbl, indent)
  indent = indent or 0
  local indent_str = string.rep("  ", indent + 1)
  local lines = {"{"}
  local i, n = 0, 0
  for _ in pairs(tbl) do n = n + 1 end

  for k, v in pairs(tbl) do
    i = i + 1
    local key = string.format('"%s"', tostring(k))
    local val
    if type(v) == "string" then
      val = string.format("%q", v)
    elseif type(v) == "number" or type(v) == "boolean" then
      val = tostring(v)
    elseif type(v) == "table" then
      val = vim.fn.json_encode(v)
    else
      val = "null"
    end

    local comma = (i < n) and "," or ""
    table.insert(lines, string.format('%s%s: %s%s', indent_str, key, val, comma))
  end

  table.insert(lines, string.rep("  ", indent) .. "}")
  return table.concat(lines, "\n")
end

function M.ensure_config(path, default_table)
  if M.file_exists(path) then
    vim.notify("🟢 Config exists at " .. path, vim.log.levels.DEBUG)
    return
  end

  if M.write_json_file(path, default_table) then
    vim.notify("✅ Created config: " .. path, vim.log.levels.INFO)
  end
end

function M.get_major_version(version)
  return tonumber(version:match("^(%d+)")) or 0
end

function M.check_version_compat(config_version, plugin_version)
  local config_major = M.get_major_version(config_version)
  local plugin_major = M.get_major_version(plugin_version)

  if config_major ~= plugin_major then
    vim.notify(string.format(
      "⚠️ Config version (%s) might not be compatible with plugin version (%s).\nPlease review your config file.",
      config_version, plugin_version
    ), vim.log.levels.INFO)
  end
end

function M.open_floating_terminal(cmd, title)
  assert(type(cmd) == "string", "cmd must be a string")

  local buf = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title or cmd,
    title_pos = "center",
  })

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "terminal"

  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(_, code, _)
      vim.schedule(function()
        if code == 0 then
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        else
          vim.cmd("startinsert")
          vim.fn.getchar()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end
      end)
    end,
  })

  vim.cmd("startinsert")
  vim.bo[buf].modifiable = false
end

return M
