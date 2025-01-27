local tabby = require("tabby")

local M = {}

---@class Buffer
---@field uri string
---@field range lsp.Range

-- Helper function to collect visible buffers
---@param except_active_buffer boolean
---@return Buffer[]
local function _collect_visible_buffers(except_active_buffer)
  ---@type Buffer[]
  local buffers = {}
  local bufs = vim.api.nvim_list_bufs()
  local current_buf = vim.api.nvim_get_current_buf()

  for _, bufnr in ipairs(bufs) do
    local fname = vim.api.nvim_buf_get_name(bufnr)

    -- Only include buffers with valid file paths
    if vim.fn.filereadable(fname) == 1 and fname:sub(1, 1) == "/" then
      -- Get visible lines range for the window
      local topline = vim.fn.line("w0")
      local botline = vim.fn.line("w$")

      -- Skip if we're excluding the active buffer
      if not (except_active_buffer and bufnr == current_buf) then
        ---@type Buffer
        local buffer = {
          uri = vim.uri_from_fname(fname),
          range = {
            start = { line = topline, character = 0 },
            ['end'] = { line = botline, character = 0 }
          }
        }

        table.insert(buffers, buffer)
      end
    end

    return buffers
  end

  -- Sort to put active buffer first
  table.sort(buffers, function(a, b)
    local current_uri = vim.uri_from_fname(vim.api.nvim_buf_get_name(current_buf))
    if a.uri == current_uri then return true end
    if b.uri == current_uri then return false end
    return false
  end)

  return buffers
end

-- Function to notify LSP about editor changes
---@param bufnr integer The number of the buffer
---@param client vim.lsp.Client The name of the LSP client
---@diagnostic disable-next-line: unused-local
function M.notify_buffer_change(bufnr, client)
  local current_buf = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(current_buf)

  if vim.fn.filereadable(fname) == 1 and fname:sub(1, 1) == "/" then
    local win = vim.api.nvim_get_current_win()
    local win_height = vim.api.nvim_win_get_height(win)
    local win_info = vim.fn.getwininfo(win)[1]
    local topline = win_info.topline - 1
    local botline = math.min(topline + win_height, vim.api.nvim_buf_line_count(current_buf))

    local params = {
      activeEditor = {
        uri = vim.uri_from_fname(fname),
        range = {
          start = { line = topline, character = 0 },
          ['end'] = { line = botline, character = 0 }
        }
      },
      visibleEditors = _collect_visible_buffers(true)
    }

    tabby.log(string.format("Sending %s to LSP client", vim.inspect(params)), vim.log.levels.DEBUG)
    -- Send notification to all active LSP clients
    local notify_success = client.notify(
      "tabby/editors/didChangeActiveEditor",
      params
    )
    if not notify_success then
      tabby.log(string.format("Failed to send %s to LSP client", vim.inspect(params)), vim.log.levels.ERROR)
    end
  end
end

return M
