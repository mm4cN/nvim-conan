local command_builder = require("conan.command_builder")

local test_set = MiniTest.new_set()
local expect = MiniTest.expect

local config = {
  recipe = "recipes/conanfile.py",
  profile_build = "build-profile",
  profile_host = "host-profile",
  build_policy = "missing",
}

test_set["install includes profiles, recipe, build policy, and resolved lockfile"] = function()
  expect.equality(command_builder.install(config, "locks/project.lock"), {
    "conan",
    "install",
    "recipes/conanfile.py",
    "-pr:b",
    "build-profile",
    "-pr:h",
    "host-profile",
    "--build=missing",
    "--lockfile",
    "locks/project.lock",
  })
end

test_set["install omits an unresolved lockfile"] = function()
  expect.equality(command_builder.install(config), {
    "conan",
    "install",
    "recipes/conanfile.py",
    "-pr:b",
    "build-profile",
    "-pr:h",
    "host-profile",
    "--build=missing",
  })
end

test_set["build sorts options and conf deterministically"] = function()
  local build_config = vim.tbl_extend("force", config, {
    options = { zlib = true, shared = false },
    conf = { ["tools.cmake:generator"] = "Ninja", ["tools.build:jobs"] = 8 },
  })

  expect.equality(command_builder.build(build_config, "conan.lock"), {
    "conan",
    "build",
    "recipes/conanfile.py",
    "-pr:b",
    "build-profile",
    "-pr:h",
    "host-profile",
    "--build=missing",
    "-o",
    "shared=false",
    "-o",
    "zlib=true",
    "-c",
    "tools.build:jobs=8",
    "-c",
    "tools.cmake:generator=Ninja",
    "--lockfile",
    "conan.lock",
  })
end

test_set["paths and option values remain single literal arguments"] = function()
  local literal_config = vim.tbl_extend("force", config, {
    recipe = "recipes/my project;$(touch unsafe).py",
    options = { feature = "value with spaces;$(echo unsafe)&*" },
  })

  expect.equality(command_builder.build(literal_config), {
    "conan",
    "build",
    "recipes/my project;$(touch unsafe).py",
    "-pr:b",
    "build-profile",
    "-pr:h",
    "host-profile",
    "--build=missing",
    "-o",
    "feature=value with spaces;$(echo unsafe)&*",
  })
end

test_set["lock uses the configured recipe"] = function()
  expect.equality(command_builder.lock(config), {
    "conan",
    "lock",
    "create",
    "recipes/conanfile.py",
  })
end

test_set["create preserves profile and recipe ordering"] = function()
  expect.equality(command_builder.create(config), {
    "conan",
    "create",
    "-pr:b",
    "build-profile",
    "-pr:h",
    "host-profile",
    "--build=missing",
    "recipes/conanfile.py",
  })
end

test_set["export includes user and channel before the recipe"] = function()
  expect.equality(command_builder.export(config, "alice", "stable"), {
    "conan",
    "export",
    "--user",
    "alice",
    "--channel",
    "stable",
    "recipes/conanfile.py",
  })
end

test_set["export-package includes user and channel before the recipe"] = function()
  expect.equality(command_builder.export_package(config, "alice", "testing"), {
    "conan",
    "export-pkg",
    "--user",
    "alice",
    "--channel",
    "testing",
    "recipes/conanfile.py",
  })
end

test_set["upload includes the selected reference and remote"] = function()
  expect.equality(command_builder.upload("pkg/1.0@alice/stable", "company"), {
    "conan",
    "upload",
    "pkg/1.0@alice/stable",
    "-r=company",
    "--confirm",
  })
end

return test_set
