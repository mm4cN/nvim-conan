local M = {}

local supported_methods = {
  requirements = "requires",
  build_requirements = "tool_requires",
}

local function trim(value)
  return value:match("^%s*(.-)%s*$")
end

local function split_lines(source)
  local newline = source:find("\r\n", 1, true) and "\r\n" or "\n"
  local normalized = source:gsub("\r\n", "\n")
  if normalized:find("\r", 1, true) then
    return nil, nil, "unsupported carriage return in recipe"
  end

  local lines = {}
  local start = 1
  while true do
    local newline_at = normalized:find("\n", start, true)
    if not newline_at then
      lines[#lines + 1] = normalized:sub(start)
      break
    end
    lines[#lines + 1] = normalized:sub(start, newline_at - 1)
    start = newline_at + 1
  end
  return lines, newline
end

local function leading_whitespace(line)
  return line:match("^([ \t]*)")
end

local function is_blank(line)
  return line:match("^%s*$") ~= nil
end

local function is_ignored(line)
  return is_blank(line) or line:match("^%s*#") ~= nil
end

local function is_deeper(indentation, parent)
  return #indentation > #parent and indentation:sub(1, #parent) == parent
end

local function indentation_kind(indentation)
  local has_spaces = indentation:find(" ", 1, true) ~= nil
  local has_tabs = indentation:find("\t", 1, true) ~= nil
  if has_spaces and has_tabs then
    return nil
  end
  return has_tabs and "tabs" or "spaces"
end

local function declaration_without_comment(line)
  return trim((line:gsub("%s+#.*$", "")))
end

local function has_conanfile_base(bases)
  for base in bases:gmatch("[%a_][%w_%.]*") do
    if base == "ConanFile" or base:match("%.ConanFile$") then
      return true
    end
  end
  return false
end

local function find_recipe_class(lines)
  local class_line
  for index, line in ipairs(lines) do
    if leading_whitespace(line) == "" then
      local declaration = declaration_without_comment(line)
      local bases = declaration:match("^class%s+[%a_][%w_]*%s*%((.*)%)%s*:$")
      if bases and has_conanfile_base(bases) then
        if class_line then
          return nil, "recipe contains more than one top-level ConanFile class"
        end
        class_line = index
      end
    end
  end

  if not class_line then
    return nil, "could not find a top-level class inheriting from ConanFile"
  end

  local class_end = #lines + 1
  for index = class_line + 1, #lines do
    if not is_ignored(lines[index]) and leading_whitespace(lines[index]) == "" then
      class_end = index
      break
    end
  end

  return { first = class_line, last = class_end }
end

local function find_member_indentation(lines, recipe_class)
  local member_indentation
  local member_kind

  for index = recipe_class.first + 1, recipe_class.last - 1 do
    local line = lines[index]
    if not is_ignored(line) then
      local indentation = leading_whitespace(line)
      if indentation == "" then
        return nil, "recipe class contains an unindented statement"
      end

      local kind = indentation_kind(indentation)
      if not kind then
        return nil, "recipe uses mixed tabs and spaces for indentation"
      end
      if member_kind and member_kind ~= kind then
        return nil, "recipe mixes tab and space indentation"
      end
      member_kind = member_kind or kind

      if not member_indentation or #indentation < #member_indentation then
        member_indentation = indentation
      end
    end
  end

  if not member_indentation then
    return nil, "ConanFile class has no body"
  end
  return member_indentation
end

local function find_method(lines, recipe_class, member_indentation, method_name)
  local method_line

  for index = recipe_class.first + 1, recipe_class.last - 1 do
    local line = lines[index]
    if not is_ignored(line) and leading_whitespace(line) == member_indentation then
      local declaration = declaration_without_comment(line)
      if declaration:match("^async%s+def%s+" .. method_name .. "%s*%(") then
        return nil, "unsupported or malformed " .. method_name .. " method declaration"
      end
      local declared_name = declaration:match("^def%s+([%a_][%w_]*)")
      if declared_name == method_name then
        local arguments = declaration:match("^def%s+" .. method_name .. "%s*%((.-)%)%s*.-%s*:$")
        if not arguments or trim(arguments) ~= "self" then
          return nil, "unsupported or malformed " .. method_name .. " method declaration"
        end
        if method_line then
          return nil, "recipe contains more than one " .. method_name .. " method"
        end
        method_line = index
      end
    end
  end

  return method_line
end

local function find_method_body(lines, recipe_class, method_line, member_indentation)
  local method_end = recipe_class.last
  for index = method_line + 1, recipe_class.last - 1 do
    if not is_ignored(lines[index]) then
      local indentation = leading_whitespace(lines[index])
      if not is_deeper(indentation, member_indentation) then
        method_end = index
        break
      end
    end
  end

  local body_indentation
  for index = method_line + 1, method_end - 1 do
    if not is_ignored(lines[index]) then
      local indentation = leading_whitespace(lines[index])
      if not is_deeper(indentation, member_indentation) then
        return nil, nil, "malformed indentation in method body"
      end
      if indentation_kind(indentation) ~= indentation_kind(member_indentation) then
        return nil, nil, "method body mixes tab and space indentation"
      end
      if not body_indentation or #indentation < #body_indentation then
        body_indentation = indentation
      end
    end
  end

  if not body_indentation then
    return nil, nil, "existing method has no body"
  end
  return method_end, body_indentation
end

local function pattern_escape(value)
  return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function already_contains(lines, first, last, call_name, reference)
  local reference_pattern = pattern_escape(reference)
  local call_pattern = "^%s*self%." .. call_name .. "%s*%(%s*[\"']" .. reference_pattern .. "[\"']"
  for index = first, last do
    if lines[index]:match(call_pattern) then
      return true
    end
  end
  return false
end

local function insert_lines(lines, index, additions)
  for offset, line in ipairs(additions) do
    table.insert(lines, index + offset - 1, line)
  end
end

local function validate_reference(reference)
  if type(reference) ~= "string" or reference == "" then
    return nil, "package reference must be a non-empty string"
  end
  if reference:find("[%c\"'\\]") then
    return nil, "package reference contains characters that cannot be inserted safely"
  end
  return true
end

local function is_absolute_path(path)
  return path:sub(1, 1) == "/" or path:match("^%a:[/\\]") ~= nil or path:sub(1, 2) == "\\\\"
end

---Add a Conan requirement call to Python recipe source.
---@param source string
---@param reference string
---@param method_name "requirements"|"build_requirements"
---@return string|nil updated_source
---@return table|string result Metadata on success, error string on failure.
function M.add(source, reference, method_name)
  if type(source) ~= "string" then
    return nil, "recipe source must be a string"
  end
  local call_name = supported_methods[method_name]
  if not call_name then
    return nil, "unsupported requirement method: " .. tostring(method_name)
  end
  local reference_ok, reference_error = validate_reference(reference)
  if not reference_ok then
    return nil, reference_error
  end

  local lines, newline, split_error = split_lines(source)
  if not lines then
    return nil, split_error
  end
  local recipe_class, class_error = find_recipe_class(lines)
  if not recipe_class then
    return nil, class_error
  end
  local member_indentation, indentation_error = find_member_indentation(lines, recipe_class)
  if not member_indentation then
    return nil, indentation_error
  end
  local method_line, method_error = find_method(lines, recipe_class, member_indentation, method_name)
  if method_error then
    return nil, method_error
  end

  local method_created = false
  if method_line then
    local method_end, body_indentation, body_error =
      find_method_body(lines, recipe_class, method_line, member_indentation)
    if not method_end then
      return nil, body_error
    end
    if already_contains(lines, method_line + 1, method_end - 1, call_name, reference) then
      return source, { changed = false, already_present = true, method_created = false }
    end

    local insertion_index = method_end
    while insertion_index > method_line + 1 and is_blank(lines[insertion_index - 1]) do
      insertion_index = insertion_index - 1
    end
    table.insert(lines, insertion_index, body_indentation .. "self." .. call_name .. '("' .. reference .. '")')
  else
    method_created = true
    local insertion_index = recipe_class.last
    while insertion_index > recipe_class.first + 1 and is_blank(lines[insertion_index - 1]) do
      insertion_index = insertion_index - 1
    end

    local indentation_unit = member_indentation
    local additions = {
      "",
      member_indentation .. "def " .. method_name .. "(self):",
      member_indentation .. indentation_unit .. "self." .. call_name .. '("' .. reference .. '")',
    }
    if insertion_index <= #lines and not is_blank(lines[insertion_index]) then
      additions[#additions + 1] = ""
    end
    insert_lines(lines, insertion_index, additions)
  end

  return table.concat(lines, newline),
    {
      changed = true,
      already_present = false,
      method_created = method_created,
    }
end

local function loaded_buffer_for(path)
  local real_path = vim.uv.fs_realpath(path)
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      local name = vim.api.nvim_buf_get_name(buffer)
      if name ~= "" then
        local normalized_name = vim.fs.normalize(name)
        if normalized_name == path or (real_path and vim.uv.fs_realpath(normalized_name) == real_path) then
          return buffer
        end
      end
    end
  end
  return nil
end

local function buffer_source(buffer)
  local source = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")
  if vim.bo[buffer].endofline then
    source = source .. "\n"
  end
  return source
end

local function set_buffer_source(buffer, source)
  local has_final_newline = source:sub(-1) == "\n"
  local lines = split_lines(source)
  if has_final_newline then
    table.remove(lines)
  end
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].endofline = has_final_newline
end

local function write_atomically(path, source, mode)
  local fd, temporary_path, create_error = vim.uv.fs_mkstemp(path .. ".nvim-conan.XXXXXX")
  if not fd then
    return nil, "could not create a temporary recipe: " .. tostring(create_error)
  end
  vim.uv.fs_close(fd)

  local file, open_error = io.open(temporary_path, "wb")
  if not file then
    vim.uv.fs_unlink(temporary_path)
    return nil, "could not open the temporary recipe: " .. tostring(open_error)
  end
  local written, write_error = file:write(source)
  local closed, close_error = file:close()
  if not written or not closed then
    vim.uv.fs_unlink(temporary_path)
    return nil, "could not write the temporary recipe: " .. tostring(write_error or close_error)
  end

  if mode then
    local permissions_set, permissions_error = vim.uv.fs_chmod(temporary_path, mode)
    if not permissions_set then
      vim.uv.fs_unlink(temporary_path)
      return nil, "could not preserve recipe permissions: " .. tostring(permissions_error)
    end
  end
  local replaced, replace_error = vim.uv.fs_rename(temporary_path, path)
  if not replaced then
    vim.uv.fs_unlink(temporary_path)
    return nil, "could not replace the recipe: " .. tostring(replace_error)
  end
  return true
end

---Resolve an existing configured Python recipe.
---@param config table|nil
---@param cwd string
---@return string|nil path
---@return string|nil error
function M.resolve_configured_recipe(config, cwd)
  if type(config) ~= "table" or type(config.recipe) ~= "string" or config.recipe == "" then
    return nil, "no recipe is selected in conan-config.json"
  end
  if not config.recipe:match("%.py$") then
    return nil, "the selected recipe is not a Python recipe"
  end

  local path = config.recipe
  if not is_absolute_path(path) then
    path = cwd .. "/" .. path
  end
  path = vim.fs.normalize(path)

  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil, "the selected Python recipe does not exist: " .. path
  end
  return path
end

---Update a recipe on disk or its loaded Neovim buffer.
---@param path string
---@param reference string
---@param method_name "requirements"|"build_requirements"
---@return table|nil result
---@return string|nil error
function M.update(path, reference, method_name)
  path = vim.fs.normalize(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil, "recipe does not exist: " .. path
  end

  local buffer = loaded_buffer_for(path)
  local source
  if buffer then
    source = buffer_source(buffer)
  else
    local file, open_error = io.open(path, "rb")
    if not file then
      return nil, "could not read recipe: " .. tostring(open_error)
    end
    source = file:read("*a")
    file:close()
  end

  local updated, result = M.add(source, reference, method_name)
  if not updated then
    return nil, result
  end
  result.path = path
  result.location = buffer and "buffer" or "file"
  if not result.changed then
    return result
  end

  if buffer then
    set_buffer_source(buffer, updated)
  else
    local written, write_error = write_atomically(path, updated, stat.mode)
    if not written then
      return nil, write_error
    end
  end
  return result
end

return M
