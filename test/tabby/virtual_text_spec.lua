local it = require('plenary.busted').it
local describe = require('plenary.busted').describe
local assert = require('luassert')
local mock = require('luassert.mock')
local stub = require('luassert.stub')
local before_each = require('plenary.busted').before_each
local after_each = require('plenary.busted').after_each

-- Module to test
local virtual_text = require('tabby.virtual_text')

describe('virtual_text', function()
  before_each(function()
    -- Create a clean buffer for testing
    vim.cmd('new')
    -- Reset namespace
    vim.api.nvim_buf_clear_namespace(0, virtual_text.virtual_text.namespace, 0, -1)
  end)

  after_each(function()
    -- Clean up the test buffer
    vim.cmd('bdelete!')
    -- Reset any stubs
    mock.revert(vim.api)
  end)

  -- We'll test _get_char_count_from_col indirectly through prepare_virtual_text
  describe('prepare_virtual_text with character counting', function()
    it('should handle unicode characters correctly', function()
      local text = 'Hello, 世界'
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { text })
      vim.fn.cursor(1, #text)

      local item = {
        insertText = 'test',
        range = {
          start = { character = 4 },
          ['end'] = { character = 8 }
        }
      }

      local result = virtual_text.prepare_virtual_text(item)
      -- The result will depend on the character counting logic
      -- We mainly want to ensure it doesn't error with unicode
      assert(type(result) == 'table')
    end)
  end)

  describe('render_virtual_text', function()
    it('should render virtual text only in insert mode', function()
      local set_extmark_spy = stub(vim.api, 'nvim_buf_set_extmark')
      stub(vim.api, 'nvim_get_mode', function() return { mode = 'i' } end)

      local virt_lines = { { 'test', 'TabbyCompletion' } }
      virtual_text.render_virtual_text(virt_lines)

      assert.stub(set_extmark_spy).was_called(1)
      set_extmark_spy:revert()
    end)

    it('should not render virtual text in normal mode', function()
      local set_extmark_spy = stub(vim.api, 'nvim_buf_set_extmark')
      stub(vim.api, 'nvim_get_mode', function() return { mode = 'n' } end)

      local virt_lines = { { 'test', 'TabbyCompletion' } }
      virtual_text.render_virtual_text(virt_lines)

      assert.stub(set_extmark_spy).was_not_called()
      set_extmark_spy:revert()
    end)

    it('should not render in visual mode', function()
      local set_extmark_spy = stub(vim.api, 'nvim_buf_set_extmark')
      stub(vim.api, 'nvim_get_mode', function() return { mode = 'v' } end)

      local virt_lines = { { 'test', 'TabbyCompletion' } }
      virtual_text.render_virtual_text(virt_lines)

      assert.stub(set_extmark_spy).was_not_called()
    end)

    it('should handle empty virtual lines', function()
      local set_extmark_spy = stub(vim.api, 'nvim_buf_set_extmark')
      stub(vim.api, 'nvim_get_mode', function() return { mode = 'i' } end)

      virtual_text.render_virtual_text({})

      assert.stub(set_extmark_spy).was_called_with(
        0,
        virtual_text.virtual_text.namespace,
        vim.fn.line('.') - 1,
        vim.fn.col('.') - 1,
        { virt_lines = {} }
      )
    end)

    it('should handle multiple virtual lines', function()
      local set_extmark_spy = stub(vim.api, 'nvim_buf_set_extmark')
      stub(vim.api, 'nvim_get_mode', function() return { mode = 'i' } end)

      local virt_lines = {
        { 'line1', 'TabbyCompletion' },
        { 'line2', 'TabbyCompletion' }
      }
      virtual_text.render_virtual_text(virt_lines)

      assert.stub(set_extmark_spy).was_called_with(
        0,
        virtual_text.virtual_text.namespace,
        vim.fn.line('.') - 1,
        vim.fn.col('.') - 1,
        { virt_lines = virt_lines }
      )
    end)
  end)

  describe('prepare_virtual_text', function()
    it('should handle empty insert text', function()
      local item = {
        insertText = '',
        range = {
          start = { character = 0 },
          ['end'] = { character = 0 }
        }
      }

      local result = virtual_text.prepare_virtual_text(item)
      assert.same({}, result)
    end)

    it('should handle single line completion', function()
      -- Setup buffer content
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test()' })
      vim.fn.cursor(1, #'function test()')

      local set_extmark_spy = stub(vim.api, 'nvim_buf_set_extmark')

      local item = {
        insertText = 'arg1, arg2)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #'function test(' }
        }
      }

      local result = virtual_text.prepare_virtual_text(item)
      assert.same({}, result) -- Empty because single line is handled via extmark
      assert.stub(set_extmark_spy).was_called(1)
      set_extmark_spy:revert()
    end)

    it('should handle multiline completion', function()
      -- Setup buffer content
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test()' })
      vim.fn.cursor(1, #'function test()')

      local item = {
        insertText = 'arg1,\narg2)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #'function test(' }
        }
      }

      local result = virtual_text.prepare_virtual_text(item)
      assert.same({
        { { 'arg2)', virtual_text.virtual_text.highlights.completion } }
      }, result)
    end)

    it('should handle suffix replace characters correctly', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test(arg)' })
      vim.fn.cursor(1, #'function test(')

      local item = {
        insertText = 'newArg)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #'function test(arg)' }
        }
      }

      local result = virtual_text.prepare_virtual_text(item)
      assert.same({}, result) -- Empty because single line handled via extmark
    end)

    it('should handle empty lines in multiline text', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test()' })
      vim.fn.cursor(1, #'function test()')

      local item = {
        insertText = 'arg1,\n\narg2)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #'function test(' }
        }
      }

      local result = virtual_text.prepare_virtual_text(item)
      assert.same({
        { { '', virtual_text.virtual_text.highlights.completion } },
        { { 'arg2)', virtual_text.virtual_text.highlights.completion } }
      }, result)
    end)
  end)

  describe('insert_text', function()
    it('should handle unicode characters correctly', function()
      local initial_text = 'function 测试()'
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { initial_text })
      vim.fn.cursor(1, #initial_text - 1)

      local item = {
        insertText = '参数1)',
        range = {
          start = { character = #'function 测试(' },
          ['end'] = { character = #initial_text }
        }
      }

      virtual_text.insert_text(item)
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      assert.are.equal('function 测试(参数1)', line)
    end)

    it('should handle empty lines in middle of multiline text', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test()' })
      vim.fn.cursor(1, #'function test()' - 1)

      local item = {
        insertText = 'arg1,\n\narg2)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #'function test()' }
        }
      }

      virtual_text.insert_text(item)
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
      assert.same({
        'function test(arg1,',
        '',
        'arg2)'
      }, lines)
    end)

    it('should handle tabs in text', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test()' })
      vim.fn.cursor(1, #'function test()' - 1)

      local item = {
        insertText = 'arg1,\n\targ2)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #'function test()' }
        }
      }

      virtual_text.insert_text(item)
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
      assert.same({
        'function test(arg1,',
        '\targ2)'
      }, lines)
    end)


    it('should insert text with correct replacement', function()
      -- Setup buffer content
      local initial_text = 'function test()'
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { initial_text })
      -- set cursor in between parens
      vim.fn.cursor(1, #initial_text - 1)

      local set_current_line_spy = stub(vim.api, 'nvim_set_current_line')

      local item = {
        insertText = 'argument1)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #initial_text }
        }
      }

      virtual_text.insert_text(item)

      -- Verify deletion feedkeys call
      assert.stub(set_current_line_spy).was_called_with("function test(")
      set_current_line_spy:revert()
    end)

    it('should insert text with correct replacement inside parens in the middle of the string', function()
      -- Setup buffer content
      local initial_text = '   if len(ac) != len(activateRequests) {'
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { initial_text })
      -- set cursor in between parens after typed text
      vim.fn.cursor(1, 13)

      local item = {
        insertText = "tivateResult.Created",
        range = {
          ["end"] = {
            character = 12,
            line = 0
          },
          start = {
            character = 12,
            line = 0
          }
        }
      }

      virtual_text.insert_text(item)
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]

      assert.are.equal(
        '   if len(activateResult.Created) != len(activateRequests) {',
        line
      )
    end)


    it('should handle multiline text insertion', function()
      -- Setup buffer content
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test(' })
      vim.fn.cursor(1, #'function test(' + 1)

      local item = {
        insertText = 'arg1,\narg2)',
        range = {
          start = { character = #'function test(' },
          ['end'] = { character = #'function test(' }
        }
      }

      virtual_text.insert_text(item)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
      assert.same({
        'function test(arg1,',
        'arg2)'
      }, lines)
    end)

    it('should handle multiline text insertion in the middle', function()
      -- Setup buffer content
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test()' })
      vim.fn.cursor(1, 15)

      local item = {
        insertText = '\narg1,\narg2)',
        range = {
          start = {
            character = 14,
            line = 1,
          },
          ['end'] = {
            character = 15,
            line = 1,
          }
        }
      }

      virtual_text.insert_text(item)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
      assert.same({
        'function test(',
        'arg1,',
        'arg2)'
      }, lines)
    end)
  end)
end)
