local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local command_builder = require("conan.command_builder")
local common = require("conan.commands.common")

--- Opens a Telescope flow: choose remote, choose cached ref, then upload.
function M.upload()
  local utils = require("utils")
  local remotes = utils.get_conan_remotes_from_cli()
  if #remotes == 0 then
    vim.notify("No remotes found from `conan remote list`.", vim.log.levels.WARN)
    return
  end

  pickers
    .new({}, {
      prompt_title = "Select Conan Remote",
      finder = finders.new_table({ results = remotes }),
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

          pickers
            .new({}, {
              prompt_title = "Select Package Ref",
              finder = finders.new_table({ results = refs }),
              sorter = conf.generic_sorter({}),
              attach_mappings = function(ref_bufnr)
                actions.select_default:replace(function()
                  actions.close(ref_bufnr)
                  local ref = action_state.get_selected_entry()[1]
                  local argv = command_builder.upload(ref, remote)

                  common.run_terminal_with_status(
                    ("📤 Conan: upload %s → %s"):format(ref, remote),
                    argv,
                    string.format("📦 Upload: %s → %s", ref, remote),
                    true
                  )
                end)
                return true
              end,
            })
            :find()
        end)
        return true
      end,
    })
    :find()
end

return M
