local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local conan_status = require("conan_status")
local common = require("conan.commands.common")
local graph_options = require("conan.graph_options")
local recipe_editor = require("conan.recipe_editor")

local search_started = false

--- Asynchronously runs `conan search <pattern>` and decodes its JSON output.
---@param pattern string
---@param remote string
---@param on_finished fun(results: table)
local function search_async(pattern, remote, on_finished)
  if search_started then
    vim.notify("A search is already in progress. Please wait.", vim.log.levels.WARN)
    return
  end

  search_started = true
  conan_status.start("🔍 Conan: search " .. pattern)

  vim.system({ "conan", "search", pattern, "-r=" .. remote, "-f=json", "-v=quiet" }, { text = true }, function(res)
    vim.schedule(function()
      conan_status.stop()
      search_started = false

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
  end)
end

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

---@param pattern string
---@param results table
local function open_search_picker(pattern, results)
  local refs, by_ref, all_remotes, remote_errors = build_index(results)
  local recipe_path = recipe_editor.resolve_configured_recipe(common.read_config(), vim.fn.getcwd())
  local options_cache = {}
  local current_preview_key

  local function first_available_remote(reference)
    local available = by_ref[reference] or {}
    for _, remote in ipairs(all_remotes) do
      if available[remote] and not remote_errors[remote] then
        return remote
      end
    end
    return nil
  end

  local function render_preview(buffer, entry, options_state)
    if not vim.api.nvim_buf_is_valid(buffer) or not vim.api.nvim_buf_is_loaded(buffer) then
      return
    end

    local lines = { ("Recipe: %s"):format(entry.value), "" }
    for _, remote in ipairs(all_remotes) do
      local remote_error = remote_errors[remote]
      if remote_error then
        table.insert(lines, ("  ⚠️  %s: %s"):format(remote, remote_error))
      else
        local available = entry.present[remote] == true
        table.insert(lines, ("  %s  %s"):format(available and "✅" or "—", remote))
      end
    end

    table.insert(lines, "")
    vim.list_extend(lines, graph_options.format_section(options_state))
    table.insert(lines, "")
    table.insert(lines, "Actions:")
    table.insert(lines, "  <Enter>  copy ref to clipboard")
    table.insert(lines, "  <C-i>    insert ref at cursor")
    if recipe_path then
      table.insert(lines, "  <C-r>    add to requirements")
      table.insert(lines, "  <C-t>    add to build_requirements")
      if options_state and options_state.status == "ready" and options_state.options and #options_state.options > 0 then
        table.insert(lines, "  <C-o>    add options to default_options")
      end
    end

    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    vim.bo[buffer].filetype = "markdown"
  end

  local function load_options(buffer, entry)
    current_preview_key = entry.value .. "\0"
    local remote = first_available_remote(entry.value)
    if not remote then
      render_preview(buffer, entry, { status = "error", error = "no available remote" })
      return
    end

    local key = entry.value .. "\0" .. remote
    current_preview_key = key
    local state = options_cache[key]
    if state then
      render_preview(buffer, entry, state)
      return
    end

    state = { status = "pending" }
    options_cache[key] = state
    render_preview(buffer, entry, state)

    vim.defer_fn(function()
      if state.status ~= "pending" then
        return
      end
      if current_preview_key ~= key then
        options_cache[key] = nil
        return
      end

      state.status = "loading"
      render_preview(buffer, entry, state)
      vim.system(graph_options.command(entry.value, remote), { text = true }, function(response)
        local options, options_error
        if response.code == 0 then
          options, options_error = graph_options.parse(response.stdout or "", entry.value)
        else
          options_error = vim.trim(response.stderr or "")
          if options_error == "" then
            options_error = "conan graph info exited with code " .. tostring(response.code)
          end
        end

        vim.schedule(function()
          if options then
            state.status = "ready"
            state.options = options
          else
            state.status = "error"
            state.error = options_error
          end
          if current_preview_key == key then
            render_preview(buffer, entry, state)
          end
        end)
      end)
    end, 150)
  end

  if #refs == 0 then
    local any_error = false
    for _, remote in ipairs(all_remotes) do
      if remote_errors[remote] then
        any_error = true
        break
      end
    end

    if any_error then
      local lines = { ("No recipes found for: %s"):format(pattern), "", "Remote errors:" }
      for _, remote in ipairs(all_remotes) do
        if remote_errors[remote] then
          table.insert(lines, ("  ⚠️  %s: %s"):format(remote, remote_errors[remote]))
        end
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN)
    else
      vim.notify(("No recipes found for: %s"):format(pattern), vim.log.levels.WARN)
    end
    return
  end

  pickers
    .new({}, {
      prompt_title = "Conan search: " .. pattern,
      finder = finders.new_table({
        results = refs,
        entry_maker = function(ref)
          local present = by_ref[ref] or {}
          local count = 0
          for _ in pairs(present) do
            count = count + 1
          end
          return {
            value = ref,
            ordinal = ref,
            display = string.format("%-30s  (%d)", ref, count),
            present = present,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry)
          load_options(self.state.bufnr, entry)
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
          local entry = get_entry()
          actions.close(prompt_bufnr)
          if not entry or not entry.value then
            return
          end
          vim.fn.setreg("+", entry.value)
          vim.notify(("Copied: %s"):format(entry.value), vim.log.levels.INFO)
        end)

        map({ "i", "n" }, "<C-i>", function()
          local entry = get_entry()
          actions.close(prompt_bufnr)
          if not entry or not entry.value then
            return
          end
          vim.api.nvim_put({ entry.value }, "c", true, true)
        end)

        local function add_to_recipe(method_name)
          local entry = get_entry()
          actions.close(prompt_bufnr)
          if not entry or not entry.value then
            return
          end

          local call_ok, result, update_error = pcall(recipe_editor.update, recipe_path, entry.value, method_name)
          if not call_ok then
            vim.notify("Could not update Conan recipe: " .. tostring(result), vim.log.levels.ERROR)
            return
          end
          if not result then
            vim.notify("Could not update Conan recipe: " .. tostring(update_error), vim.log.levels.ERROR)
            return
          end
          if result.already_present then
            vim.notify(entry.value .. " is already present in " .. method_name, vim.log.levels.INFO)
            return
          end

          local location = result.location == "buffer" and " (unsaved buffer)" or ""
          vim.notify("Added " .. entry.value .. " to " .. method_name .. location, vim.log.levels.INFO)
        end

        local function add_options_to_recipe()
          local entry = get_entry()
          if not entry or not entry.value then
            return
          end

          local remote = first_available_remote(entry.value)
          local state = remote and options_cache[entry.value .. "\0" .. remote] or nil
          if not state or state.status == "pending" or state.status == "loading" then
            vim.notify("Conan options are still loading", vim.log.levels.INFO)
            return
          end
          if state.status ~= "ready" then
            vim.notify("Conan options are unavailable", vim.log.levels.WARN)
            return
          end
          if not state.options or #state.options == 0 then
            vim.notify("The selected recipe does not expose any options", vim.log.levels.INFO)
            return
          end

          actions.close(prompt_bufnr)
          local call_ok, result, update_error =
            pcall(recipe_editor.update_default_options, recipe_path, entry.value, state.options)
          if not call_ok then
            vim.notify("Could not update Conan recipe: " .. tostring(result), vim.log.levels.ERROR)
            return
          end
          if not result then
            vim.notify("Could not update Conan recipe: " .. tostring(update_error), vim.log.levels.ERROR)
            return
          end
          if not result.changed then
            vim.notify("All options are already present in default_options", vim.log.levels.INFO)
            return
          end

          local location = result.location == "buffer" and " (unsaved buffer)" or ""
          local skipped = result.skipped_count > 0 and (", preserved " .. result.skipped_count .. " existing") or ""
          vim.notify(
            "Added " .. result.added_count .. " option(s) to default_options" .. skipped .. location,
            vim.log.levels.INFO
          )
        end

        if recipe_path then
          map({ "i", "n" }, "<C-r>", function()
            add_to_recipe("requirements")
          end)
          map({ "i", "n" }, "<C-t>", function()
            add_to_recipe("build_requirements")
          end)
          map({ "i", "n" }, "<C-o>", add_options_to_recipe)
        end

        return true
      end,
    })
    :find()
end

--- Entry point for `:Conan search <pattern> [remote]`.
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

return M
