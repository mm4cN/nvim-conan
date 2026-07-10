local M = {}

local health = vim.health

local function check_nvim()
  local version = vim.version()
  local current = string.format("%d.%d.%d", version.major, version.minor, version.patch)

  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim " .. current .. " detected")
    return
  end

  health.error("Neovim 0.12+ is required (found " .. current .. ")")
end

local function check_conan()
  if vim.fn.executable("conan") ~= 1 then
    health.error("`conan` executable not found on PATH")
    health.info("Install Conan 2.x manually and ensure `conan --version` works in your shell.")
    return
  end

  local output = vim.fn.system("conan --version")
  if vim.v.shell_error ~= 0 then
    health.error("Failed to run `conan --version`")
    local details = vim.trim(output)
    if details ~= "" then
      health.info(details)
    end
    return
  end

  local version = output:match("(%d+%.%d+%.%d+)") or vim.trim(output)
  if output:match("Conan version 2%.") then
    health.ok("Conan " .. version .. " detected")
    return
  end

  health.error("Conan 2.x is required (found " .. version .. ")")
end

local function check_telescope()
  local modules = {
    "telescope",
    "telescope.pickers",
    "telescope.finders",
    "telescope.config",
    "telescope.previewers",
    "telescope.actions",
    "telescope.actions.state",
  }

  local missing = {}
  for _, module in ipairs(modules) do
    local ok = pcall(require, module)
    if not ok then
      table.insert(missing, module)
    end
  end

  if #missing == 0 then
    health.ok("Telescope.nvim is available")
    return
  end

  health.error("Telescope.nvim is required for interactive pickers")
  health.info("Missing modules: " .. table.concat(missing, ", "))
end

function M.check()
  health.start("nvim-conan")
  check_nvim()
  check_conan()
  check_telescope()
end

return M
