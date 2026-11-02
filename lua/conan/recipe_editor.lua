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

local function python_string(value)
  value = tostring(value)
  value = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
  return '"' .. value .. '"'
end

local function python_option_value(value)
  value = tostring(value)
  if value == "True" or value == "False" or value == "None" then
    return value
  end
  return python_string(value)
end

local function dependency_default_options(reference, options)
  local reference_ok, reference_error = validate_reference(reference)
  if not reference_ok then
    return nil, reference_error
  end

  local package_name = reference:match("^([^/]+)/")
  if not package_name or not package_name:match("^[%w_.+%-]+$") then
    return nil, "could not determine a safe package name from the reference"
  end
  if type(options) ~= "table" or #options == 0 then
    return nil, "the selected recipe does not expose any options"
  end

  local entries = {}
  local seen = {}
  for _, option in ipairs(options) do
    if type(option) ~= "table" or type(option.name) ~= "string" or option.name == "" or option.value == nil then
      return nil, "Conan returned a malformed option"
    end
    if option.name:find("[%c\"'\\]") then
      return nil, "Conan returned an option name that cannot be inserted safely"
    end

    local key = package_name .. "/*:" .. option.name
    if not seen[key] then
      seen[key] = true
      entries[#entries + 1] = {
        key = key,
        value = python_option_value(option.value),
      }
    end
  end
  table.sort(entries, function(left, right)
    return left.key < right.key
  end)
  return entries
end

local function find_first_method(lines, recipe_class, member_indentation)
  for index = recipe_class.first + 1, recipe_class.last - 1 do
    if not is_ignored(lines[index]) and leading_whitespace(lines[index]) == member_indentation then
      local declaration = declaration_without_comment(lines[index])
      if declaration:match("^def%s+") or declaration:match("^async%s+def%s+") then
        local first = index
        while first > recipe_class.first + 1 do
          local previous = lines[first - 1]
          local previous_content = trim(previous)
          if
            leading_whitespace(previous) == member_indentation
            and (previous_content:match("^@") or previous_content:match("^#"))
          then
            first = first - 1
          else
            break
          end
        end
        return first
      end
    end
  end
  return nil
end

local function scan_dictionary(lines, first, last, open_column)
  local depth = 0
  local quote
  local escaped = false

  for line_index = first, last do
    local line = lines[line_index]
    local column = line_index == first and open_column or 1
    while column <= #line do
      local character = line:sub(column, column)
      if quote then
        if escaped then
          escaped = false
        elseif character == "\\" then
          escaped = true
        elseif character == quote then
          quote = nil
        end
      elseif character == "#" then
        break
      elseif character == '"' or character == "'" then
        if line:sub(column, column + 2) == character .. character .. character then
          return nil, "triple-quoted strings in default_options are not supported"
        end
        quote = character
      elseif character == "{" then
        depth = depth + 1
      elseif character == "}" then
        depth = depth - 1
        if depth == 0 then
          local remainder = trim(line:sub(column + 1):gsub("%s+#.*$", ""))
          if remainder ~= "" then
            return nil, "unsupported content after the default_options dictionary"
          end
          return { first = first, last = line_index, open_column = open_column, close_column = column }
        end
      end
      column = column + 1
    end
    if quote then
      return nil, "unterminated string in default_options"
    end
  end
  return nil, "unterminated default_options dictionary"
end

local function find_default_options(lines, recipe_class, member_indentation)
  local found
  local index = recipe_class.first + 1
  while index < recipe_class.last do
    local line = lines[index]
    if not is_ignored(line) and leading_whitespace(line) == member_indentation then
      local declaration = declaration_without_comment(line)
      if declaration:match("^default_options%s*=") then
        if found then
          return nil, "recipe contains more than one default_options assignment"
        end
        local equals = line:find("=", 1, true)
        local open_column = equals and line:find("{", equals + 1, true)
        if not open_column or trim(line:sub(equals + 1, open_column - 1)) ~= "" then
          return nil, "default_options must be a Python dictionary literal"
        end
        local block, block_error = scan_dictionary(lines, index, recipe_class.last - 1, open_column)
        if not block then
          return nil, block_error
        end
        found = block
        index = block.last
      end
    end
    index = index + 1
  end
  return found
end

local function dictionary_has_key(lines, block, key)
  local key_pattern = "[\"']" .. pattern_escape(key) .. "[\"']%s*:"
  for index = block.first, block.last do
    if lines[index]:match(key_pattern) then
      return true
    end
  end
  return false
end

local function append_comma(line)
  local code, comment = line:match("^(.-)(%s+#.*)$")
  code = code or line
  comment = comment or ""
  if trim(code):sub(-1) ~= "," then
    code = code .. ","
  end
  return code .. comment
end

local function add_entries_to_dictionary(lines, block, member_indentation, entries)
  local missing = {}
  for _, entry in ipairs(entries) do
    if not dictionary_has_key(lines, block, entry.key) then
      missing[#missing + 1] = entry
    end
  end
  if #missing == 0 then
    return block, 0
  end

  if block.first == block.last then
    local line = lines[block.first]
    local content = trim(line:sub(block.open_column + 1, block.close_column - 1))
    local additions = {}
    for _, entry in ipairs(missing) do
      additions[#additions + 1] = python_string(entry.key) .. ": " .. entry.value
    end
    local separator = ""
    if content ~= "" then
      separator = content:sub(-1) == "," and " " or ", "
    end
    lines[block.first] = line:sub(1, block.close_column - 1)
      .. separator
      .. table.concat(additions, ", ")
      .. line:sub(block.close_column)
    block.close_column = block.close_column + #separator + #table.concat(additions, ", ")
    return block, #missing
  end

  local last_content
  for index = block.last - 1, block.first, -1 do
    local content = lines[index]
    if index == block.first then
      content = content:sub(block.open_column + 1)
    end
    if trim(content) ~= "" and not content:match("^%s*#") then
      last_content = index
      break
    end
  end
  if last_content then
    lines[last_content] = append_comma(lines[last_content])
  end

  local entry_indentation
  for index = block.first + 1, block.last - 1 do
    if not is_ignored(lines[index]) then
      local indentation = leading_whitespace(lines[index])
      if is_deeper(indentation, member_indentation) then
        entry_indentation = indentation
        break
      end
    end
  end
  entry_indentation = entry_indentation or (member_indentation .. member_indentation)

  for offset, entry in ipairs(missing) do
    table.insert(
      lines,
      block.last + offset - 1,
      entry_indentation .. python_string(entry.key) .. ": " .. entry.value .. ","
    )
  end
  block.last = block.last + #missing
  return block, #missing
end

local function default_options_insertion_index(lines, recipe_class, member_indentation)
  local insertion_index = find_first_method(lines, recipe_class, member_indentation) or recipe_class.last
  while insertion_index > recipe_class.first + 1 and is_blank(lines[insertion_index - 1]) do
    insertion_index = insertion_index - 1
  end
  return insertion_index
end

---Add dependency option values as recipe-level `default_options`.
---@param source string
---@param reference string
---@param options table[] Sorted `{ name, value }` entries from Conan graph info.
---@return string|nil updated_source
---@return table|string result Metadata on success, error string on failure.
function M.add_default_options(source, reference, options)
  if type(source) ~= "string" then
    return nil, "recipe source must be a string"
  end
  local entries, entries_error = dependency_default_options(reference, options)
  if not entries then
    return nil, entries_error
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

  local block, block_error = find_default_options(lines, recipe_class, member_indentation)
  if block_error then
    return nil, block_error
  end

  local added_count = #entries
  if block then
    block, added_count = add_entries_to_dictionary(lines, block, member_indentation, entries)
  else
    local insertion_index = default_options_insertion_index(lines, recipe_class, member_indentation)
    local additions = { member_indentation .. "default_options = {" }
    for _, entry in ipairs(entries) do
      additions[#additions + 1] = member_indentation
        .. member_indentation
        .. python_string(entry.key)
        .. ": "
        .. entry.value
        .. ","
    end
    additions[#additions + 1] = member_indentation .. "}"
    if insertion_index <= #lines and not is_blank(lines[insertion_index]) then
      additions[#additions + 1] = ""
    end
    insert_lines(lines, insertion_index, additions)
    block = { first = insertion_index, last = insertion_index + #additions - 1 }
    if additions[#additions] == "" then
      block.last = block.last - 1
    end
  end

  recipe_class = assert(find_recipe_class(lines))
  block = assert(find_default_options(lines, recipe_class, member_indentation))
  local block_lines = {}
  for index = block.last, block.first, -1 do
    table.insert(block_lines, 1, table.remove(lines, index))
  end

  recipe_class = assert(find_recipe_class(lines))
  local insertion_index = default_options_insertion_index(lines, recipe_class, member_indentation)
  if insertion_index <= #lines and not is_blank(lines[insertion_index]) then
    block_lines[#block_lines + 1] = ""
  end
  insert_lines(lines, insertion_index, block_lines)

  local updated = table.concat(lines, newline)
  return updated,
    {
      changed = updated ~= source,
      added_count = added_count,
      skipped_count = #entries - added_count,
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

local function update_source(path, transform)
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

  local updated, result = transform(source)
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

---Update requirement methods in a recipe on disk or in its loaded Neovim buffer.
---@param path string
---@param reference string
---@param method_name "requirements"|"build_requirements"
---@return table|nil result
---@return string|nil error
function M.update(path, reference, method_name)
  return update_source(path, function(source)
    return M.add(source, reference, method_name)
  end)
end

---Update dependency `default_options` in a recipe on disk or in its loaded Neovim buffer.
---@param path string
---@param reference string
---@param options table[]
---@return table|nil result
---@return string|nil error
function M.update_default_options(path, reference, options)
  return update_source(path, function(source)
    return M.add_default_options(source, reference, options)
  end)
end

return M
