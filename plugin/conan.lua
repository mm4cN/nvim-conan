if vim.g.loaded_nvim_conan then return end
vim.g.loaded_nvim_conan = true

local ok, mod = pcall(require, "conan")
if ok and mod then
  mod.setup()
end
