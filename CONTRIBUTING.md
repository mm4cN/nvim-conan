# Contributing to nvim-conan

Welcome, curious hacker — thank you for considering a contribution.  
This project is built with love and Lua, and contributions are deeply appreciated.

Whether you're fixing a bug, adding a feature, improving documentation, or just asking good questions — you're helping.

---

## 🛠️ Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/mm4cN/nvim-conan
cd nvim-conan
```


### 2. Link the Plugin Locally

If you're using [lazy.nvim](https://github.com/folke/lazy.nvim), point to your local copy:
```lua
{
  dir = "~/path/to/nvim-conan",
  name = "conan",
}
```

------

## 📋 Requirements

Before contributing, make sure the following tools are installed:

- Neovim 0.12+
- Conan 2.x – Installed manually and available on your PATH
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim): Required for interactive pickers
- A working Python 3 provider for Neovim (check with :checkhealth)
- A basic C/C++ toolchain for testing Conan builds locally
- [StyLua](https://github.com/JohnnyMorganz/StyLua) for formatting checks

You can install Telescope like so:

```lua
{
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
}
```
-----

## 🧪 Testing

Install the test dependencies once, then run the headless Neovim test suite:

```bash
make deps
make test
```

The tests use `mini.test` with real Telescope and Plenary checkouts in the ignored `.deps`
directory. They do not require Conan credentials or network access after the dependencies are
installed.

Check or apply Lua formatting with:

```bash
make format-check
make format
```

### Manual plugin testing

To test plugin behavior:

Open a project with a conanfile.py
Run :Conan <subcommand> to test commands like:
install, build, lock, search, create, export, upload
You can use a test config:

```json
{
  "profile_host": "default",
  "profile_build": "default"
}
```

`build_policy` is optional. To exercise an explicitly configured policy, add any Conan-supported
value, such as `"build_policy": "missing:zlib/*"`; the plugin passes it as
`--build=missing:zlib/*`.
-------

## ✨ Suggestions Welcome

If you're unsure where to start, feel free to open an issue and ask — small improvements are just as valuable as big features.

Thanks again for contributing 💚


---

Let me know if you'd like to add a **`Makefile` or setup script** for common dev tasks, or a `:Conan debug` mode that outputs internal state.
