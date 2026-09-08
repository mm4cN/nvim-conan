local M = {}

local function append(argv, ...)
  for index = 1, select("#", ...) do
    argv[#argv + 1] = tostring(select(index, ...))
  end
end

local function append_profiles(argv, config)
  append(argv, "-pr:b", config.profile_build, "-pr:h", config.profile_host)
end

local function append_build_policy(argv, config)
  append(argv, "--build=" .. tostring(config.build_policy))
end

local function append_lockfile(argv, lockfile)
  if lockfile and lockfile ~= "" then
    append(argv, "--lockfile", lockfile)
  end
end

local function sorted_entries(values)
  local entries = {}
  for key, value in pairs(values or {}) do
    entries[#entries + 1] = { key = tostring(key), value = value }
  end
  table.sort(entries, function(left, right)
    return left.key < right.key
  end)
  return entries
end

local function append_key_values(argv, flag, values)
  for _, entry in ipairs(sorted_entries(values)) do
    append(argv, flag, entry.key .. "=" .. tostring(entry.value))
  end
end

function M.install(config, lockfile)
  local argv = { "conan", "install", config.recipe or "." }
  append_profiles(argv, config)
  append_build_policy(argv, config)
  append_lockfile(argv, lockfile)
  return argv
end

function M.build(config, lockfile)
  local argv = { "conan", "build", config.recipe or "." }
  append_profiles(argv, config)
  append_build_policy(argv, config)
  append_key_values(argv, "-o", config.options)
  append_key_values(argv, "-c", config.conf)
  append_lockfile(argv, lockfile)
  return argv
end

function M.lock(config)
  return { "conan", "lock", "create", config.recipe or "." }
end

function M.create(config)
  local argv = { "conan", "create" }
  append_profiles(argv, config)
  append_build_policy(argv, config)
  append(argv, config.recipe or ".")
  return argv
end

function M.export(config, user, channel)
  local argv = { "conan", "export" }
  if user then
    append(argv, "--user", user)
  end
  if channel then
    append(argv, "--channel", channel)
  end
  append(argv, config.recipe or ".")
  return argv
end

function M.export_package(config, user, channel)
  local argv = { "conan", "export-pkg" }
  if user then
    append(argv, "--user", user)
  end
  if channel then
    append(argv, "--channel", channel)
  end
  append(argv, config.recipe or ".")
  return argv
end

function M.upload(reference, remote)
  return { "conan", "upload", tostring(reference), "-r=" .. tostring(remote), "--confirm" }
end

return M
