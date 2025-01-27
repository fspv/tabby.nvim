local assert = require('luassert')
local describe = require('plenary.busted').describe
local it = require('plenary.busted').it
local before_each = require('plenary.busted').before_each

local client_methods = require('tabby.client_methods')

describe('tabby.client_methods', function()
  -- Mock LSP client and buffer setup
  ---@type vim.lsp.Client
  local mock_client
  local mock_bufnr = 1

  before_each(function()
    -- Set up fresh mocks for each test
    mock_client = {
      name = "test_lsp",
      request_sync = function() end,
      server_capabilities = {
        semanticTokensProvider = {
          legend = {
            tokenTypes = { "variable", "function", "class" },
            tokenModifiers = { "declaration", "definition" }
          }
        }
      }
    }
  end)

  describe('test_handle_text_document_declaration', function()
    it('should return result when LSP request succeeds', function()
      ---@type lsp.Declaration
      local expected_result = {
        {
          uri = "file:///test.lua",
          range = {
            start = { line = 0, character = 0 },
            ['end'] = { line = 0, character = 10 }
          }
        }
      }

      -- Mock successful response
      mock_client.request_sync = function()
        return { result = expected_result }
      end

      local params = {
        textDocument = { uri = "file:///test.lua" },
        position = { line = 0, character = 5 }
      }

      local result = client_methods.test_handle_text_document_declaration(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same(expected_result, result)
    end)

    it('should return error response when LSP request fails', function()
      -- Mock error response
      mock_client.request_sync = function()
        return { err = { code = 123, message = "Test error" } }
      end

      ---@type lsp.DeclarationParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        position = { line = 0, character = 5 }
      }

      local result = client_methods.test_handle_text_document_declaration(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same({ code = 123, message = "Test error" }, result)
    end)

    it('should return default error when response is nil', function()
      -- Mock nil response
      mock_client.request_sync = function()
        return nil
      end

      ---@type lsp.DeclarationParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        position = { line = 0, character = 5 }
      }

      local result = client_methods.test_handle_text_document_declaration(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same({
        error = {
          code = -32603,
          message = "Unhandled error during handling textDocument/definition"
        }
      }, result)
    end)
  end)

  describe('test_handle_text_document_definition', function()
    it('should return result when LSP request succeeds', function()
      ---@type lsp.Definition
      local expected_result = {
        {
          uri = "file:///test.lua",
          range = {
            start = { line = 0, character = 0 },
            ['end'] = { line = 0, character = 10 }
          }
        }
      }

      -- Mock successful response
      mock_client.request_sync = function()
        return { result = expected_result }
      end

      ---@type lsp.DefinitionParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        position = { line = 0, character = 5 }
      }

      local result = client_methods.test_handle_text_document_definition(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same(expected_result, result)
    end)

    it('should return error response when LSP request fails', function()
      -- Mock error response
      mock_client.request_sync = function()
        return { err = { code = 123, message = "Test error" } }
      end

      ---@type lsp.DefinitionParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        position = { line = 0, character = 5 }
      }

      local result = client_methods.test_handle_text_document_definition(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same({ code = 123, message = "Test error" }, result)
    end)

    it('should return default error when response is nil', function()
      -- Mock nil response
      mock_client.request_sync = function()
        return nil
      end

      ---@type lsp.DefinitionParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        position = { line = 0, character = 5 }
      }

      local result = client_methods.test_handle_text_document_definition(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same({
        error = {
          code = -32603,
          message = "Unhandled error during handling textDocument/definition"
        }
      }, result)
    end)
  end)

  describe('test_handle_semantic_tokens_range', function()
    it('should return tokens and legend when request succeeds', function()
      ---@type lsp.SemanticTokens
      local mock_tokens = {
        data = { 0, 4, 3, 1, 1 } -- Example token data
      }

      -- Mock successful response
      mock_client.request_sync = function()
        return { result = mock_tokens }
      end

      ---@type lsp.SemanticTokensRangeParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        range = {
          start = { line = 0, character = 0 },
          ['end'] = { line = 10, character = 0 }
        }
      }

      local result = client_methods.test_handle_semantic_tokens_range(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same({
        legend = mock_client.server_capabilities.semanticTokensProvider.legend,
        tokens = mock_tokens
      }, result)
    end)

    it('should return error when legend is not available', function()
      -- Remove legend from mock client
      mock_client.server_capabilities.semanticTokensProvider = nil

      ---@type lsp.SemanticTokensRangeParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        range = {
          start = { line = 0, character = 0 },
          ['end'] = { line = 10, character = 0 }
        }
      }

      local result = client_methods.test_handle_semantic_tokens_range(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same({
        error = {
          code = -32603,
          message = "Failed to get legend for semantic tokens"
        }
      }, result)
    end)

    it('should return error when token request fails', function()
      -- Mock failed token request
      mock_client.request_sync = function()
        return { err = "Failed to get tokens" }
      end

      ---@type lsp.SemanticTokensRangeParams
      local params = {
        textDocument = { uri = "file:///test.lua" },
        range = {
          start = { line = 0, character = 0 },
          ['end'] = { line = 10, character = 0 }
        }
      }

      local result = client_methods.test_handle_semantic_tokens_range(
        mock_client,
        mock_bufnr,
        params
      )

      assert.are.same({
        error = {
          code = -32603,
          message = "Failed to get semantic tokens"
        }
      }, result)
    end)
  end)
end)
