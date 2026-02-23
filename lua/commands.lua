local M = {
  config_file = vim.fn.getcwd() .. "/" .. ".nvim-conan.json",
  _search_started = false,
}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conan_status = require("conan_status")

local TERMINAL_STATUS_MS = 900
local function status_start(text)
  if conan_status.start then
    conan_status.start(text)
  else
    vim.g.conan_busy_text = text or "Conan"
    conan_status.start()
  end
end

local function status_stop()
  if conan_status.stop then
    conan_status.stop()
  end
end

local function with_status(text, fn, stop_after_ms)
  status_start(text)
  local ok, err = pcall(fn)
  if not ok then
    status_stop()
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if stop_after_ms and stop_after_ms > 0 then
    vim.defer_fn(function()
      status_stop()
    end, stop_after_ms)
  end
end

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
  with_status("📦 Conan: install", function()
    local config = read_config()
    if config == nil then
      vim.notify("Couldn't read config", vim.log.levels.ERROR)
      return
    end

    local cmd = string.format(
      "conan install %s -pr:b %s -pr:h %s --build=%s",
      config.recipe or ".",
      config.profile_build,
      config.profile_host,
      config.build_policy
    )

    require("utils").open_floating_terminal(cmd, "📦 Conan Install")
  end, TERMINAL_STATUS_MS)
end

M.build = function()
  with_status("🔨 Conan: build", function()
    local config = read_config()
    if config == nil then
      vim.notify("Couldn't read config", vim.log.levels.ERROR)
      return
    end

    local options_str = ""
    if config.options then
      for k, v in pairs(config.options) do
        options_str = options_str .. string.format("-o %s=%s ", k, v)
      end
    end

    local conf_str = ""
    if config.conf then
      for k, v in pairs(config.conf) do
        conf_str = conf_str .. string.format("-c %s=%s ", k, v)
      end
    end

    local cmd = string.format(
      "conan build %s -pr:b %s -pr:h %s --build=%s %s %s",
      config.recipe or ".",
      config.profile_build,
      config.profile_host,
      config.build_policy,
      options_str,
      conf_str
    )

    if vim.loop.fs_stat(vim.fn.getcwd() .. "/conan.lock") ~= nil then
      cmd = cmd .. " --lockfile=conan.lock"
    end

    require("utils").open_floating_terminal(cmd, "🔨 Conan Build")

    local compile_commands = require("utils").get_compile_commands_path()
    if compile_commands then
      local target = vim.fn.getcwd() .. "/compile_commands.json"
      os.execute(string.format("ln -sf %s %s", compile_commands, target))
      vim.notify("🔗 Linked compile_commands.json to project root", vim.log.levels.INFO)
    end
  end, TERMINAL_STATUS_MS)
end

M.lock = function()
  with_status("🔒 Conan: lock", function()
    local config = read_config()
    if config == nil then
      vim.notify("Couldn't read config", vim.log.levels.ERROR)
      return
    end

    local cmd = string.format("conan lock create %s", config.recipe or ".")
    require("utils").open_floating_terminal(cmd, "🔒 Conan Lock")
  end, TERMINAL_STATUS_MS)
end

local function search_async(pattern, remote, on_finished)
  if M._search_started then
    vim.notify("A search is already in progress. Please wait.", vim.log.levels.WARN)
    return
  end
  M._search_started = true
  vim.g.conan_busy_text = "Conan: " .. pattern
  conan_status.start()

  vim.system(
    { "conan", "search", pattern, "-r=" .. remote, "-f=json", "-v=quiet" },
    { text = true },
    function(res)
      vim.schedule(function()
        conan_status.stop()
        M._search_started = false
        local ok, decoded = pcall(vim.json.decode, res.stdout)
        if not ok then
          vim.notify("JSON decode failed", vim.log.levels.ERROR)
          return
        end
        on_finished(decoded)
      end)
    end
  )
end

local function build_index(results)
  local all_remotes = {}
  local by_ref = {}
  local remote_errors = {}

  for remote, payload in pairs(results or {}) do
    table.insert(all_remotes, remote)

    if type(payload) == "table" and payload.error then
      remote_errors[remote] = payload.error
    else
      for ref, _ in pairs(payload or {}) do
        by_ref[ref] = by_ref[ref] or {}
        by_ref[ref][remote] = true
      end
    end
  end

  table.sort(all_remotes)

  local refs = {}
  for ref, _ in pairs(by_ref) do
    table.insert(refs, ref)
  end
  table.sort(refs)

  return refs, by_ref, all_remotes, remote_errors
end

local function open_search_picker(pattern, results)
  local refs, by_ref, all_remotes, remote_errors = build_index(results)

  if #refs == 0 then
    local any_error = false
    for _, r in ipairs(all_remotes) do
      if remote_errors[r] then
        any_error = true
        break
      end
    end

    if any_error then
      local lines = { ("No recipes found for: %s"):format(pattern), "", "Remote errors:" }
      for _, r in ipairs(all_remotes) do
        if remote_errors[r] then
          table.insert(lines, ("  ⚠️  %s: %s"):format(r, remote_errors[r]))
        end
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN)
    else
      vim.notify(("No recipes found for: %s"):format(pattern), vim.log.levels.WARN)
    end
    return
  end

  pickers.new({}, {
    prompt_title = ("Conan search: " .. pattern),
    finder = finders.new_table({
      results = refs,
      entry_maker = function(ref)
        local present = by_ref[ref] or {}
        local cnt = 0
        for _ in pairs(present) do cnt = cnt + 1 end

        local display = string.format("%-30s  (%d)", ref, cnt)

        return {
          value = ref,
          ordinal = ref,
          display = display,
          present = present,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local lines = {}
        table.insert(lines, ("Recipe: %s"):format(entry.value))
        table.insert(lines, "")

        for _, r in ipairs(all_remotes) do
          local err = remote_errors[r]
          if err then
            table.insert(lines, ("  ⚠️  %s: %s"):format(r, err))
          else
            local ok = entry.present[r] == true
            table.insert(lines, ("  %s  %s"):format(ok and "✅" or "—", r))
          end
        end

        table.insert(lines, "")
        table.insert(lines, "Actions:")
        table.insert(lines, "  <Enter>  copy ref to clipboard")
        table.insert(lines, "  <C-i>    insert ref at cursor")

        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = "markdown"
      end,
    }),
    layout_strategy = "horizontal",
    layout_config = {
      preview_width = 0.50,
      width = 0.95,
      height = 0.80,
    },
    attach_mappings = function(prompt_bufnr, map)
      local function get_entry()
        return action_state.get_selected_entry()
      end

      actions.select_default:replace(function()
        local e = get_entry()
        actions.close(prompt_bufnr)
        if not e or not e.value then return end
        vim.fn.setreg("+", e.value)
        vim.notify(("Copied: %s"):format(e.value), vim.log.levels.INFO)
      end)

      map({ "i", "n" }, "<C-i>", function()
        local e = get_entry()
        actions.close(prompt_bufnr)
        if not e or not e.value then return end
        vim.api.nvim_put({ e.value }, "c", true, true)
      end)

      return true
    end,
  }):find()
end

M.search = function(args)
  local pattern = args[1]
  local remote = args[2]

  if not pattern then
    vim.notify("❌ Package name is required for :Conan search", vim.log.levels.ERROR)
    return
  end

  if remote == nil then
    remote = "*"
  end

  search_async(pattern, remote, function(results)
    open_search_picker(pattern, results)
  end)
end

M.create = function()
  with_status("📦 Conan: create", function()
    local config = read_config()
    if config == nil then
      vim.notify("Couldn't read config", vim.log.levels.ERROR)
      return
    end

    local cmd = string.format(
      "conan create -pr:b %s -pr:h %s --build=%s %s",
      config.profile_build,
      config.profile_host,
      config.build_policy,
      config.recipe or "."
    )
    require("utils").open_floating_terminal(cmd, "📦 Conan Create")
  end, TERMINAL_STATUS_MS)
end

M.export = function(args)
  with_status("📤 Conan: export", function()
    local user = args[1]
    local channel = args[2]

    local config = read_config()
    if config == nil then
      vim.notify("Couldn't read config", vim.log.levels.ERROR)
      return
    end

    local cmd = "conan export"
    if user then cmd = cmd .. " --user " .. user end
    if channel then cmd = cmd .. " --channel " .. channel end
    cmd = cmd .. " " .. (config.recipe or ".")

    require("utils").open_floating_terminal(cmd, "📤 Conan Export")
  end, TERMINAL_STATUS_MS)
end

M.export_package = function(args)
  with_status("📦 Conan: export-pkg", function()
    local user = args[1]
    local channel = args[2]
    local config = read_config()

    if config == nil then
      vim.notify("Couldn't read config", vim.log.levels.ERROR)
      return
    end

    local cmd = "conan export-pkg"
    if user then cmd = cmd .. string.format(" --user %s", user) end
    if channel then cmd = cmd .. string.format(" --channel %s", channel) end
    cmd = cmd .. " " .. (config.recipe or ".")

    require("utils").open_floating_terminal(cmd, "📦 Conan Export-Pkg")
  end, TERMINAL_STATUS_MS)
end

M.upload = function()
  with_status("📤 Conan: upload", function()
    local utils = require("utils")

    local remotes = utils.get_conan_remotes_from_cli()
    if #remotes == 0 then
      vim.notify("No remotes found from `conan remote list`.", vim.log.levels.WARN)
      return
    end

    pickers.new({}, {
      prompt_title = "Select Conan Remote",
      finder = finders.new_table { results = remotes },
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local remote = action_state.get_selected_entry()[1]

          local refs = utils.get_cached_package_refs()
          if #refs == 0 then
            vim.notify("No cached Conan packages found", vim.log.levels.WARN)
            return
          end

          pickers.new({}, {
            prompt_title = "Select Package Ref",
            finder = finders.new_table { results = refs },
            sorter = conf.generic_sorter({}),
            attach_mappings = function(ref_bufnr)
              actions.select_default:replace(function()
                actions.close(ref_bufnr)
                local ref = action_state.get_selected_entry()[1]

                local cmd = string.format("conan upload %s -r=%s --confirm", ref, remote)
                require("utils").open_floating_terminal(cmd, string.format("📦 Upload: %s → %s", ref, remote))
              end)
              return true
            end,
          }):find()
        end)
        return true
      end,
    }):find()
  end, TERMINAL_STATUS_MS)
end

return M
