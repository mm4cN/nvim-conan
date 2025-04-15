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

function M.open_floating_terminal(cmd, title, close_term)
  assert(type(cmd) == "string", "cmd must be a string")

  if close_term == nil then
    close_term = true
  end

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
    title_pos = "left",
  })

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "terminal"

  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(_, code, _)
      vim.schedule(function()
        if (code == 0 and close_term) then
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

function M.get_conan_remotes_from_cli()
  local output = vim.fn.systemlist("conan remote list")
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local remotes = {}
  for _, line in ipairs(output) do
    local name = line:match("^(.-):%s")
    if name then
      table.insert(remotes, name)
    end
  end
  return remotes
end

function M.get_cached_package_refs()
  local output_lines = vim.fn.systemlist("conan list --format=json")
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to run `conan list`", vim.log.levels.ERROR)
    return {}
  end

  local json_start = nil
  for i, line in ipairs(output_lines) do
    if line:match("^%s*{") then
      json_start = i
      break
    end
  end

  if not json_start then
    vim.notify("Could not locate JSON in Conan list output", vim.log.levels.ERROR)
    return {}
  end

  local json = table.concat(vim.list_slice(output_lines, json_start), "\n")
  local ok, parsed = pcall(vim.fn.json_decode, json)
  if not ok or type(parsed) ~= "table" then
    vim.notify("Failed to parse Conan list JSON block", vim.log.levels.ERROR)
    return {}
  end

  local refs = {}
  local cache = parsed["Local Cache"]
  if not cache then
    vim.notify("No 'Local Cache' section found in parsed output", vim.log.levels.WARN)
    return {}
  end

  for ref, _ in pairs(cache) do
    table.insert(refs, ref)
  end

  table.sort(refs)
  return refs
end

function M.get_conan_profiles()
  local lines = vim.fn.systemlist("conan profile list")
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to run `conan profile list`", vim.log.levels.ERROR)
    return {}
  end

  local profiles = {}
  for _, line in ipairs(lines) do
    if not line:match("Profiles found") and line:match("%S") then
      table.insert(profiles, vim.trim(line))
    end
  end

  return profiles
end

function M.pick_conan_profile(prompt, callback)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local profiles = M.get_conan_profiles()
  if #profiles == 0 then
    vim.notify("No Conan profiles found", vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = prompt,
    finder = finders.new_table { results = profiles },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        actions.close(bufnr)
        local selection = action_state.get_selected_entry()[1]
        callback(selection)
      end)
      return true
    end,
  }):find()
end

function M.pick_build_policy(callback)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local options = { "missing", "never", "always" }

  pickers.new({}, {
    prompt_title = "Select Build Policy",
    finder = finders.new_table { results = options },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        actions.close(bufnr)
        local selection = action_state.get_selected_entry()[1]
        callback(selection)
      end)
      return true
    end,
  }):find()
end

function M.get_compile_commands_path()
  local config_file = require("commands").config_file
  local cwd = vim.fn.getcwd()

  local file = io.open(config_file, "r")
  if not file then
    vim.notify("Could not read config file: " .. config_file, vim.log.levels.ERROR)
    return nil
  end

  local content = file:read("*a")
  file:close()

  local config = vim.fn.json_decode(content)
  local profile = config and config.profile_build
  if not profile then
    vim.notify("Missing 'profile_build' in config", vim.log.levels.ERROR)
    return nil
  end

  local lines = vim.fn.systemlist("conan profile show -pr:h " .. profile)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get profile: " .. profile, vim.log.levels.ERROR)
    return nil
  end

  local in_host_settings = false
  local build_type = nil

  for _, line in ipairs(lines) do
    if line:match("^Host profile:") then
      in_host_settings = false
    elseif line:match("^%[settings%]") and not in_host_settings then
      in_host_settings = true
    elseif in_host_settings and line:match("^%[.*%]") then
      break
    elseif in_host_settings then
      local key, val = line:match("^(.-)=(.+)$")
      if key and key:match("build_type") then
        build_type = vim.trim(val)
        break
      end
    end
  end

  if not build_type then
    vim.notify("Could not find 'build_type' in host profile: " .. profile, vim.log.levels.WARN)
    return nil
  end

  local path = string.format("%s/build/%s/compile_commands.json", cwd, build_type)
  if vim.loop.fs_stat(path) then
    return path
  else
    return nil
  end
end

function M.reconfigure()
  local config_file = require("commands").config_file
  local version = require("version")
  local cwd = vim.fn.getcwd()
  local config_path = config_file:match("^/") and config_file or (cwd .. "/" .. config_file)

  if M.file_exists(config_path) then
    vim.loop.fs_unlink(config_path)
    vim.notify("✅ Removed old config", vim.log.levels.INFO)
  end

  M.pick_conan_profile("Select Host Profile", function(host_profile)
    M.pick_conan_profile("Select Build Profile", function(build_profile)
      M.pick_build_policy(function(build_policy)

        M.ensure_config(config_file, {
          name = "nvim-conan",
          version = version,
          profile_build = build_profile,
          profile_host = host_profile,
          build_policy = build_policy,
        })

        vim.notify(string.format(
          "🎯 Configured with host: %s, build: %s, policy: %s",
          host_profile, build_profile, build_policy
        ), vim.log.levels.INFO)

        local ok, config = pcall(function()
          local file = io.open(config_path, "r")
          if not file then return nil end
          local content = file:read("*a")
          file:close()
          return vim.fn.json_decode(content)
        end)

        if ok and config then
          M.check_version_compat(config.version, version)
        end
      end)
    end)
  end)
end

return M

