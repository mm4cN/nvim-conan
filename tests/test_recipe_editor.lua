local test_set = MiniTest.new_set()
local expect = MiniTest.expect
local recipe_editor = require("conan.recipe_editor")

local function add(source, reference, method_name)
  local updated, result = recipe_editor.add(source, reference, method_name)
  if not updated then
    error(result)
  end
  return updated, result
end

local function write_file(path, content)
  local file = assert(io.open(path, "wb"))
  assert(file:write(content))
  assert(file:close())
end

local function read_file(path)
  local file = assert(io.open(path, "rb"))
  local content = assert(file:read("*a"))
  assert(file:close())
  return content
end

test_set["appends requires as the final requirements statement"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    name = "demo"

    def requirements(self):
        self.requires("fmt/11.0.2")
        if self.options.shared:
            self.requires("zlib/1.3.1")

    def build(self):
        pass
]]
  local expected = [[from conan import ConanFile

class DemoConan(ConanFile):
    name = "demo"

    def requirements(self):
        self.requires("fmt/11.0.2")
        if self.options.shared:
            self.requires("zlib/1.3.1")
        self.requires("openssl/3.3.2")

    def build(self):
        pass
]]

  local updated, result = add(source, "openssl/3.3.2", "requirements")

  expect.equality(updated, expected)
  expect.equality(result.changed, true)
  expect.equality(result.method_created, false)
end

test_set["appends tool_requires to an existing annotated build_requirements method"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    def build_requirements(self) -> None:
        self.tool_requires("cmake/3.30.1")
]]
  local expected = [[from conan import ConanFile

class DemoConan(ConanFile):
    def build_requirements(self) -> None:
        self.tool_requires("cmake/3.30.1")
        self.tool_requires("ninja/1.12.1")
]]

  local updated = add(source, "ninja/1.12.1", "build_requirements")

  expect.equality(updated, expected)
end

test_set["creates a missing requirements method at the end of the recipe class"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    name = "demo"

    def build(self):
        pass


def helper():
    pass
]]
  local expected = [[from conan import ConanFile

class DemoConan(ConanFile):
    name = "demo"

    def build(self):
        pass

    def requirements(self):
        self.requires("fmt/11.0.2")


def helper():
    pass
]]

  local updated, result = add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, expected)
  expect.equality(result.method_created, true)
end

test_set["creates both missing requirement methods with the correct Conan calls"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    name = "demo"
]]
  local with_requirements = add(source, "fmt/11.0.2", "requirements")
  local updated = add(with_requirements, "cmake/3.30.1", "build_requirements")
  local expected = [[from conan import ConanFile

class DemoConan(ConanFile):
    name = "demo"

    def requirements(self):
        self.requires("fmt/11.0.2")

    def build_requirements(self):
        self.tool_requires("cmake/3.30.1")
]]

  expect.equality(updated, expected)
end

test_set["preserves CRLF line endings and tab indentation"] = function()
  local source = table.concat({
    "from conan import ConanFile",
    "",
    "class DemoConan(ConanFile):",
    '\tname = "demo"',
    "",
  }, "\r\n")
  local expected = table.concat({
    "from conan import ConanFile",
    "",
    "class DemoConan(ConanFile):",
    '\tname = "demo"',
    "",
    "\tdef requirements(self):",
    '\t\tself.requires("fmt/11.0.2")',
    "",
  }, "\r\n")

  local updated = add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, expected)
end

test_set["does not add a duplicate reference"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    def requirements(self):
        self.requires( 'fmt/11.0.2', transitive_headers=True)
]]

  local updated, result = add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, source)
  expect.equality(result.changed, false)
  expect.equality(result.already_present, true)
end

test_set["rejects a recipe without a ConanFile class without changing it"] = function()
  local source = [[class NotARecipe:
    pass
]]
  local updated, err = recipe_editor.add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, nil)
  expect.equality(err:find("ConanFile", 1, true) ~= nil, true)
  expect.equality(
    source,
    [[class NotARecipe:
    pass
]]
  )
end

test_set["rejects ambiguous recipes with multiple ConanFile classes"] = function()
  local source = [[from conan import ConanFile

class First(ConanFile):
    pass

class Second(ConanFile):
    pass
]]
  local updated, err = recipe_editor.add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, nil)
  expect.equality(err:find("more than one", 1, true) ~= nil, true)
end

test_set["rejects a malformed target method instead of creating a duplicate"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    def requirements(self, profile):
        pass
]]
  local updated, err = recipe_editor.add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, nil)
  expect.equality(err:find("malformed", 1, true) ~= nil, true)
end

test_set["rejects an async target method instead of creating a duplicate"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    async def requirements(self):
        pass
]]
  local updated, err = recipe_editor.add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, nil)
  expect.equality(err:find("malformed", 1, true) ~= nil, true)
end

test_set["rejects an existing target method without a body"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    def requirements(self):

    def build(self):
        pass
]]
  local updated, err = recipe_editor.add(source, "fmt/11.0.2", "requirements")

  expect.equality(updated, nil)
  expect.equality(err:find("no body", 1, true) ~= nil, true)
end

test_set["rejects references that could break generated Python syntax"] = function()
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    pass
]]

  for _, reference in ipairs({ 'bad/1.0"', 'bad/1.0\nself.requires("evil/1.0")' }) do
    local updated = recipe_editor.add(source, reference, "requirements")
    expect.equality(updated, nil)
  end
end

test_set["updates a recipe file atomically when it is not loaded"] = function()
  local directory = vim.fn.tempname()
  local path = directory .. "/conanfile.py"
  vim.fn.mkdir(directory, "p")
  local source = [[from conan import ConanFile

class DemoConan(ConanFile):
    pass
]]
  write_file(path, source)

  local result, err = recipe_editor.update(path, "fmt/11.0.2", "requirements")

  expect.equality(err, nil)
  expect.equality(result.changed, true)
  expect.equality(result.location, "file")
  expect.equality(read_file(path):find('self.requires("fmt/11.0.2")', 1, true) ~= nil, true)
  expect.equality(#vim.fn.glob(path .. ".nvim-conan.*", false, true), 0)
  vim.fn.delete(directory, "rf")
end

test_set["resolves only an existing configured Python recipe"] = function()
  local directory = vim.fn.tempname()
  local path = directory .. "/recipes/conanfile.py"
  vim.fn.mkdir(directory .. "/recipes", "p")
  write_file(path, "")

  local resolved, err = recipe_editor.resolve_configured_recipe({ recipe = "recipes/conanfile.py" }, directory)
  local text_path, text_error = recipe_editor.resolve_configured_recipe({ recipe = "conanfile.txt" }, directory)
  local missing_path, missing_error = recipe_editor.resolve_configured_recipe({ recipe = "missing.py" }, directory)

  expect.equality(err, nil)
  expect.equality(resolved, vim.fs.normalize(path))
  expect.equality(text_path, nil)
  expect.equality(text_error:find("not a Python recipe", 1, true) ~= nil, true)
  expect.equality(missing_path, nil)
  expect.equality(missing_error:find("does not exist", 1, true) ~= nil, true)
  vim.fn.delete(directory, "rf")
end

test_set["updates a loaded recipe buffer without overwriting its unsaved content"] = function()
  local directory = vim.fn.tempname()
  local path = directory .. "/conanfile.py"
  vim.fn.mkdir(directory, "p")
  local disk_source = [[from conan import ConanFile

class DemoConan(ConanFile):
    name = "disk"
]]
  write_file(path, disk_source)

  local buffer = vim.fn.bufadd(path)
  vim.bo[buffer].swapfile = false
  vim.fn.bufload(buffer)
  vim.api.nvim_buf_set_lines(buffer, 3, 4, false, { '    name = "unsaved"' })

  local result, err = recipe_editor.update(path, "fmt/11.0.2", "requirements")
  local buffer_source = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")

  expect.equality(err, nil)
  expect.equality(result.location, "buffer")
  expect.equality(buffer_source:find('name = "unsaved"', 1, true) ~= nil, true)
  expect.equality(buffer_source:find('self.requires("fmt/11.0.2")', 1, true) ~= nil, true)
  expect.equality(read_file(path), disk_source)

  vim.api.nvim_buf_delete(buffer, { force = true })
  vim.fn.delete(directory, "rf")
end

return test_set
