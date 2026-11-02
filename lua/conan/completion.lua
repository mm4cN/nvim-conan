local M = {}

local help_cache = {}
local remote_cache

local command_names = {
  create = "create",
  export = "export",
  export_package = "export-pkg",
}

local remote_flags = {
  ["-r"] = true,
  ["--remote"] = true,
}

local function starts_with(value, prefix)
  return value:sub(1, #prefix) == prefix
end

local function filtered(values, arg_lead)
  local matches = {}
  for _, value in ipairs(values) do
    if starts_with(value, arg_lead) then
      matches[#matches + 1] = value
    end
  end
  table.sort(matches)
  return matches
end

local function default_help_provider(command)
  local output = vim.fn.systemlist({ "conan", command, "--help" })
  if vim.v.shell_error ~= 0 then
    return ""
  end
  return table.concat(output, "\n")
end

local function default_remote_provider()
  return require("utils").get_conan_remotes_from_cli()
end

---Extract long option names from Conan command help.
---@param help string
---@return string[]
function M.parse_help(help)
  local seen = {}
  help = tostring(help)
  for option in help:gmatch("%-%-[%a][%w%-:]*") do
    seen[option] = true
  end
  for line in help:gmatch("[^\r\n]+") do
    local declaration = line:match("^%s+(.-)%s%s+")
    if declaration and declaration:sub(1, 1) == "-" then
      for option in declaration:gmatch("%-+[%a][%w%-:]*") do
        seen[option] = true
      end
    end
  end

  local options = {}
  for option in pairs(seen) do
    options[#options + 1] = option
  end
  table.sort(options)
  return options
end

---Parse the current `:Conan` command-line completion position.
---@param cmdline string
---@param cursor_position integer
---@return table|nil context
function M.context(cmdline, cursor_position)
  local before_cursor = cmdline:sub(1, cursor_position)
  local body = before_cursor:match("^['<,'>]*Conan[!]*%s+(.*)$")
  if not body then
    return nil
  end

  local trailing_space = body:match("%s$") ~= nil
  local tokens = {}
  for token in body:gmatch("%S+") do
    tokens[#tokens + 1] = token
  end
  if #tokens == 0 then
    return nil
  end

  local argument_index = trailing_space and #tokens or (#tokens - 1)
  local previous_argument
  if argument_index > 1 then
    previous_argument = trailing_space and tokens[#tokens] or tokens[#tokens - 1]
  end

  return {
    subcommand = tokens[1],
    argument_index = argument_index,
    previous_argument = previous_argument,
  }
end

local function command_flags(command, help_provider)
  if not help_cache[command] then
    help_cache[command] = M.parse_help(help_provider(command))
  end
  return help_cache[command]
end

local function remotes(remote_provider)
  if not remote_cache then
    remote_cache = remote_provider()
    table.sort(remote_cache)
  end
  return remote_cache
end

local function inline_remote_completion(arg_lead, remote_provider)
  local prefix, value_lead = arg_lead:match("^(%-%-remote=)(.*)$")
  if not prefix then
    prefix, value_lead = arg_lead:match("^(%-r=)(.*)$")
  end
  if not prefix then
    return nil
  end

  local matches = filtered(remotes(remote_provider), value_lead)
  for index, remote in ipairs(matches) do
    matches[index] = prefix .. remote
  end
  return matches
end

---Complete arguments for a Conan subcommand.
---@param context table
---@param arg_lead string
---@param providers? table Test/custom providers for help and remotes.
---@return string[]
function M.complete(context, arg_lead, providers)
  providers = providers or {}
  local help_provider = providers.help or default_help_provider
  local remote_provider = providers.remotes or default_remote_provider

  if context.subcommand == "search" and context.argument_index == 2 then
    local candidates = { "*" }
    vim.list_extend(candidates, remotes(remote_provider))
    return filtered(candidates, arg_lead)
  end
  if context.subcommand == "sbom" then
    if context.argument_index == 1 then
      return filtered({ "1.4", "1.6" }, arg_lead)
    end
    if context.argument_index == 2 then
      return vim.fn.getcompletion(arg_lead, "dir")
    end
    return {}
  end

  local command = command_names[context.subcommand]
  if not command then
    return {}
  end
  local inline_remotes = inline_remote_completion(arg_lead, remote_provider)
  if inline_remotes then
    return inline_remotes
  end
  if remote_flags[context.previous_argument] then
    return filtered(remotes(remote_provider), arg_lead)
  end
  if starts_with(arg_lead, "-") then
    return filtered(command_flags(command, help_provider), arg_lead)
  end
  return {}
end

---Clear cached help and remote data. Primarily useful after changing Conan installations/configuration.
function M.clear_cache()
  help_cache = {}
  remote_cache = nil
end

return M
