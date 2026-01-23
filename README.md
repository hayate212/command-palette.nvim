# command-palette.nvim

A customizable command palette for Neovim, built with [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

## Features

- 🔍 Fuzzy search through your custom commands
- 📁 Organize commands by category
- 🎨 Customizable UI with icons
- ⌨️ Intuitive keyboard navigation
- 📝 Command descriptions displayed in real-time

## Requirements

- Neovim >= 0.8.0
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## Installation

### lazy.nvim

```lua
{
  "hayate212/command-palette.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim"
  },
  cmd = { "CommandPalette" },
  keys = {
    { "<leader>:", "<cmd>CommandPalette<cr>", desc = "Command Palette" },
  },
  opts = {
    commands = {
      -- Your custom commands here
    },
  },
  config = true,
}
```

## Configuration

### Basic Setup

```lua
require("command-palette").setup({
  commands = {
    {
      name = "Save",
      description = "Save current buffer",
      command = "w",
      category = "File",
      icon = ""
    },
    {
      name = "Quit",
      description = "Quit Neovim",
      command = "q",
      category = "File",
      icon = "󰗼"
    },
  },
  ui = {
    border = "rounded",      -- Border style: "single", "double", "rounded", "solid", "shadow"
    width = 60,              -- Width of the palette
    max_height = 20,         -- Maximum height for command list
    position = "50%",        -- Position on screen
    title = " Commands ",   -- Title shown at the top
    show_icons = true,       -- Show/hide icons
  },
})
```

### Command Definition

Each command is defined with the following fields:

- `name` (required): The display name of the command
- `command` (required): Either a Vim command string (e.g., `"w"`) or a Lua function
- `description` (optional): A brief description shown at the bottom
- `category` (optional): Category for grouping commands
- `icon` (optional): An icon to display (requires a patched font)

### Example Configuration

```lua
require("command-palette").setup({
  commands = {
    -- File operations
    {
      name = "Save",
      description = "Save current buffer",
      command = "w",
      category = "File",
      icon = ""
    },
    {
      name = "Save All",
      description = "Save all buffers",
      command = "wa",
      category = "File",
      icon = ""
    },

    -- Telescope integration
    {
      name = "Find Files",
      description = "Search for files in workspace",
      command = "Telescope find_files",
      category = "Search",
      icon = ""
    },
    {
      name = "Live Grep",
      description = "Search text in workspace",
      command = "Telescope live_grep",
      category = "Search",
      icon = ""
    },

    -- Custom Lua functions
    {
      name = "Toggle Dark Mode",
      description = "Switch between light and dark themes",
      command = function()
        vim.opt.background = vim.opt.background:get() == "dark" and "light" or "dark"
      end,
      category = "UI",
      icon = "🌓"
    },
  },
})
```

## Usage

### Opening the Palette

Call the `open()` function to display the command palette:

```lua
require("command-palette").open()
```

Or map it to a key (e.g., `<leader>:`):

```lua
vim.keymap.set("n", "<leader>:", function()
  require("command-palette").open()
end, { desc = "Command Palette" })
```

### Keyboard Shortcuts

When the palette is open:

- `<C-n>` or `<Down>`: Move to next command
- `<C-p>` or `<Up>`: Move to previous command
- `<CR>`: Execute selected command
- `<Esc>`: Close the palette
- Type to filter commands by name, description, or category

## State API

The state module provides programmatic access to the command palette's internal state, enabling dynamic command management and integration with other plugins.

### Available Functions

| Function | Return | Description |
|----------|--------|-------------|
| `state.get_commands()` | table[] | Get list of registered commands |
| `state.is_open()` | boolean | Check if palette UI is open |
| `state.add_command(cmd)` | void | Dynamically add a command |
| `state.remove_command(name)` | void | Remove a command by name |

### Basic Usage

```lua
local state = require("command-palette.state")

-- Get all registered commands
local commands = state.get_commands()

-- Check if palette is open
local is_open = state.is_open()

-- Dynamically add a command
state.add_command({
  name = "My Command",
  description = "Description here",
  command = "echo 'Hello'",
  category = "Custom",
})

-- Remove a command by name
state.remove_command("My Command")
```

## UI Customization

### Border Styles

Available border styles:
- `"single"`: Single line border
- `"double"`: Double line border
- `"rounded"`: Rounded corners (default)
- `"solid"`: Solid border
- `"shadow"`: Shadow effect

### Example with Custom UI

```lua
require("command-palette").setup({
  commands = { ... },
  ui = {
    border = "double",
    width = 80,
    max_height = 25,
    title = " 🚀 My Commands ",
    show_icons = false,  -- Disable icons
  },
})
```

## License

MIT

## Credits

Built with [nui.nvim](https://github.com/MunifTanjim/nui.nvim) by [@MunifTanjim](https://github.com/MunifTanjim).
