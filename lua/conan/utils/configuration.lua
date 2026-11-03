local M = {}

local function parse_quoted_string_list(value)
  local position = 1
  local length = #value

  local function skip_whitespace()
    while position <= length and value:sub(position, position):match("%s") do
      position = position + 1
    end
  end

  skip_whitespace()
  if value:sub(position, position) ~= "[" then
    return nil
  end
  position = position + 1
  skip_whitespace()

  local result = {}
  if value:sub(position, position) == "]" then
    position = position + 1
    skip_whitespace()
    return position > length and result or nil
  end

  while position <= length do
    local quote = value:sub(position, position)
    if quote ~= "'" and quote ~= '"' then
      return nil
    end
    position = position + 1

    local characters = {}
    local closed = false
    while position <= length do
      local character = value:sub(position, position)
      if character == quote then
        closed = true
        position = position + 1
        break
      end
      if character == "\\" and position < length then
        local escaped = value:sub(position + 1, position + 1)
        if escaped == quote or escaped == "\\" then
          characters[#characters + 1] = escaped
        else
          characters[#characters + 1] = character .. escaped
        end
        position = position + 2
      else
        characters[#characters + 1] = character
        position = position + 1
      end
    end
    if not closed then
      return nil
    end
    result[#result + 1] = table.concat(characters)

    skip_whitespace()
    local separator = value:sub(position, position)
    if separator == "]" then
      position = position + 1
      skip_whitespace()
      return position > length and result or nil
    end
    if separator ~= "," then
      return nil
    end
    position = position + 1
    skip_whitespace()
  end

  return nil
end

local function parse_prompt_value(value)
  if not value:match("^%s*%[") then
    return value
  end

  local ok, decoded = pcall(vim.json.decode, value)
  if ok and type(decoded) == "table" then
    return decoded
  end
  return parse_quoted_string_list(value) or value
end

local function prompt_for(what, callback)
  local values = {}
  local function prompt()
    vim.ui.input({
      prompt = "Enter " .. what .. " (key=value), enter with blank field to finish: ",
    }, function(input)
      if input == nil then
        callback(nil)
      elseif input ~= "" then
        local key, value = input:match("^%s*(.-)%s*=%s*(.-)%s*$")
        if key and value and key ~= "" and value ~= "" then
          values[key] = parse_prompt_value(value)
        else
          vim.notify("Invalid input. Use key=value format.", vim.log.levels.WARN)
        end
        prompt()
      else
        callback(values)
      end
    end)
  end
  prompt()
end

local function optional_build_policy(callback)
  vim.ui.input({
    prompt = "Build policy (optional; value after --build=, e.g. missing or missing:zlib/*): ",
  }, function(input)
    if input == nil then
      callback(nil)
      return
    end
    callback(vim.trim(input))
  end)
end

local function replace_config(dependencies, path, config)
  local fd, temp_path, temp_error = vim.loop.fs_mkstemp(path .. ".tmp.XXXXXX")
  if not fd then
    vim.notify("❌ Failed to create temporary config: " .. tostring(temp_error), vim.log.levels.ERROR)
    return false
  end
  local closed, close_error = vim.loop.fs_close(fd)
  if not closed then
    vim.loop.fs_unlink(temp_path)
    vim.notify("❌ Failed to close temporary config: " .. tostring(close_error), vim.log.levels.ERROR)
    return false
  end

  local write_ok, written = pcall(dependencies.write_json_file, temp_path, config)
  if not write_ok or not written then
    vim.loop.fs_unlink(temp_path)
    vim.notify("❌ Failed to write temporary config", vim.log.levels.ERROR)
    return false
  end

  local replaced, replace_error = vim.loop.fs_rename(temp_path, path)
  if not replaced then
    vim.loop.fs_unlink(temp_path)
    vim.notify("❌ Failed to replace config: " .. tostring(replace_error), vim.log.levels.ERROR)
    return false
  end
  return true
end

---@param dependencies table
---@param configuration_options table
function M.run(dependencies, configuration_options)
  local version = require("version")
  local config_path = configuration_options.config_path or dependencies.default_config_path()
  local cancelled = false

  local function cancel_configuration()
    if not cancelled then
      cancelled = true
      vim.notify("⚠️ Configuration cancelled", vim.log.levels.INFO)
    end
  end

  dependencies.pick_recipe("Select Conan Recipe", function(recipe)
    if recipe == nil then
      cancel_configuration()
      return
    end
    dependencies.pick_conan_profile("Select Host Profile", function(host_profile)
      if host_profile == nil then
        cancel_configuration()
        return
      end
      dependencies.pick_conan_profile("Select Build Profile", function(build_profile)
        if build_profile == nil then
          cancel_configuration()
          return
        end

        local function finish_configuration(build_policy)
          if build_policy == nil then
            cancel_configuration()
            return
          end
          prompt_for("options", function(options)
            if options == nil then
              cancel_configuration()
              return
            end
            prompt_for("conf", function(conf)
              if conf == nil then
                cancel_configuration()
                return
              end
              vim.ui.input({ prompt = "Enter lockfile path (optional): " }, function(lockfile)
                if lockfile == nil then
                  cancel_configuration()
                  return
                end

                local config = {
                  recipe = recipe,
                  version = version,
                  profile_build = build_profile,
                  profile_host = host_profile,
                  options = options or {},
                  conf = conf or {},
                }
                if build_policy ~= "" then
                  config.build_policy = build_policy
                end
                if lockfile ~= "" then
                  config.lockfile = lockfile
                end

                if not replace_config(dependencies, config_path, config) then
                  return
                end

                vim.notify(
                  string.format(
                    "🎯 Configured with host: %s, build: %s%s",
                    host_profile,
                    build_profile,
                    build_policy ~= "" and ", policy: " .. build_policy or ""
                  ),
                  vim.log.levels.INFO
                )
                dependencies.check_version_compat(config.version, version)
              end)
            end)
          end)
        end

        if configuration_options.prompt_for_build_policy then
          optional_build_policy(finish_configuration)
        else
          finish_configuration("")
        end
      end)
    end)
  end)
end

return M
