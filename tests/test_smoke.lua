local test_set = MiniTest.new_set()
local expect = MiniTest.expect

test_set["loads conan with its runtime dependencies"] = function()
  local conan = require("conan")

  expect.equality(type(conan), "table")
  expect.equality(type(conan.setup), "function")
end

return test_set
