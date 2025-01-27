local request_manager = require("tabby.request_manager").new()
local virtual_text = require("tabby.virtual_text")
local schema = require("tabby.schema")

local M = {}

---@class InlineCompletionConfig
---@field trigger "auto"|"manual" Whether completion triggers automatically or manually
---@field keybindings InlineCompletionKeybindings Key mappings for completion actions

---@class InlineCompletionKeybindings
---@field accept string Keybinding to accept completion
---@field trigger_or_dismiss string Keybinding to trigger or dismiss completion

-- Plugin configuration with defaults
---@type { inline_completion: InlineCompletionConfig, debug: boolean }
local plugin_config = {
  inline_completion = {
    trigger = "auto", -- or "manual"
    keybindings = {
      accept = "<Tab>",
      trigger_or_dismiss = "<C-\\>"
    }
  },
  debug = false
}

---@param msg string The message to log
---@param level? integer The log level (vim.log.levels)
---@return nil
function M.log(msg, level)
  if plugin_config.debug or vim.env.PLENARY_TEST ~= nil then
    msg = string.format("tabby: %s", msg)
    vim.notify(msg, level, {})
  end
end

---@class CompletionContext
---@field buf integer
---@field offset integer
---@field modification boolean
---@field trigger_kind integer

---@class CompletionState
---@field request_context CompletionContext|nil The context of the current completion request
---@field completion_list CompletionList|nil The current list of completion items

-- Current completion state
---@type CompletionState
local completion_state = {
  request_context = nil,
  completion_list = nil,
}


---@return vim.lsp.Client|nil
local function _get_client()
  return vim.lsp.get_clients({
    name = "tabby"
  })[1]
end


---@param inline_completion_params lsp.TextDocumentPositionParams
---@param request_id string
---@param callback fun(completion_list: CompletionList)
function M.request_inline_completion(inline_completion_params, request_id, callback)
  M.log(
    string.format(
      "inline_completion_params: %s, request_id: %s",
      vim.inspect(inline_completion_params),
      request_id
    ),
    vim.log.levels.DEBUG
  )
  local lsp_client = _get_client()
  if lsp_client == nil then
    return
  end

  local wrapped_callback = request_manager.create_callback(request_id, callback)
  local status, lsp_request_id = lsp_client.request(
    "textDocument/inlineCompletion",
    inline_completion_params,
    function(err, result)
      if err ~= nil then
        M.log(string.format("Error: %s", vim.inspect(err)), vim.log.levels.ERROR)
        return
      end
      wrapped_callback(result)
    end
  )
  if lsp_request_id then
    request_manager.register_cancellation(
      request_id,
      function() lsp_client.cancel_request(lsp_request_id) end
    )
  end

  if not status then
    vim.notify("Tabby LSP client is down")
  end
end

-- Completion service implementation
---comment
---@param is_manually boolean
---@return CompletionContext
local function _create_completion_context(is_manually)
  ---@diagnostic disable-next-line: unused-local
  local bufnum, lnum, col, off = vim.fn.getpos('.')
  local current_offset = 0
  if lnum ~= nil then
    current_offset = vim.fn.line2byte(lnum) + col - 1
  end

  return {
    buf = vim.fn.bufnr(),
    offset = current_offset,
    modification = vim.bo.modified,
    trigger_kind = is_manually and 1 or 2
  }
end

---Handle inline completion response from tabby agent
---@param params CompletionContext
---@param result CompletionList
local function _handle_completion_response(params, result)
  M.log(string.format('params: %s, result: %s', vim.inspect(params), vim.inspect(result)), vim.log.levels.TRACE)
  if not vim.deep_equal(completion_state.request_context, params) then
    return
  end

  local ok, err = schema.validate_completion_list(result)
  if not ok then
    M.log(string.format('Invalid completion list: %s', err), vim.log.levels.ERROR)
    return
  end

  M.clear()

  if #result.items == 0 then
    return
  end

  completion_state.completion_list = result

  local item = result.items[1]
  local virt_lines = virtual_text.prepare_virtual_text(item)
  if #virt_lines > 0 then
    virtual_text.render_virtual_text(virt_lines)
  end
end

---@param is_manually boolean
function M.trigger(is_manually)
  M.log(string.format("triggering completion: %s", is_manually and "manually" or "auto"), vim.log.levels.DEBUG)
  if plugin_config.inline_completion.trigger ~= "auto" and not is_manually then
    return
  end

  local params = _create_completion_context(is_manually)
  ---@type lsp.TextDocumentPositionParams|nil
  local inline_completion_params = vim.lsp.util.make_position_params()
  if inline_completion_params == nil then
    return
  end

  -- TODO: for some reason this field doesn't exist in upstream LSP spec
  ---@diagnostic disable-next-line: inject-field
  inline_completion_params.context = {}
  inline_completion_params.context.triggerKind = params.trigger_kind


  local request_id = request_manager.generate_request_id()

  -- Delay to avoid issuing requests when the user is typing some text
  -- TODO: make delay configurable
  vim.wait(
    100,
    function()
      if not request_manager.is_last_request_id(request_id) then
        return true
      end
      completion_state.request_context = params

      M.request_inline_completion(
        inline_completion_params,
        request_id,
        function(result) _handle_completion_response(params, result) end
      )

      return true
    end
  )
end

---@return nil
function M.accept()
  M.log("calling accept()", vim.log.levels.DEBUG)
  local function insert_tab()
    vim.api.nvim_put({ "\t" }, "c", true, true)
  end

  -- If there is nothing to complete (i.e. regular typing), just use the accept
  -- character as a regular character
  local ok, err = schema.validate_completion_list(completion_state.completion_list)
  if not ok or #completion_state.completion_list.items == 0 then
    M.log(string.format('Invalid completion list: %s', err), vim.log.levels.ERROR)
    return insert_tab()
  end

  local item = completion_state.completion_list.items[1]

  ok, err = schema.validate_item(0, item)
  if not ok then
    M.log(string.format('Invalid item: %s', err), vim.log.levels.ERROR)
    return insert_tab()
  end

  M.clear()
  virtual_text.insert_text(item)
end

---@return nil
function M.clear()
  M.log("calling clear()", vim.log.levels.DEBUG)
  request_manager.cancel_all_requests()

  completion_state.request_context = nil
  completion_state.completion_list = nil

  -- Clear virtual text
  vim.api.nvim_buf_clear_namespace(0, virtual_text.virtual_text.namespace, 0, -1)
end

-- Setup function to initialize the plugin
---@param opts { inline_completion: InlineCompletionConfig }
function M.setup(opts)
  M.log(string.format("calling setup(%s)", vim.inspect(opts)), vim.log.levels.DEBUG)

  -- Merge user config with defaults
  plugin_config = vim.tbl_deep_extend("force", plugin_config, opts or {})

  -- Setup highlights
  vim.api.nvim_set_hl(0, virtual_text.virtual_text.highlights.completion, { fg = "#808080" })
  vim.api.nvim_set_hl(0, virtual_text.virtual_text.highlights.replace_range, { fg = "#303030", bg = "#808080" })

  -- Setup autocommands
  local group = vim.api.nvim_create_augroup('TabbyCompletion', { clear = true })

  vim.api.nvim_create_autocmd({ 'TextChangedI', 'CompleteChanged' }, {
    group = group,
    pattern = '*',
    callback = function()
      vim.schedule(function()
        M.clear()
        M.trigger(false)
      end)
    end
  })

  vim.api.nvim_create_autocmd('CursorMovedI', {
    group = group,
    pattern = '*',
    callback = function()
      vim.schedule(function()
        local context = _create_completion_context(false)
        if not vim.deep_equal(completion_state.request_context, context) then
          M.clear()
        end
      end)
    end
  })

  vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave' }, {
    group = group,
    pattern = '*',
    callback = function() M.clear() end
  })

  vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter', 'WinScrolled' }, {
    callback = function()
      vim.schedule(
        function()
          local lsp_client = _get_client()
          if lsp_client == nil then
            return
          end
          require("tabby.server_methods").notify_buffer_change(lsp_client.id, lsp_client)
        end
      )
    end
  })

  vim.keymap.set(
    'i',
    plugin_config.inline_completion.keybindings.accept,
    function()
      -- schedule, because otherwise it runs into this error:
      -- It says E565: Not allowed to change text or change window
      vim.schedule(function()
        M.accept()
      end)
    end,
    { noremap = true, expr = true, silent = true, nowait = true, desc = 'Tabby Inline completion' }
  )

  vim.keymap.set(
    'i',
    plugin_config.inline_completion.keybindings.trigger_or_dismiss,
    function()
      if completion_state.completion_list ~= nil and not vim.tbl_isempty(completion_state.completion_list) then
        M.clear()
      else
        M.trigger(true)
      end
      return ''
    end,
    { noremap = true, expr = true, silent = true, nowait = true, desc = 'Tabby Trigger or Dismiss Inline completion' }
  )

  -- Register handler for the custom LSP request
  vim.lsp.handlers["tabby/languageSupport/textDocument/declaration"] = require(
    "tabby.client_methods"
  ).handle_text_document_declaration
  vim.lsp.handlers["tabby/languageSupport/textDocument/semanticTokens/range"] = require(
    "tabby.client_methods"
  ).handle_semantic_tokens_range
end

return M
