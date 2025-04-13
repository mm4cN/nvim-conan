local M = {
  config_file = vim.fn.getcwd() .. "/" .. ".nvim-conan.json"
}

local reference = vim.fn.getcwd() .. "/conanfile.py"

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
  local config = read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
  end
  local cmd = string.format(
    "conan install %s -pr:b %s -pr:h %s --build=%s",
    reference,
    config.profile_build,
    config.profile_host,
    config.build_policy
  )
  local utils = require("utils")
  utils.open_floating_terminal(cmd, "📦 Conan Install")
end

M.build = function()
  local config = read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
  end
  local cmd = string.format(
    "conan build %s -pr:b %s -pr:h %s --build=%s",
    reference,
    config.profile_build,
    config.profile_host,
    config.build_policy
  )
  if vim.loop.fs_stat(vim.fn.getcwd() .. "/conan.lock") ~= nil then
    cmd = cmd .. " --lockfile=conan.lock"
  end
  local utils = require("utils")
  utils.open_floating_terminal(cmd, "🔨 Conan Build")
end

M.lock = function()
  local config = read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
  end
  local cmd = string.format(
    "conan lock create %s",
    reference
  )
  local utils = require("utils")
  utils.open_floating_terminal(cmd, "🔒 Conan Lock")
end

M.search = function(args)
  local package_name = args[1]
  local remote = args[2]

  if not package_name then
    vim.notify("❌ Package name is required for :Conan search", vim.log.levels.ERROR)
    return
  end

  local cmd = "conan search " .. package_name
  if remote then
    cmd = cmd .. " -r " .. remote
  end
  local utils = require("utils")
  utils.open_floating_terminal(cmd, "Conan Search: " .. package_name, false)
end

M.version = function()
end

M.create = function()
  local config = read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
  end

  local cmd = string.format(
    "conan create -pr:b %s -pr:h %s --build=%s %s",
    config.profile_build,
    config.profile_host,
    config.build_policy,
    reference
  )
  local utils = require("utils")
  utils.open_floating_terminal(cmd)
end

M.export = function(args)
  local user = args[1]
  local channel = args[2]

  local config = read_config()
  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
    return
  end

  local cmd = "conan export"

  if user then
    cmd = cmd .. " --user " .. user
  end

  if channel then
    cmd = cmd .. " --channel " .. channel
  end
  cmd = cmd .. " " .. reference

  local utils = require("utils")
  utils.open_floating_terminal(cmd, "Conan Export")
end

M.export_package = function(args)
  local user = args[1]
  local channel = args[2]
  local config = read_config()

  if config == nil then
    vim.notify("Couldn't read config", vim.log.levels.ERROR)
    return
  end

  local cmd = "conan export-pkg"
  if user then
    cmd = cmd .. string.format(" --user %s", user)
  end

  if channel then
    cmd = cmd .. string.format(" --channel %s", channel)
  end

  cmd = cmd .. " " .. reference
  local utils = require("utils")
  utils.open_floating_terminal(cmd, "Conan Export-Package")
end

M.upload = function()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
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
end

return M

