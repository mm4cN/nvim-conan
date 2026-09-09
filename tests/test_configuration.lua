local utils = require("utils")

local test_set = MiniTest.new_set()
local expect = MiniTest.expect

local function write_file(path, content)
  local file = assert(io.open(path, "w"))
  assert(file:write(content))
  assert(file:close())
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function has_notification(notifications, text)
  for _, notification in ipairs(notifications) do
    if notification.message:find(text, 1, true) then
      return true
    end
  end
  return false
end

local function run_wizard(method, inputs, opts)
  opts = opts or {}
  local originals = {
    pick_conan_profile = utils.pick_conan_profile,
    pick_recipe = utils.pick_recipe,
    write_json_file = utils.write_json_file,
    input = vim.ui.input,
    notify = vim.notify,
    cwd = vim.fn.getcwd(),
    fs_rename = vim.loop.fs_rename,
  }
  local test_dir = vim.fn.tempname()
  vim.fn.mkdir(test_dir, "p")
  vim.fn.chdir(test_dir)

  local config_path = test_dir .. "/" .. (opts.config_path or "conan-config.json")
  if opts.initial_content then
    vim.fn.mkdir(vim.fn.fnamemodify(config_path, ":h"), "p")
    write_file(config_path, opts.initial_content)
  end

  local notifications = {}
  local prompts = {}
  local profile_index = 0
  local input_index = 0
  local temporary_path

  utils.pick_recipe = function(_, callback)
    callback(opts.cancel_at == "recipe" and nil or "recipes/conanfile.py")
  end
  utils.pick_conan_profile = function(_, callback)
    profile_index = profile_index + 1
    if opts.cancel_at == "host_profile" and profile_index == 1 then
      callback(nil)
    elseif opts.cancel_at == "build_profile" and profile_index == 2 then
      callback(nil)
    else
      callback(profile_index == 1 and "host-profile" or "build-profile")
    end
  end
  utils.write_json_file = function(path, config)
    temporary_path = path
    if opts.write_failure then
      return false
    end
    return originals.write_json_file(path, config)
  end
  vim.ui.input = function(input_opts, callback)
    prompts[#prompts + 1] = input_opts.prompt
    input_index = input_index + 1
    callback(inputs[input_index])
  end
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end
  if opts.replace_failure then
    vim.loop.fs_rename = function(source)
      temporary_path = source
      return nil, "forced replacement failure"
    end
  end

  local ok, err = xpcall(utils[method], debug.traceback)
  local result = {
    config_path = config_path,
    content = read_file(config_path),
    notifications = notifications,
    prompts = prompts,
    temporary_path = temporary_path,
    temporary_exists = temporary_path ~= nil and utils.file_exists(temporary_path),
    root_config_exists = utils.file_exists(test_dir .. "/conan-config.json"),
  }

  utils.pick_conan_profile = originals.pick_conan_profile
  utils.pick_recipe = originals.pick_recipe
  utils.write_json_file = originals.write_json_file
  vim.ui.input = originals.input
  vim.notify = originals.notify
  vim.loop.fs_rename = originals.fs_rename
  vim.fn.chdir(originals.cwd)
  vim.fn.delete(test_dir, "rf")

  if not ok then
    error(err)
  end
  return result
end

local old_config = '{"version":"old","recipe":"old.py"}'

test_set["cancelling reconfiguration preserves the existing file"] = function()
  local cancellation_inputs = {
    build_policy = { nil },
    options = { "", nil },
    conf = { "", "", nil },
    lockfile = { "", "", "", nil },
  }

  for _, stage in ipairs({ "recipe", "host_profile", "build_profile" }) do
    local result = run_wizard("reconfigure", {}, { initial_content = old_config, cancel_at = stage })
    expect.equality(result.content, old_config)
    expect.equality(has_notification(result.notifications, "Configuration cancelled"), true)
  end

  for _, inputs in pairs(cancellation_inputs) do
    local result = run_wizard("reconfigure", inputs, { initial_content = old_config })
    expect.equality(result.content, old_config)
    expect.equality(has_notification(result.notifications, "Configuration cancelled"), true)
  end
end

test_set["successful reconfiguration replaces the existing file"] = function()
  local result = run_wizard("reconfigure", { "missing", "shared=True", "", "", "conan.lock" }, {
    initial_content = old_config,
  })
  local config = vim.json.decode(result.content)

  expect.equality(config.recipe, "recipes/conanfile.py")
  expect.equality(config.profile_host, "host-profile")
  expect.equality(config.profile_build, "build-profile")
  expect.equality(config.build_policy, "missing")
  expect.equality(config.options.shared, "True")
  expect.equality(config.lockfile, "conan.lock")
  expect.equality(has_notification(result.notifications, "Configured with host"), true)
end

test_set["temporary-file write failure preserves the existing file"] = function()
  local result = run_wizard("reconfigure", { "", "", "", "" }, {
    initial_content = old_config,
    write_failure = true,
  })

  expect.equality(result.content, old_config)
  expect.equality(result.temporary_exists, false)
  expect.equality(has_notification(result.notifications, "Failed to write temporary config"), true)
end

test_set["replacement failure preserves the existing file and removes the temporary file"] = function()
  local result = run_wizard("reconfigure", { "", "", "", "" }, {
    initial_content = old_config,
    replace_failure = true,
  })

  expect.equality(result.content, old_config)
  expect.equality(result.temporary_exists, false)
  expect.equality(has_notification(result.notifications, "Failed to replace config"), true)
end

test_set["first-time configuration creates a new file successfully"] = function()
  local result = run_wizard("configure", { "", "", "" })
  local config = vim.json.decode(result.content)

  expect.equality(config.recipe, "recipes/conanfile.py")
  expect.equality(config.build_policy, nil)
  expect.equality(#result.prompts, 3)
end

test_set["an existing vscode configuration is replaced in place"] = function()
  local result = run_wizard("reconfigure", { "", "", "", "" }, {
    config_path = ".vscode/conan-config.json",
    initial_content = old_config,
  })

  expect.equality(vim.json.decode(result.content).recipe, "recipes/conanfile.py")
  expect.equality(result.root_config_exists, false)
end

test_set["empty optional values continue while cancellation aborts"] = function()
  local empty = run_wizard("reconfigure", { "   ", "", "", "" }, { initial_content = old_config })
  local cancelled = run_wizard("reconfigure", { nil }, { initial_content = old_config })

  expect.equality(vim.json.decode(empty.content).build_policy, nil)
  expect.equality(has_notification(empty.notifications, "Configured with host"), true)
  expect.equality(cancelled.content, old_config)
  expect.equality(has_notification(cancelled.notifications, "Configuration cancelled"), true)
end

test_set["explicit reconfiguration stores a free-form build policy"] = function()
  local result = run_wizard("reconfigure", { " missing:zlib/* ", "", "", "" })

  expect.equality(vim.json.decode(result.content).build_policy, "missing:zlib/*")
end

return test_set
