if exists("g:loaded_nvim_conan")
  finish
endif
let g:loaded_nvim_conan = 1

lua << EOF
pcall(require, "conan") and require("conan").setup()
EOF

