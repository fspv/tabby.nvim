# Unofficial Tabby Plugin for Neovim

Enhanced LSP-integrated inline completion plugin for Neovim that provides richer context for [Tabby](https://www.tabbyml.com/) suggestions. Built as an alternative to the [official vim plugin](https://github.com/TabbyML/tabby/tree/main/clients/vim) to improve completion quality through deeper Neovim LSP integration.

## Features Comparison

| Feature | This Plugin | Official Plugin |
|---------|------------------|-----------------|
| Basic Inline Completion | ✓ | ✓ |
| LSP symbol definition resolution | ✓ | ✗ |
| Multi-file Context Support | ✓ | ✗ |
| Cross-file Code Resolution | ✓ | ✗ |
| Telemetry Collection | ✗ | ✓ |
| Test Coverage | ✓ | ✗ |
| Vimscript | 0% | >0% |

The enhanced context gathering capabilities result in significantly improved code suggestions compared to the official plugin's "around cursor only" approach. Written entirely in Lua with no VimScript dependencies, it implements features available in the VSCode client but missing from the official Vim plugin.

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
require("tabby_lspconfig").setup()
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
mkdir test_data && nvim --headless -c "PlenaryBustedDirectory test/tabby"
```
