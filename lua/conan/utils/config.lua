local M = {}

function M.file_exists(path)
  return vim.loop.fs_stat(path) ~= nil
end

function M.default_path()
  return vim.fn.getcwd() .. "/conan-config.json"
end

function M.find_config(cwd)
  local candidates = {
    cwd .. "/conan-config.json",
    cwd .. "/.vscode/conan-config.json",
  }
  for _, path in ipairs(candidates) do
    if M.file_exists(path) then
      return path
    end
  end
  return nil
end

function M.read_config(cwd)
  local path = M.find_config(cwd)
  if not path then
    return nil
  end

  local ok, config = pcall(function()
    local file = io.open(path, "r")
    if not file then
      return nil
    end
    local content = file:read("*a")
    file:close()
    return vim.json.decode(content)
  end)

  if not ok or config == nil then
    return nil
  end
  return config
end

function M.write_json_file(path, tbl)
  local file = io.open(path, "w")
  if not file then
    vim.notify("❌ Failed to open " .. path .. " for writing", vim.log.levels.ERROR)
    return false
  end

  local written = file:write(M.encode_json(tbl, 0))
  local closed = file:close()
  if not written or not closed then
    vim.notify("❌ Failed to write " .. path, vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.encode_json(tbl, indent)
  indent = indent or 0
  local indent_str = string.rep("  ", indent + 1)
  local lines = { "{" }
  local index, count = 0, 0
  for _ in pairs(tbl) do
    count = count + 1
  end

  for key, value in pairs(tbl) do
    index = index + 1
    local encoded_key = string.format('"%s"', tostring(key))
    local encoded_value
    if type(value) == "string" then
      encoded_value = string.format("%q", value)
    elseif type(value) == "number" or type(value) == "boolean" then
      encoded_value = tostring(value)
    elseif type(value) == "table" and (key == "options" or key == "conf") then
      local nested_lines = { "{" }
      local nested_index, nested_count = 0, 0
      for _ in pairs(value) do
        nested_count = nested_count + 1
      end
      for nested_key, nested_value in pairs(value) do
        nested_index = nested_index + 1
        local encoded_nested_key = string.format('"%s"', tostring(nested_key))
        local encoded_nested_value = vim.json.encode(nested_value)
        local nested_comma = nested_index < nested_count and "," or ""
        table.insert(
          nested_lines,
          string.format("%s  %s: %s%s", indent_str, encoded_nested_key, encoded_nested_value, nested_comma)
        )
      end
      table.insert(nested_lines, indent_str .. "}")
      encoded_value = table.concat(nested_lines, "\n")
    elseif type(value) == "table" then
      encoded_value = vim.fn.json_encode(value)
    end

    local comma = index < count and "," or ""
    table.insert(lines, string.format("%s%s: %s%s", indent_str, encoded_key, encoded_value, comma))
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
    vim.notify(
      string.format(
        "⚠️ Config version (%s) might not be compatible with plugin version (%s).\nPlease review your config file.",
        config_version,
        plugin_version
      ),
      vim.log.levels.INFO
    )
  end
end

return M
