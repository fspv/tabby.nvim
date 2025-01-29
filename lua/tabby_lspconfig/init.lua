return {
  -- Configures lspconfig tabby plugin. needs to be called before
  -- `lspconfig.tabby.setup()`. The reason it exists, is because the
  -- [upstream tabby_ml lspconfig plugin](https://github.com/neovim/nvim-lspconfig/blob/1f941b3668151963fca3e1230922c433ea4b7b64/lua/lspconfig/configs/tabby_ml.lua)
  -- is outdated and uses an incorrect command. Additionally, the default
  -- `init_options` are not sufficient to support all the functionality of this
  -- plugin. In particular, `languageSupport` feature is missing, which is
  -- required to enable semantic tokens to be sent to the LLM.
  setup = function()
    local lspconfig_configs = require("lspconfig.configs")

    ---@type lspconfig.Config
    local default_lsp_config = {
      default_config = {
        name = "tabby",
        filetypes = { "*" },
        -- TODO: how to install this? Create a minimal nix profile and docker
        -- container to test installation
        cmd = { "npx", "tabby-agent", "--stdio" },
        single_file_support = true,
        init_options = {
          clientCapabilities = {
            textDocument = {
              -- Support for completion dropdown
              completion = true,
              -- Support for the completion with the virtual text
              inlineCompletion = true,
            },
            tabby = {
              -- Enable semantic tokens support. Semantic tokens need to be
              -- available on the main language server attached to the buffer.
              -- For examply, pyright doesn't support semantic tokens at the
              -- moment and they not enabled by default in gopls
              languageSupport = true,
            },
          },
        },
        root_dir = function()
          vim.fs.dirname(vim.fs.find('.git', { path = ".", upward = true })[1])
        end
      }
    }

    if not lspconfig_configs.tabby then
      lspconfig_configs.tabby = default_lsp_config
    end
  end
}
