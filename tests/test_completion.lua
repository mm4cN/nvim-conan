local test_set = MiniTest.new_set()
local expect = MiniTest.expect
local completion = require("conan.completion")

test_set["extracts unique short and long flags from Conan help"] = function()
  local help = [[usage: conan create [-h] [-r REMOTE] [--build BUILD]

options:
  -h, --help            show this help message and exit
  -r, --remote REMOTE   use a remote
  --build BUILD         accepts forms such as --build=missing
]]

  expect.equality(completion.parse_help(help), {
    "--build",
    "--help",
    "--remote",
    "-h",
    "-r",
  })
end

test_set["parses positional completion context at and before the cursor"] = function()
  local search = "Conan search zlib con"
  local create = "Conan create --remote "
  local before_suffix = "Conan export --version ignored"

  expect.equality(completion.context(search, #search), {
    subcommand = "search",
    argument_index = 2,
    previous_argument = "zlib",
  })
  expect.equality(completion.context(create, #create), {
    subcommand = "create",
    argument_index = 2,
    previous_argument = "--remote",
  })
  expect.equality(completion.context(before_suffix, #"Conan export --version"), {
    subcommand = "export",
    argument_index = 1,
  })
end

test_set["completes the positional search remote and caches the remote list"] = function()
  completion.clear_cache()
  local provider_calls = 0
  local providers = {
    remotes = function()
      provider_calls = provider_calls + 1
      return { "private", "conancenter" }
    end,
  }
  local context = { subcommand = "search", argument_index = 2 }

  expect.equality(completion.complete(context, "con", providers), { "conancenter" })
  expect.equality(completion.complete(context, "", providers), { "*", "conancenter", "private" })
  expect.equality(provider_calls, 1)
end

test_set["completes version-specific Conan flags and caches help per command"] = function()
  completion.clear_cache()
  local provider_calls = 0
  local providers = {
    help = function(command)
      provider_calls = provider_calls + 1
      expect.equality(command, "create")
      return "  --version VERSION  package version\n  --verbose  verbose output\n"
    end,
  }
  local context = { subcommand = "create", argument_index = 1 }

  expect.equality(completion.complete(context, "--v", providers), { "--verbose", "--version" })
  expect.equality(completion.complete(context, "--ver", providers), { "--verbose", "--version" })
  expect.equality(provider_calls, 1)
end

test_set["completes remote flag values for create and export commands"] = function()
  completion.clear_cache()
  local providers = {
    remotes = function()
      return { "private", "conancenter" }
    end,
  }

  expect.equality(
    completion.complete({ subcommand = "export", argument_index = 2, previous_argument = "--remote" }, "p", providers),
    { "private" }
  )
  expect.equality(
    completion.complete({ subcommand = "export_package", argument_index = 2, previous_argument = "-r" }, "c", providers),
    { "conancenter" }
  )
  expect.equality(
    completion.complete({ subcommand = "create", argument_index = 1 }, "--remote=con", providers),
    { "--remote=conancenter" }
  )
  expect.equality(
    completion.complete({ subcommand = "create", argument_index = 1 }, "-r=p", providers),
    { "-r=private" }
  )
end

test_set["does not suggest flags for positional values or unsupported commands"] = function()
  completion.clear_cache()
  expect.equality(completion.complete({ subcommand = "create", argument_index = 1 }, "value", {}), {})
  expect.equality(completion.complete({ subcommand = "install", argument_index = 1 }, "--", {}), {})
  expect.equality(completion.complete({ subcommand = "search", argument_index = 1 }, "zlib", {}), {})
end

test_set["completes supported SBOM formats"] = function()
  expect.equality(completion.complete({ subcommand = "sbom", argument_index = 1 }, "1.", {}), { "1.4", "1.6" })
  expect.equality(completion.complete({ subcommand = "sbom", argument_index = 3 }, "", {}), {})
end

return test_set
