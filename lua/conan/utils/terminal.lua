local M = {}

function M.open_floating_terminal(argv, title, close_term, opts)
  assert(type(argv) == "table" and #argv > 0, "argv must be a non-empty table")
  for index, argument in ipairs(argv) do
    assert(type(argument) == "string", string.format("argv[%d] must be a string", index))
  end

  opts = opts or {}
  if close_term == nil then
    close_term = true
  end

  local width = math.floor(vim.o.columns * 0.35)
  vim.cmd("botright vsplit")

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(win, width)

  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "terminal"

  vim.fn.termopen(argv, {
    on_exit = function(_, code, _)
      vim.schedule(function()
        if type(opts.on_exit) == "function" then
          pcall(opts.on_exit, code, {
            win = win,
            buf = buf,
            argv = argv,
            title = title,
          })
        end

        if code == 0 and close_term then
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        elseif
          code ~= 0
          and vim.api.nvim_win_is_valid(win)
          and vim.api.nvim_buf_is_valid(buf)
          and vim.api.nvim_win_get_buf(win) == buf
          and vim.api.nvim_get_current_win() == win
          and vim.api.nvim_get_mode().mode:sub(1, 1) == "t"
        then
          vim.api.nvim_feedkeys(vim.keycode("<C-\\><C-N>"), "n", false)
        end
      end)
    end,
  })

  if type(opts.buffer_name) == "string" and opts.buffer_name ~= "" then
    local previous = vim.fn.bufnr(opts.buffer_name)
    if previous ~= -1 and previous ~= buf and vim.api.nvim_buf_is_valid(previous) then
      vim.api.nvim_buf_set_name(previous, opts.buffer_name .. ":" .. previous)
    end
    vim.api.nvim_buf_set_name(buf, opts.buffer_name)
  end

  vim.cmd("startinsert")
end

return M
