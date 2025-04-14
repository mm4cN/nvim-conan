if has("nvim")
lua << EOF
  local ok, mod = pcall(require, "conan")
  if ok and mod then
    mod.setup()
  end
EOF
endif

