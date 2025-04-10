# 🌿 nvim-conan

A Lua-crafted bridge between Neovim and Conan, the C/C++ package manager.

------ 

# ✨ Features

Project Initialization: Seamlessly set up your C/C++ projects with Conan integration.

Neovim Integration: Designed specifically for Neovim users who seek streamlined package management.

Lua-Powered: Leverages Lua for efficient and elegant scripting within Neovim.

------

# ⚙️ Installation

Using lazy.nvim:

```lua
return {
  "mmacz/nvim-conan",
  config = function()
    require("conan").setup()
  end
}
```

------

# 🔧 Configuration

Default setup:
```lua
require("conan").setup({
  -- Add your configuration options here
})
```
Customize the setup to fit your project's needs.

------

# 📋 Requirements

Neovim: Version 0.7 or higher

Lua: Ensure Lua support is enabled in your Neovim setup

------

# 📚 Documentation

[CHANGELOG.md](CHANGELOG.md): Stay updated with the latest changes.

[CONTRIBUTING.md](CONTRIBUTING.md): Guidelines for contributing to the project.

------

# 🛡 License

This project is licensed under the MIT License.

------

*Embrace the harmony of Neovim and Conan, orchestrated through Lua.*
