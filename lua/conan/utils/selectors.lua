local M = {}

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

  local json_start
  for index, line in ipairs(output_lines) do
    if line:match("^%s*{") then
      json_start = index
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

  local cache = parsed["Local Cache"]
  if not cache then
    vim.notify("No 'Local Cache' section found in parsed output", vim.log.levels.WARN)
    return {}
  end

  local refs = {}
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
    callback(nil)
    return
  end

  pickers
    .new({}, {
      prompt_title = prompt,
      finder = finders.new_table({ results = profiles }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(bufnr)
        local finished = false
        actions.close:enhance({
          post = function()
            if not finished then
              finished = true
              callback(nil)
            end
          end,
        })
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()[1]
          finished = true
          actions.close(bufnr)
          callback(selection)
        end)
        return true
      end,
    })
    :find()
end

function M.pick_recipe(prompt, callback)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local recipes = vim.fn.glob(vim.fn.getcwd() .. "/conanfile*.py", false, true)
  pickers
    .new({}, {
      prompt_title = prompt,
      finder = finders.new_table({ results = recipes }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(bufnr)
        local finished = false
        actions.close:enhance({
          post = function()
            if not finished then
              finished = true
              callback(nil)
            end
          end,
        })
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()[1]
          finished = true
          actions.close(bufnr)
          callback(selection)
        end)
        return true
      end,
    })
    :find()
end

return M
