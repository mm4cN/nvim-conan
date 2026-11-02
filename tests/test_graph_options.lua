local test_set = MiniTest.new_set()
local expect = MiniTest.expect
local graph_options = require("conan.graph_options")

test_set["builds graph info argv without shell interpolation"] = function()
  expect.equality(graph_options.command("zlib/1.3.1", "conancenter"), {
    "conan",
    "graph",
    "info",
    "--requires=zlib/1.3.1",
    "-r=conancenter",
    "--filter=options",
    "--format=json",
    "-vquiet",
  })
end

test_set["extracts and sorts options from the selected recipe node"] = function()
  local stdout = [[{
    "graph": {
        "nodes": {
            "0": {
                "ref": "conanfile",
                "options": {}
            },
            "1": {
                "ref": "zlib/1.3.1#b8bc2603263cf7eccbd6e17e66b0ed76",
                "options": {
                    "shared": "False",
                    "fPIC": "True"
                }
            }
        },
        "error": null
    }
}]]

  local options, err = graph_options.parse(stdout, "zlib/1.3.1")

  expect.equality(err, nil)
  expect.equality(options, {
    { name = "fPIC", value = "True" },
    { name = "shared", value = "False" },
  })
end

test_set["matches a selected reference that already contains a recipe revision"] = function()
  local stdout = vim.json.encode({
    graph = {
      nodes = {
        ["0"] = { ref = "conanfile", options = {} },
        ["1"] = { ref = "fmt/11.0.2#abc123", options = { header_only = true } },
      },
    },
  })

  local options = graph_options.parse(stdout, "fmt/11.0.2#abc123")

  expect.equality(options, { { name = "header_only", value = "true" } })
end

test_set["returns an empty option list for a recipe without options"] = function()
  local stdout = vim.json.encode({
    graph = {
      nodes = {
        ["0"] = { ref = "conanfile", options = {} },
        ["1"] = { ref = "cmake/3.30.1#abc123", options = {} },
      },
    },
  })

  local options, err = graph_options.parse(stdout, "cmake/3.30.1")

  expect.equality(err, nil)
  expect.equality(options, {})
end

test_set["reports malformed JSON, graph errors, and a missing selected node"] = function()
  local invalid_options, invalid_error = graph_options.parse("not-json", "zlib/1.3.1")
  local graph_options_result, graph_error = graph_options.parse(
    vim.json.encode({ graph = { nodes = {}, error = "dependency resolution failed" } }),
    "zlib/1.3.1"
  )
  local missing_options, missing_error = graph_options.parse(
    vim.json.encode({ graph = { nodes = { ["0"] = { ref = "conanfile", options = {} } } } }),
    "zlib/1.3.1"
  )

  expect.equality(invalid_options, nil)
  expect.equality(invalid_error:find("invalid JSON", 1, true) ~= nil, true)
  expect.equality(graph_options_result, nil)
  expect.equality(graph_error:find("dependency resolution failed", 1, true) ~= nil, true)
  expect.equality(missing_options, nil)
  expect.equality(missing_error:find("selected recipe", 1, true) ~= nil, true)
end

test_set["formats loading, populated, empty, and error preview sections"] = function()
  expect.equality(graph_options.format_section({ status = "loading" }), {
    "Options:",
    "  loading...",
  })
  expect.equality(
    graph_options.format_section({
      status = "ready",
      options = {
        { name = "fPIC", value = "True" },
        { name = "shared", value = "False" },
      },
    }),
    {
      "Options:",
      "  fPIC: True",
      "  shared: False",
    }
  )
  expect.equality(graph_options.format_section({ status = "ready", options = {} }), {
    "Options:",
    "  not specified",
  })
  expect.equality(graph_options.format_section({ status = "error", error = "first line\nsecond line" }), {
    "Options:",
    "  unavailable",
  })
end

return test_set
