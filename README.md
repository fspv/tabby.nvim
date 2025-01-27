# tabby.nvim

A Neovim plugin that provides inline completion functionality integrated with LSP.

## Features

- Automatic and manual inline completion triggers
- LSP integration for accurate completions
- Virtual text display of completion suggestions
- Semantic token support
- Custom keybindings for completion actions

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'fspv/tabby.nvim',
  requires = {
    'nvim-lua/plenary.nvim', -- for tests
  }
}
```

Using `lazy.nvim`:
```lua
require("lazy").setup({
  {
    "fspv/tabby.nvim",
  },
})
```

## Configuration

```lua
local lspconfig = require("lspconfig")
local lspconfig_configs = require("lspconfig.configs")

if not lspconfig_configs.tabby then
  lspconfig_configs.tabby = {
    default_config = {
      name = "tabby",
      filetypes = { "*" },
      cmd = { "npx", "tabby-agent", "--stdio" },
      single_file_support = true,
      init_options = {
        clientCapabilities = {
          textDocument = {
            completion = true,
            inlineCompletion = true,
          },
          tabby = {
            languageSupport = true,
          },
        },
      },
      root_dir = vim.fs.dirname(vim.fs.find('.git', { path = ".", upward = true })[1]),
    }
  }
end

lspconfig.tabby.setup({})

require('tabby').setup({
  inline_completion = {
    trigger = "auto", -- or "manual"
    keybindings = {
      accept = "<Tab>",
      trigger_or_dismiss = "<C-\\>"
    }
  }
})
```

## Default Keybindings

- `<Tab>`: Accept current completion
- `<C-\>`: Trigger or dismiss completion

## Development

### Running Tests

Tests are written using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim). To run the tests:

```bash
nvim --headless -c "PlenaryBustedDirectory test/tabby"
```
