local M = {}

local conan_check_or_install = function()
  if vim.fn.executable("conan") == 1 then
    return true
  end

  local py = vim.g.python3_host_prog or "python3"
  vim.fn.system(py .. " -m pip --version")
  local pip_available = vim.v.shell_error == 0

  if not pip_available then
    vim.notify("Conan executable is missing and pip is unavailable to install it.\nCheck your Python provider or install manually.", vim.log.levels.ERROR)
  end

 local choice = vim.fn.input(string.format("'conan' not found. Install Python package using pip? [y/N]: "))

  if choice:lower() ~= "y" then
    vim.notify("'conan' is required but not installed.", vim.log.levels.ERROR)
  end

  vim.fn.system(py .. " -m pip install --user conan")

  if vim.v.shell_error == 0 then
    vim.notify("✅ Installed 'conan' using pip", vim.log.levels.ERROR)
    return true
  else
    vim.notify("Failed to install 'conan' using pip", vim.log.levels.ERROR)
  end
end

M.setup = function()
  vim.notify("Loaded conan.nvim", vim.log.levels.INFO)
end

return M

