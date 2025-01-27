local M = {}

---@class VirtualTextConfig
---@field namespace integer Neovim namespace ID for virtual text
---@field highlights VirtualTextHighlights Highlight group definitions

---@class VirtualTextHighlights
---@field completion string Highlight group for completion text
---@field replace_range string Highlight group for replacement range

-- Virtual text namespace and highlights
---@type VirtualTextConfig
M.virtual_text = {
  namespace = vim.api.nvim_create_namespace('TabbyCompletion'),
  highlights = {
    completion = 'TabbyCompletion',
    replace_range = 'TabbyCompletionReplaceRange'
  }
}

---@return integer
local function _get_char_count_from_col()
  local line = vim.fn.getline('.')
  local col = vim.fn.col('.')
  return vim.fn.strchars(string.sub(line, 1, col - 1))
end

---@param virt_lines string[]
---@return nil
function M.render_virtual_text(virt_lines)
  -- Check if we're in insert mode
  local mode = vim.api.nvim_get_mode().mode

  -- Only set extmark if we're in insert mode
  if mode ~= 'i' then
    return
  end

  vim.api.nvim_buf_set_extmark(0, M.virtual_text.namespace, vim.fn.line('.') - 1, vim.fn.col('.') - 1, {
    virt_lines = virt_lines
  })
end

---@param item CompletionItem
---@return string[]
function M.prepare_virtual_text(item)
  local char_count_col = _get_char_count_from_col()
  local prefix_replace_chars = char_count_col - item.range.start.character
  local suffix_replace_chars = item.range["end"].character - char_count_col
  local text = string.sub(item.insertText, prefix_replace_chars)

  if #text == 0 then
    return {}
  end

  local current_line = vim.fn.getline('.')
  local current_line_suffix = string.sub(current_line, vim.fn.col('.'))

  if vim.fn.strchars(current_line_suffix) < suffix_replace_chars then
    return {}
  end

  -- Split text into lines
  local text_lines = vim.split(text, "\n", { plain = true })

  -- Handle first line
  if #text_lines[1] > 0 then
    vim.api.nvim_buf_set_extmark(0, M.virtual_text.namespace, vim.fn.line('.') - 1, vim.fn.col('.') - 1, {
      virt_text = { { text_lines[1], M.virtual_text.highlights.completion } },
      virt_text_win_col = vim.fn.virtcol('.') - 1,
    })
  end

  -- Handle additional lines if any
  if #text_lines > 1 then
    local virt_lines = {}
    for i = 2, #text_lines do
      table.insert(virt_lines, { { text_lines[i], M.virtual_text.highlights.completion } })
    end

    return virt_lines
  end

  return {}
end

---@param item CompletionItem
---@return nil
function M.insert_text(item)
  local text_to_insert = item.insertText

  -- Remove the part of the line specified in the replace range of the item
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_set_current_line(line:sub(1, item.range.start.character) .. line:sub(item.range["end"].character + 1))

  -- Figure out if this if the cursor is at the last position of the line. It
  -- is imporatant, because if it is then the only place it can be positioned
  -- is on the symbol we want to insert new text after. If it is not, then it
  -- is usually positioned on the next symbol.
  --
  -- This is when we're in the middle of the line and we want to insert text
  -- between the parens
  --
  -- def test_func() -> None
  --               ^
  -- And this is what happens when we're in the end of the line and want to
  -- insert text after the paren
  --
  -- def test_func(
  --              ^
  local after = false
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  -- TODO: we probably don't need this, but leaving for now in case some edge
  -- cases found
  -- vim.fn.cursor(row, item.range.start.character + 1)
  line = vim.api.nvim_get_current_line()
  if #line - 1 == col then
    after = true
  end
  vim.api.nvim_put(vim.split(text_to_insert, '\n', { plain = true }), 'c', after, true)
end

return M
