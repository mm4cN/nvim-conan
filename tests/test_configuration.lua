local utils = require("utils")

local test_set = MiniTest.new_set()
local expect = MiniTest.expect

local function run_wizard(method, inputs)
  local originals = {
    file_exists = utils.file_exists,
    pick_conan_profile = utils.pick_conan_profile,
    pick_recipe = utils.pick_recipe,
    write_json_file = utils.write_json_file,
    input = vim.ui.input,
    notify = vim.notify,
  }
  local notifications = {}
  local prompts = {}
  local saved_config
  local profile_index = 0
  local input_index = 0

  utils.file_exists = function()
    return false
  end
  utils.pick_recipe = function(_, callback)
    callback("recipes/conanfile.py")
  end
  utils.pick_conan_profile = function(_, callback)
    profile_index = profile_index + 1
    callback(profile_index == 1 and "host-profile" or "build-profile")
  end
  utils.write_json_file = function(_, config)
    saved_config = config
    return true
  end
  vim.ui.input = function(opts, callback)
    prompts[#prompts + 1] = opts.prompt
    input_index = input_index + 1
    callback(inputs[input_index])
  end
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end

  local ok, err = xpcall(utils[method], debug.traceback)

  utils.file_exists = originals.file_exists
  utils.pick_conan_profile = originals.pick_conan_profile
  utils.pick_recipe = originals.pick_recipe
  utils.write_json_file = originals.write_json_file
  vim.ui.input = originals.input
  vim.notify = originals.notify

  if not ok then
    error(err)
  end
  return saved_config, prompts
end

test_set["first-time setup neither prompts for nor stores a build policy"] = function()
  local config, prompts = run_wizard("configure", { "", "", "" })

  expect.equality(config.build_policy, nil)
  expect.equality(#prompts, 3)
  expect.equality(prompts[1]:find("options", 1, true) ~= nil, true)
end

test_set["explicit reconfiguration omits an empty build policy"] = function()
  local config, prompts = run_wizard("reconfigure", { "", "", "", "" })

  expect.equality(config.build_policy, nil)
  expect.equality(#prompts, 4)
  expect.equality(prompts[1]:find("optional", 1, true) ~= nil, true)
  expect.equality(prompts[1]:find("missing:zlib/*", 1, true) ~= nil, true)
end

test_set["explicit reconfiguration omits cancelled and whitespace-only build policies"] = function()
  for _, build_policy in ipairs({ false, "   \t " }) do
    local config = run_wizard("reconfigure", { build_policy or nil, "", "", "" })
    expect.equality(config.build_policy, nil)
  end
end

test_set["explicit reconfiguration stores a free-form build policy"] = function()
  local config = run_wizard("reconfigure", { " missing:zlib/* ", "", "", "" })

  expect.equality(config.build_policy, "missing:zlib/*")
end

return test_set
