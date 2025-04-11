if exists("g:loaded_nvim_conan")
  finish
endif
let g:loaded_nvim_conan = 1

if has("nvim")
lua << EOF
  local ok, mod = pcall(require, "conan")
  if ok and mod then
    mod.setup()
  end
EOF
endif
