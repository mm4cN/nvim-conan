# Contributing to myplugin.nvim

Welcome, curious hacker — thank you for considering a contribution.  
This project is built with love and Lua, and contributions are deeply appreciated.

Whether you're fixing a bug, adding a feature, improving documentation, or just asking good questions — you're helping.
Here's how you can get involved.

---

## 🛠️ Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/mmacz/nvim-conan
cd nvim-conan
```

### 2. Link the Plugin Locally

If you're using Lazy.nvim, point to your local copy:

```lua
{
  dir = "~/path/to/nvim-conan",
  name = "conan",
  config = function()
    require("conan").setup()
  end,
}
```

Or local development:

```lua
{
  dir = "~/dev/nvim-conan",
  name = "conan",
  config = function()
    require("conan").setup()
  end
}
```

