# Django Automation for Neovim

A Neovim plugin that automates common Django development tasks.

## Installation

Using lazy.nvim:
```lua
-- ~/.config/nvim/lua/plugins/django-automation.lua

{
  "franmacke/django-automation.nvim",
  config = function()
    require("django_automation").setup()
  end,
  keys = {
    { "<leader>dr", "<cmd>DjangoRun<cr>", desc = "Django Run Server" },
    { "<leader>dm", "<cmd>DjangoMigrate<cr>", desc = "Django Migrate" },
    -- ... other keybindings
  },
}
```

## Usage

1. Navigate to your Django project directory
2. Run `:DjangoInit` to initialize the plugin
3. Use the commands or keybindings to run Django tasks
