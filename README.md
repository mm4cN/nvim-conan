# 🌿 nvim-conan

<p align="center">
  <img src="assets/icon.png" alt="nvim-conan logo" width="240">
</p>

<p align="center">
  A Lua-crafted bridge between Neovim and Conan, the C/C++ package manager.
</p>

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

- 🛡️ **Safe Command Execution**
  Conan commands are passed as argument lists rather than shell command strings.

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

On first use in a Conan project, an interactive wizard creates `conan-config.json` in the project
root. The plugin also recognises `.vscode/conan-config.json`, so teams that keep project settings
there do not need a duplicate file.

The automatic first-time configuration leaves Conan's optional `build_policy` unset.
`:Conan reconfigure` accepts a free-form optional value such as `missing` or `missing:zlib/*`.
A missing, empty, or blank value omits `--build`; otherwise, `install`, `build`, and `create`
include `--build=<value>`.

Create and export commands accept additional Conan arguments:

```vim
:Conan create [args...]
:Conan create --version=1.2.3
:Conan export [args...]
:Conan export --user=alice --channel=stable
:Conan export_package [args...]
:Conan export_package --output-folder=build/package --user=alice --channel=stable
```

They generate argv in this order:

```text
conan create [recipe] [profiles] [optional build policy] [args...]
conan export [recipe] [args...]
conan export-pkg [recipe] [args...]
```

Additional arguments retain their original order, remain separate literal argv elements, and are
passed directly to Conan without shell interpretation.

This is a breaking change for exports: `:Conan export alice stable` and
`:Conan export_package alice stable` are no longer rewritten as user/channel flags. Pass explicit
Conan flags instead, as shown in the examples above.

-------

# 📋 Requirements

Neovim: 0.12 or higher

Lua: 5.1+ (included with Neovim)

Conan: 2.x — installed manually and available on your PATH

[Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim): Required for interactive remote/ref pickers (used by upload)

Run `:checkhealth conan` to verify the required components are available.

-------

# 🧪 Development

Install the test dependencies and run the headless Neovim test suite:

```bash
make deps
make test
```

Tests use `mini.test` with real Telescope and Plenary dependencies. Command construction is kept
in the pure Lua `conan.command_builder` module so it can be tested without loading UI code.

Check or apply Lua formatting with StyLua:

```bash
make format-check
make format
```

-------

# 📚 Documentation

- [`:help nvim-conan`](doc/nvim-conan.txt): Built-in help for setup, commands, config, and health checks.
- [CHANGELOG.md](CHANGELOG.md): Stay updated with the latest changes.
- [CONTRIBUTING.md](CONTRIBUTING.md): Guidelines for contributing to the project.

----- 

# 🛡 License

This project is licensed under the MIT License.

------

*Embrace the harmony of Neovim and Conan, orchestrated through Lua.*
