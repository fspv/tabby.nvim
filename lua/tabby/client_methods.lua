-- This file contains methods exposed by neovim instance to reply to the requests from tabby agent.
-- These methods are used by tabby agent to fetch missing information about files (such as semantic tokens, etc).

local tabby = require("tabby")

local default_error_code = -32603 -- suggested by chatgpt, have no idea what it means


--- Helper function to get semantic tokens for a range
---@param client vim.lsp.Client
---@param bufnr integer
---@param range lsp.Range
---@return lsp.SemanticTokens|nil
local function _get_semantic_tokens(client, bufnr, range)
  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr)
    },
    range = range
  }

  -- Request semantic tokens from the client
  local tokens = client.request_sync('textDocument/semanticTokens/range', params, 1000, bufnr)
  if tokens and tokens.err then
    return nil
  end
  if tokens and tokens.result then
    return tokens.result
  end
  return nil
end

-- Helper function to get semantic token legend
---@param client vim.lsp.Client
---@return lsp.SemanticTokensLegend|nil
local function _get_semantic_token_legend(client)
  if client.server_capabilities.semanticTokensProvider then
    return client.server_capabilities.semanticTokensProvider.legend
  end
  return nil
end

---Get client, which is not tabby, attached to the buffer and supporting method
---@param uri string
---@param method string
---@return vim.lsp.Client|nil
local function _get_language_lsp_client(uri, method)
  local bufnr = vim.uri_to_bufnr(uri)

  -- Find a suitable LSP client that supports semantic tokens
  for _, client in pairs(
    vim.lsp.get_clients(
      {
        bufnr = bufnr,
        method = method,
      }
    )
  ) do
    if client.name ~= "tabby" then
      return client
    end
  end

  return nil
end

---This one is kinda weird, but tabby expact raw object, not the {result = x, err = y}, as it is returned by lsp
---@class WrappedErrorResponse
---@field error lsp.ResponseError

---Get definitions from lsp server
---@param client vim.lsp.Client
---@param bufnr integer
---@param params lsp.DefinitionParams
---@return lsp.Definition|WrappedErrorResponse|nil
local _handle_text_document_definition = function(client, bufnr, params)
  tabby.log(
    string.format("handling textDocument/definition for %s", vim.inspect(params)),
    vim.log.levels.DEBUG
  )
  local response = client.request_sync("textDocument/definition", params, 1000, bufnr)

  if response and response.result then
    tabby.log(
      string.format("textDocument/definition response: %s", vim.inspect(response.result)),
      vim.log.levels.DEBUG
    )
    return response.result
  end

  if response and response.err then
    tabby.log(
      string.format("textDocument/definition error: %s", vim.inspect(response.err)),
      vim.log.levels.ERROR
    )
    return response.err
  end

  tabby.log(
    string.format("textDocument/definition response: %s", vim.inspect(response)),
    vim.log.levels.ERROR
  )

  -- Often fails when editing files and syntax is temporarily incorrect
  return {
    error = {
      code = default_error_code,
      message = "Unhandled error during handling textDocument/definition"
    }
  }
end

---Get declarations from lsp server
---@param client vim.lsp.Client
---@param bufnr integer
---@param params lsp.DeclarationParams
---@return lsp.Declaration|WrappedErrorResponse|nil
local _handle_text_document_declaration = function(client, bufnr, params)
  tabby.log(
    string.format("handling textDocument/declaration for %s", vim.inspect(params)),
    vim.log.levels.DEBUG
  )

  local response = client.request_sync("textDocument/definition", params, 1000, bufnr)

  if response and response.result then
    tabby.log(
      string.format("textDocument/declaration response: %s", vim.inspect(response.result)),
      vim.log.levels.DEBUG
    )
    return response.result
  end

  if response and response.err then
    tabby.log(
      string.format("textDocument/declaration error: %s", vim.inspect(response.err)),
      vim.log.levels.ERROR
    )
    return response.err
  end

  tabby.log(
    string.format("textDocument/declaration response: %s", vim.inspect(response)),
    vim.log.levels.ERROR
  )

  -- Often fails when editing files and syntax is temporarily incorrect
  return {
    error = {
      code = default_error_code,
      message = "Unhandled error during handling textDocument/definition"
    }
  }
end

---@type lsp.Handler
---@diagnostic disable-next-line: unused-local
local _handle_text_document_declaration_wrapper = function(err, result, ctx, config)
  local uri = result.textDocument.uri
  local bufnr = vim.uri_to_bufnr(uri)

  -- Find a suitable LSP client that supports semantic tokens
  local client = _get_language_lsp_client(
    uri,
    "textDocument/declaration"
  )

  if client then
    return _handle_text_document_declaration(client, bufnr, result)
  end

  client = _get_language_lsp_client(
    uri,
    "textDocument/definition"
  )
  if client then
    return _handle_text_document_definition(client, bufnr, result)
  end
end

---@class SemanticTokensRangeResponse
---@field legend lsp.SemanticTokensLegend
---@field tokens lsp.SemanticTokens

---Get declarations from lsp server
---@param client vim.lsp.Client
---@param bufnr integer
---@param params lsp.SemanticTokensRangeParams
---@return SemanticTokensRangeResponse|WrappedErrorResponse
local _handle_semantic_tokens_range = function(client, bufnr, params)
  tabby.log(
    string.format("handling semantic tokens request for %s", vim.inspect(params)),
    vim.log.levels.DEBUG
  )

  local range = params.range

  -- Get the semantic tokens and legend
  local tokens = _get_semantic_tokens(client, bufnr, range)
  local legend = _get_semantic_token_legend(client)

  if not legend then
    tabby.log("Failed to get legend for semantic tokens", vim.log.levels.ERROR)
    return {
      error = {
        code = default_error_code,
        message = "Failed to get legend for semantic tokens"
      }
    }
  end

  if not tokens then
    tabby.log("Failed to get semantic tokens", vim.log.levels.ERROR)
    return {
      error = {
        code = default_error_code,
        message = "Failed to get semantic tokens"
      }
    }
  end

  -- Return the result
  local result = {
    legend = legend,
    tokens = tokens
  }

  tabby.log(string.format("got semantic tokens: %s", vim.inspect(result)), vim.log.levels.DEBUG)

  return result
end

-- Handler for the semantic tokens range request
---@type lsp.Handler
---@diagnostic disable-next-line: unused-local
local _handle_semantic_tokens_range_wrapper = function(err, result, ctx, config)
  local uri = result.textDocument.uri
  local bufnr = vim.uri_to_bufnr(uri)

  -- Find a suitable LSP client that supports semantic tokens
  local client = _get_language_lsp_client(
    uri,
    "textDocument/semanticTokens/range"
  )

  if not client then
    return {
      error = {
        code = default_error_code,
        message = "No LSP client available with semantic tokens support"
      }
    }
  end

  return _handle_semantic_tokens_range(client, bufnr, result)
end

local M = {
  handle_text_document_declaration = _handle_text_document_declaration_wrapper,
  handle_semantic_tokens_range = _handle_semantic_tokens_range_wrapper,
}

-- Test only methods, don't use
if vim.env.PLENARY_TEST ~= nil then
  M.test_handle_text_document_declaration = _handle_text_document_declaration
  M.test_handle_text_document_definition = _handle_text_document_definition
  M.test_handle_semantic_tokens_range = _handle_semantic_tokens_range
end

return M
