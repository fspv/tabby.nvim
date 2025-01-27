---@class EventId
---@field choiceIndex number for example 0
---@field completionId string for example "cmpl-9f10e6c3-6d4b-4c69-bad1-948b4382487e"

---@class CompletionData
---@field eventId EventId

---@class CompletionItem Custom completion item object returned by tabby. Doesn't match lsp.CompletionItem
---@field insertText string The text to insert
---@field range lsp.Range The range to replace
---@field data CompletionData

---@class CompletionList Custom completion list object returned by tabby. Doesn't match lsp.CompletionList
---@field isIncomplete boolean
---@field items CompletionItem[]


local M = {}

---@param i integer
---@param item any
---@return boolean is_valid
---@return string? error_message
function M.validate_item(i, item)
  -- Check if item is a table
  if type(item) ~= "table" then
    return false, string.format("CompletionItem at index %d must be a table", i)
  end

  -- Validate insertText
  if type(item.insertText) ~= "string" then
    return false, string.format("CompletionItem.insertText at index %d must be a string", i)
  end

  -- Validate range
  if type(item.range) ~= "table" then
    return false, string.format("CompletionItem.range at index %d must be a table", i)
  end

  local range = item.range
  -- Check if range has start and end positions
  if type(range.start) ~= "table" or type(range["end"]) ~= "table" then
    return false, string.format("CompletionItem.range at index %d must have start and end positions", i)
  end

  -- Validate position fields
  local function validate_position(pos, pos_name)
    if type(pos.line) ~= "number" then
      return false, string.format("CompletionItem.range.%s.line at index %d must be a number", pos_name, i)
    end
    if type(pos.character) ~= "number" then
      return false, string.format("CompletionItem.range.%s.character at index %d must be a number", pos_name, i)
    end
    if pos.line < 0 then
      return false, string.format("CompletionItem.range.%s.line at index %d must be non-negative", pos_name, i)
    end
    if pos.character < 0 then
      return false, string.format("CompletionItem.range.%s.character at index %d must be non-negative", pos_name, i)
    end
    return true
  end

  local is_start_valid, start_error = validate_position(range.start, "start")
  if not is_start_valid then
    return false, start_error
  end

  local is_end_valid, end_error = validate_position(range["end"], "end")
  if not is_end_valid then
    return false, end_error
  end

  -- Validate range boundaries
  if range.start.line > range["end"].line then
    return false, string.format("CompletionItem.range at index %d: start line cannot be after end line", i)
  end
  if range.start.line == range["end"].line and range.start.character > range["end"].character then
    return false,
        string.format("CompletionItem.range at index %d: start character cannot be after end character on same line", i)
  end

  return true, nil
end

---@param completion_list any
---@return boolean is_valid
---@return string? error_message
function M.validate_completion_list(completion_list)
  -- Check if completion_list is a table
  if type(completion_list) ~= "table" then
    return false, "CompletionList must be a table"
  end

  -- Check isIncomplete field
  if type(completion_list.isIncomplete) ~= "boolean" then
    return false, "CompletionList.isIncomplete must be a boolean"
  end

  -- Check items field
  if type(completion_list.items) ~= "table" then
    return false, "CompletionList.items must be a table"
  end

  -- Validate each completion item
  for i, item in ipairs(completion_list.items) do
    local ok, err = M.validate_item(i, item)
    if not ok then
      return false, err
    end
  end

  return true, nil
end

return M
