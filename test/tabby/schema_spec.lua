local describe = require('plenary.busted').describe
local assert = require('luassert')

local schema = require("tabby.schema")

describe("schema validation", function()
  -- Helper function to create a valid completion list
  local function create_valid_completion_list()
    return {
      isIncomplete = true,
      items = {
        {
          insertText = "example",
          range = {
            start = { line = 0, character = 0 },
            ["end"] = { line = 0, character = 5 }
          }
        }
      }
    }
  end

  describe("validate_completion_list", function()
    it("should accept valid completion list", function()
      local completion_list = create_valid_completion_list()
      local is_valid, error = schema.validate_completion_list(completion_list)
      assert.is_true(is_valid)
      assert.is_nil(error)
    end)

    it("should reject non-table input", function()
      local is_valid, error = schema.validate_completion_list("not a table")
      assert.is_false(is_valid)
      assert.equals("CompletionList must be a table", error)
    end)

    it("should reject missing isIncomplete", function()
      local completion_list = create_valid_completion_list()
      completion_list.isIncomplete = nil
      local is_valid, error = schema.validate_completion_list(completion_list)
      assert.is_false(is_valid)
      assert.equals("CompletionList.isIncomplete must be a boolean", error)
    end)

    it("should reject wrong type for isIncomplete", function()
      local completion_list = create_valid_completion_list()
      completion_list.isIncomplete = "true"
      local is_valid, error = schema.validate_completion_list(completion_list)
      assert.is_false(is_valid)
      assert.equals("CompletionList.isIncomplete must be a boolean", error)
    end)

    it("should reject missing items", function()
      local completion_list = create_valid_completion_list()
      completion_list.items = nil
      local is_valid, error = schema.validate_completion_list(completion_list)
      assert.is_false(is_valid)
      assert.equals("CompletionList.items must be a table", error)
    end)

    it("should reject non-table items", function()
      local completion_list = create_valid_completion_list()
      completion_list.items = "not a table"
      local is_valid, error = schema.validate_completion_list(completion_list)
      assert.is_false(is_valid)
      assert.equals("CompletionList.items must be a table", error)
    end)

    describe("completion item validation", function()
      it("should reject non-table item", function()
        local completion_list = create_valid_completion_list()
        ---@diagnostic disable-next-line
        completion_list.items[1] = "not a table"
        local is_valid, error = schema.validate_completion_list(completion_list)
        assert.is_false(is_valid)
        assert.equals("CompletionItem at index 1 must be a table", error)
      end)

      it("should reject missing insertText", function()
        local completion_list = create_valid_completion_list()
        completion_list.items[1].insertText = nil
        local is_valid, error = schema.validate_completion_list(completion_list)
        assert.is_false(is_valid)
        assert.equals("CompletionItem.insertText at index 1 must be a string", error)
      end)

      it("should reject non-string insertText", function()
        local completion_list = create_valid_completion_list()
        ---@diagnostic disable-next-line
        completion_list.items[1].insertText = 123
        local is_valid, error = schema.validate_completion_list(completion_list)
        assert.is_false(is_valid)
        assert.equals("CompletionItem.insertText at index 1 must be a string", error)
      end)

      describe("range validation", function()
        it("should reject missing range", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range = nil
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range at index 1 must be a table", error)
        end)

        it("should reject non-table range", function()
          local completion_list = create_valid_completion_list()
          ---@diagnostic disable-next-line
          completion_list.items[1].range = "not a table"
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range at index 1 must be a table", error)
        end)

        it("should reject missing start position", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range.start = nil
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range at index 1 must have start and end positions", error)
        end)

        it("should reject missing end position", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range["end"] = nil
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range at index 1 must have start and end positions", error)
        end)

        it("should reject negative line numbers", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range.start.line = -1
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range.start.line at index 1 must be non-negative", error)
        end)

        it("should reject negative character numbers", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range.start.character = -1
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range.start.character at index 1 must be non-negative", error)
        end)

        it("should reject start line after end line", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range.start.line = 1
          completion_list.items[1].range["end"].line = 0
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range at index 1: start line cannot be after end line", error)
        end)

        it("should reject start character after end character on same line", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range.start.character = 6
          completion_list.items[1].range["end"].character = 5
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_false(is_valid)
          assert.equals("CompletionItem.range at index 1: start character cannot be after end character on same line",
            error)
        end)

        it("should accept valid range on different lines", function()
          local completion_list = create_valid_completion_list()
          completion_list.items[1].range.start = { line = 0, character = 5 }
          completion_list.items[1].range["end"] = { line = 1, character = 0 }
          local is_valid, error = schema.validate_completion_list(completion_list)
          assert.is_true(is_valid)
          assert.is_nil(error)
        end)
      end)
    end)
  end)
end)
