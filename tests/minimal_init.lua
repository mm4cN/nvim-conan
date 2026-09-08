local root = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h:h")

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. "/.deps/mini.nvim")
vim.opt.runtimepath:prepend(root .. "/.deps/plenary.nvim")
vim.opt.runtimepath:prepend(root .. "/.deps/telescope.nvim")

require("mini.test").setup()
