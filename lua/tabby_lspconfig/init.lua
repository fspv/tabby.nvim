return {
  setup = function()
    local lspconfig_configs = require("lspconfig.configs")

    ---@type lspconfig.Config
    local default_lsp_config = {
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
