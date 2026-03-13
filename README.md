# Djortcuts for Neovim

A Neovim plugin that automates common Django development tasks.

## Installation

Using lazy.nvim:

```lua
-- ~/.config/nvim/lua/plugins/djortcuts.lua

{
  "franmacke/djortcuts.nvim",
  config = function()
    require("djortcuts").setup()
  end,
  keys = {
    { "<leader>dr", "<cmd>DjangoRun<cr>", desc = "Django Run Server" },
    { "<leader>dm", "<cmd>DjangoMigrate<cr>", desc = "Django Migrate" },
    { "<leader>di18n", "<cmd>DjangoMakemessages<cr>", desc = "i18n: Make Messages" },
    { "<leader>dbi18n", "<cmd>DjangoCompilemessages<cr>", desc = "i18n: Build Messages" },
    -- ... other keybindings
  },
}
```

## Usage

1. Navigate to your Django project directory
2. Run `:DjangoInit` to initialize the plugin
3. Use the commands or keybindings to run Django tasks

## Current Config

```lua
return {
  {
    "franmacke/djortcuts.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      local django_automation = require("djortcuts")
      django_automation.setup()
    end,
    keys = {
      { "<leader>jr", "<cmd>DjangoRun<cr>", desc = "Django Run Server" },
      { "<leader>jmg", "<cmd>DjangoMigrate<cr>", desc = "Django Migrate" },
      { "<leader>jmm", "<cmd>DjangoMakemigrations<cr>", desc = "Django Make Migrations" },
      { "<leader>js", "<cmd>DjangoShell<cr>", desc = "Django Shell" },
      { "<leader>ji", "<cmd>DjangoInit<cr>", desc = "Django Init Config" },
      { "<leader>jt", "<cmd>DjangoTest<cr>", desc = "Django Test" },
      { "<leader>jc", "<cmd>DjangoCollectstatic<cr>", desc = "Django Collect Static" },
      { "<leader>jk", "<cmd>DjangoCheck<cr>", desc = "Django Check" },
      { "<leader>jI", "<cmd>DjangoMakemessages<cr>", desc = "i18n: Make Messages" },
      { "<leader>jB", "<cmd>DjangoCompilemessages<cr>", desc = "i18n: Build Messages" },
      { "<leader>jC", "<cmd>DjangoManagementCommand<cr>", desc = "Django Management Command" },
    },
    dependencies = {
      "folke/which-key.nvim",
      opts = {
        spec = {
          { "<leader>j", group = "djortcuts", icon = { icon = "⚡" } },
          { "<leader>jm", group = "Migrations" },
        },
      },
    },
  },
}

## New Commands

- `:DjangoMakemessages` — prompts for options (e.g., `-l es` or `-a`) and runs `manage.py makemessages` with the provided flags.
- `:DjangoCompilemessages` — prompts for optional flags (e.g., `-l es`) and runs `manage.py compilemessages`.

Tip: You can also use `:DjangoManagementCommand` and pick `makemessages`/`compilemessages` to compose flags interactively.
```
