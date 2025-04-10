if exists("g:loaded_conan_nvim")
  finish
endif
let g:loaded_conan_nvim = 1

lua << EOF
local ok, mod = pcall(require, "conan")
if ok and mod then
  mod.setup()
end
EOF

