local M = {}

M._timer = nil
M._spin_i = 1
M._frames = { "⟳", "⟲" }

local uv = vim.loop

local function exists(path)
  return uv.fs_stat(path) ~= nil
end

local function in_conan_project()
  local cwd = vim.fn.getcwd()
  return exists(cwd .. "/conanfile.py")
      or exists(cwd .. "/conanfile.txt")
      or exists(cwd .. "/.nvim-conan.json")
      or exists(cwd .. "/conan.lock")
end

local function redraw()
  vim.cmd("redrawstatus")
end

function M.start(text)
  vim.g.conan_busy = true
  vim.g.conan_busy_text = text or vim.g.conan_busy_text or "Conan"

  if M._timer then
    M._timer:stop()
    M._timer:close()
    M._timer = nil
  end

  M._spin_i = 1
  M._timer = vim.loop.new_timer()
  M._timer:start(0, 60, vim.schedule_wrap(function()
    vim.g.conan_busy_spin = M._frames[M._spin_i]
    M._spin_i = (M._spin_i % #M._frames) + 1
    redraw()
  end))

  redraw()
end

function M.stop()
  vim.g.conan_busy = false
  vim.g.conan_busy_text = nil
  vim.g.conan_busy_spin = nil

  if M._timer then
    M._timer:stop()
    M._timer:close()
    M._timer = nil
  end

  redraw()
end

function M.component()
  if vim.g.conan_busy then
    local spin = vim.g.conan_busy_spin or "…"
    local text = vim.g.conan_busy_text or "Conan"
    return spin .. " " .. text
  end

  if in_conan_project() then
    return " Conan"
  end

  return ""
end

return M
