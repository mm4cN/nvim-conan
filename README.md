# conan.nvim

Conan wrapper written in lua. Designed for neovim usage.
Conan is a C/C++ package manager. For more information please refer to:

![conan](https://img.shields.io/badge/Conan-2.X-blue)
![neovim](https://img.shields.io/badge/Neovim-0.7+-blueviolet?style=flat&logo=neovim)
![license](https://img.shields.io/github/license/mmacz/conan.nvim)

---

## ✨ Features

- Init project

---

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mmacz/conan.nvim",
  config = function()
    require("conan").setup()
  end
}
```


