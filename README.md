# 🌿 nvim-conan

A Lua-crafted bridge between Neovim and Conan, the C/C++ package manager.

---

# ✨ Features

- 🧱 **Project Initialization**  
  Seamlessly set up your C/C++ projects with Conan integration.

- 🧠 **Command Palette via `:Conan`**  
  Use `:Conan <subcommand>` for interactive Conan actions:
  - `install`: Install dependencies
  - `build`: Build using Conan profiles
  - `lock`: Create or update lockfiles
  - `search`: Search Conan cache or remotes
  - `create`: Package your recipe
  - `export`: Export the recipe
  - `export_package`: Export prebuilt packages
  - `upload`: Upload recipes to remotes (with **Telescope-powered** remote and ref selection!)

- 🔭 **Telescope Integration**  
  Intuitive fuzzy-pickers for selecting remotes and cached packages before upload.

- ⚡ **Neovim Native**  
  No Python wrappers. No frills. Pure Lua.

---

# ⚙️ Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "mm4cN/nvim-conan",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
}
```

-----

# 🔧 Configuration

Default setup:

```lua
require("conan").setup()
```

This checks whether Conan is available, bootstraps config files, and provides `:Conan` commands.

On first use in a Conan project, an interactive wizard creates a `conan-config.json` in your project root. The plugin also recognises `conan-config.json` placed inside a `.vscode/` subdirectory, so teams that already keep per-project settings there don't need a duplicate file.

-------

# 📋 Requirements

Neovim: 0.12 or higher

Lua: 5.1+ (included with Neovim)

Conan: 2.x — installed manually and available on your PATH

[Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim): Required for interactive remote/ref pickers (used by upload)

Run `:checkhealth conan` to verify the required components are available.

-------

# 📚 Documentation

[`:help nvim-conan`](doc/nvim-conan.txt): Built-in help for setup, commands, config, and health checks.
[CHANGELOG.md](CHANGELOG.md): Stay updated with the latest changes.
[CONTRIBUTING.md](CONTRIBUTING.md): Guidelines for contributing to the project.

----- 

# 🛡 License

This project is licensed under the MIT License.

------

*Embrace the harmony of Neovim and Conan, orchestrated through Lua.*
