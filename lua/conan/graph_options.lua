local M = {}

local function recipe_reference(reference)
  return reference:match("^([^#]+)") or reference
end

---Build the command used to resolve option values for a recipe reference.
---@param reference string
---@param remote string
---@return string[]
function M.command(reference, remote)
  return {
    "conan",
    "graph",
    "info",
    "--requires=" .. reference,
    "-r=" .. remote,
    "--filter=options",
    "--format=json",
    "-vquiet",
  }
end

---Parse `conan graph info --format=json` output for the requested direct requirement.
---@param stdout string
---@param reference string
---@return table[]|nil options Sorted `{ name, value }` entries.
---@return string|nil error
function M.parse(stdout, reference)
  local decoded_ok, decoded = pcall(vim.json.decode, stdout)
  if not decoded_ok or type(decoded) ~= "table" then
    return nil, "Conan returned invalid JSON"
  end

  local graph = decoded.graph
  if type(graph) ~= "table" or type(graph.nodes) ~= "table" then
    return nil, "Conan graph output does not contain nodes"
  end
  if graph.error ~= nil and graph.error ~= vim.NIL and tostring(graph.error) ~= "" then
    return nil, "Conan graph error: " .. tostring(graph.error)
  end

  local requested_reference = recipe_reference(reference)
  local matching_node
  for _, node in pairs(graph.nodes) do
    if type(node) == "table" and type(node.ref) == "string" then
      local node_reference = recipe_reference(node.ref)
      if node_reference == requested_reference then
        if matching_node then
          return nil, "Conan graph contains more than one matching recipe node"
        end
        matching_node = node
      end
    end
  end

  if not matching_node then
    return nil, "Conan graph does not contain the selected recipe"
  end
  if matching_node.options ~= nil and type(matching_node.options) ~= "table" then
    return nil, "Conan graph contains malformed options"
  end

  local options = {}
  for name, value in pairs(matching_node.options or {}) do
    options[#options + 1] = { name = tostring(name), value = tostring(value) }
  end
  table.sort(options, function(left, right)
    return left.name < right.name
  end)
  return options
end

---Format the options block displayed in the search preview.
---@param state table|nil
---@return string[]
function M.format_section(state)
  local lines = { "Options:" }
  if not state or state.status == "pending" or state.status == "loading" then
    lines[#lines + 1] = "  loading..."
  elseif state.status == "error" then
    lines[#lines + 1] = "  unavailable"
  elseif not state.options or #state.options == 0 then
    lines[#lines + 1] = "  not specified"
  else
    for _, option in ipairs(state.options) do
      lines[#lines + 1] = ("  %s: %s"):format(option.name, option.value)
    end
  end
  return lines
end

return M
