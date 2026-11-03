local test_set = MiniTest.new_set()
local expect = MiniTest.expect

test_set["terminal uses the requested buffer name"] = function()
  local utils = require("utils")
  local original_window = vim.api.nvim_get_current_win()
  local terminal_window
  local terminal_buffer

  local ok, err = xpcall(function()
    utils.open_floating_terminal({ "sh", "-c", "exit 1" }, "test", false, {
      buffer_name = "terminal-test",
    })
    terminal_window = vim.api.nvim_get_current_win()
    terminal_buffer = vim.api.nvim_get_current_buf()

    local name = vim.api.nvim_buf_get_name(terminal_buffer)
    expect.equality(vim.fn.fnamemodify(name, ":t"), "terminal-test")
    expect.equality(vim.bo[terminal_buffer].buflisted, true)
  end, debug.traceback)

  if terminal_window and vim.api.nvim_win_is_valid(terminal_window) then
    vim.api.nvim_win_close(terminal_window, true)
  end
  if terminal_buffer and vim.api.nvim_buf_is_valid(terminal_buffer) then
    vim.api.nvim_buf_delete(terminal_buffer, { force = true })
  end
  if vim.api.nvim_win_is_valid(original_window) then
    vim.api.nvim_set_current_win(original_window)
  end

  if not ok then
    error(err)
  end
end

return test_set
