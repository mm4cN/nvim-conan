--- nvim-conan main module.
--- Provides user-facing commands for Conan workflows inside Neovim:
--- install/build/lock/create/export/export-pkg/search/upload.
---
--- This module integrates:
--- - floating terminal runner (utils.open_floating_terminal)
--- - lualine status via conan_status (spinner + text)
--- - Telescope UI for `conan search` results
---
--- Requirements:
--- - `utils.open_floating_terminal(cmd, title, close_term, opts)` supports `opts.on_exit(code, ctx?)`
--- - `conan_status.start(text)` accepts optional text and renders it in statusline
local M = {
  ---@private
  _search_started = false,
}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local conan_status = require("conan_status")

--- Returns absolute path to the per-project config file.
--- The path is based on the current working directory (respects `:cd`).
---@return string
local function config_path()
  return vim.fn.getcwd() .. "/.nvim-conan.json"
end

--- Reads and decodes `.nvim-conan.json` from current working directory.
--- Returns nil on any error (missing file / invalid JSON / IO error).
---@return table|nil
local function read_config()
  local ok, config = pcall(function()
    local file = io.open(config_path(), "r")
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

--- Runs a shell command in a floating terminal and shows a busy spinner in statusline.
--- Spinner stops when the terminal job exits (success or failure).
---
--- This is the preferred runner for long-running Conan commands (install/build/etc.).
---@param text string Statusline text to show while the command runs.
---@param cmd string Shell command executed in the floating terminal.
---@param title string Floating window title.
---@param close_term boolean If true, closes terminal window automatically on exit code 0.
local function run_terminal_with_status(text, cmd, title, close_term)
  local utils = require("utils")
  conan_status.start(text)

  utils.open_floating_terminal(cmd, title, close_term, {
    ---@param code integer
    on_exit = function(code)
      conan_status.stop()
      if code ~= 0 then
        vim.notify(("Conan command failed (exit %d)"):format(code), vim.log.levels.ERROR)
      end
    end,
  })
end

-- -------------------------
-- Conan commands (terminal)
-- -------------------------

--- Runs `conan install` using config from `.nvim-conan.json`.
--- Opens a floating terminal and shows statusline spinner until the command finishes.
function M.install()
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

  run_terminal_with_status("📦 Conan: install", cmd, "📦 Conan Install", true)
end

--- Runs `conan build` using config from `.nvim-conan.json`.
--- Also attempts to symlink `compile_commands.json` into project root if it can be located.
function M.build()
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

  run_terminal_with_status("🔨 Conan: build", cmd, "🔨 Conan Build", true)

  -- Best-effort symlink for tooling (clangd, etc.)
  local utils = require("utils")
  local compile_commands = utils.get_compile_commands_path()
  if compile_commands then
    local target = vim.fn.getcwd() .. "/compile_commands.json"
    vim.system({ "ln", "-sf", compile_commands, target }, { text = true }, function(res)
      vim.schedule(function()
        if res.code == 0 then
          vim.notify("🔗 Linked compile_commands.json to project root", vim.log.levels.INFO)
        else
          vim.notify(res.stderr or "Failed to link compile_commands.json", vim.log.levels.WARN)
        end
      end)
    end)
  end
end

--- Runs `conan lock create` using config from `.nvim-conan.json`.
function M.lock()
  local config = read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format("conan lock create %s", config.recipe or ".")
  run_terminal_with_status("🔒 Conan: lock", cmd, "🔒 Conan Lock", true)
end

--- Runs `conan create` using config from `.nvim-conan.json`.
function M.create()
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

  run_terminal_with_status("📦 Conan: create", cmd, "📦 Conan Create", true)
end

--- Runs `conan export` for the current recipe.
---@param args string[] CLI-like args: {user?, channel?}
function M.export(args)
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

  run_terminal_with_status("📤 Conan: export", cmd, "📤 Conan Export", true)
end

--- Runs `conan export-pkg` for the current recipe.
---@param args string[] CLI-like args: {user?, channel?}
function M.export_package(args)
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

  run_terminal_with_status("📦 Conan: export-pkg", cmd, "📦 Conan Export-Pkg", true)
end

-- -------------------------
-- Search (async + Telescope)
-- -------------------------

--- Asynchronously runs `conan search <pattern>` and returns decoded JSON results.
--- Uses a guard to prevent multiple concurrent searches.
---@param pattern string Search pattern (e.g. "huffman" or "pkg/*").
---@param remote string Remote name or "*" to search across remotes.
---@param on_finished fun(results: table) Callback invoked with decoded JSON results.
local function search_async(pattern, remote, on_finished)
  if M._search_started then
    vim.notify("A search is already in progress. Please wait.", vim.log.levels.WARN)
    return
  end

  M._search_started = true
  conan_status.start("🔍 Conan: search " .. pattern)

  vim.system(
    { "conan", "search", pattern, "-r=" .. remote, "-f=json", "-v=quiet" },
    { text = true },
    function(res)
      vim.schedule(function()
        conan_status.stop()
        M._search_started = false

        if res.code ~= 0 then
          vim.notify(res.stderr or "Conan search failed", vim.log.levels.ERROR)
          return
        end

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

--- Builds a reverse index from Conan search JSON:
--- - list of refs
--- - mapping ref -> remotes that contain it
--- - list of remotes
--- - mapping remote -> error string (if remote reported error)
---@param results table
---@return string[] refs
---@return table by_ref
---@return string[] all_remotes
---@return table remote_errors
local function build_index(results)
  local all_remotes, by_ref, remote_errors = {}, {}, {}

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

--- Opens Telescope picker for search results:
--- - left pane: package refs
--- - preview: remotes availability + per-remote errors
---@param pattern string
---@param results table
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
        return {
          value = ref,
          ordinal = ref,
          display = string.format("%-30s  (%d)", ref, cnt),
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

--- Entry point for `:Conan search <pattern> [remote]`
---@param args string[]
function M.search(args)
  local pattern = args[1]
  local remote = args[2] or "*"

  if not pattern then
    vim.notify("❌ Package name is required for :Conan search", vim.log.levels.ERROR)
    return
  end

  search_async(pattern, remote, function(results)
    open_search_picker(pattern, results)
  end)
end

-- -------------------------
-- Upload (status only on run)
-- -------------------------

--- Opens a Telescope flow: choose remote -> choose cached ref -> run `conan upload`.
--- Statusline spinner starts only when upload command actually runs.
function M.upload()
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

              run_terminal_with_status(
                ("📤 Conan: upload %s → %s"):format(ref, remote),
                cmd,
                string.format("📦 Upload: %s → %s", ref, remote),
                true
              )
            end)
            return true
          end,
        }):find()
      end)
      return true
    end,
  }):find()
end

return M
