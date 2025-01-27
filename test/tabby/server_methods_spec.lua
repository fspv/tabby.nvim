-- test/spec/buffer_spec.lua
local module = require('tabby.server_methods') -- replace with actual plugin name

describe('notify_buffer_change', function()
  local test_file1 = vim.fn.getcwd() .. '/test_data/test1.txt'
  local test_file2 = vim.fn.getcwd() .. '/test_data/test2.txt'

  -- Helper function to create test files
  local function create_test_file(path, content)
    local file = io.open(path, 'w')
    if file == nil then
      return
    end
    file:write(content or 'test content\nline 2\nline 3\n')
    file:close()
  end

  before_each(function()
    -- To make sure window sizes are always the same
    vim.o.columns = 120
    vim.o.lines = 40

    -- Create test files
    create_test_file(test_file1)
    create_test_file(test_file2)

    -- Setup test environment
    vim.api.nvim_command('enew')                  -- Create new buffer
    vim.api.nvim_command('edit ' .. test_file1)   -- Open first test file
    vim.api.nvim_command('vsplit ' .. test_file2) -- Open second test file in split
  end)

  after_each(function()
    -- Clean up test files
    os.remove(test_file1)
    os.remove(test_file2)

    -- Close all buffers
    vim.api.nvim_command('silent! %bdelete!')
  end)

  it('should notify LSP client with correct parameters', function()
    local notifications = {}
    local mock_client = {
      notify = function(method, params)
        table.insert(notifications, {
          method = method,
          params = params
        })
        return true
      end
    }

    local current_buf = vim.api.nvim_get_current_buf()

    -- Call the function
    module.notify_buffer_change(current_buf, mock_client)

    -- Expected notification structure
    local expected = {
      method = 'tabby/editors/didChangeActiveEditor',
      params = {
        activeEditor = {
          uri = vim.uri_from_fname(test_file2),
          range = {
            start = { line = 0, character = 0 },
            ['end'] = { line = 3, character = 0 }
          }
        },
        visibleEditors = {
          {
            uri = vim.uri_from_fname(test_file1),
            range = {
              start = { line = 1, character = 0 },
              ['end'] = { line = 3, character = 0 }
            }
          }
        }
      }
    }

    -- Single assertion comparing the full structure
    assert.are.same(expected, notifications[1])
  end)

  it('should handle LSP client notification failure', function()
    local current_buf = vim.api.nvim_get_current_buf()

    -- Create a failing mock client
    local failing_client = {
      notify = function()
        return false
      end
    }

    -- Call the function
    module.notify_buffer_change(current_buf, failing_client)

    -- we only verify here it doesn't fail
  end)

  it('should handle non-file buffers', function()
    local notifications = {}
    local mock_client = {
      notify = function(method, params)
        table.insert(notifications, {
          method = method,
          params = params
        })
        return true
      end
    }

    -- Create a scratch buffer
    vim.api.nvim_command('enew')
    local scratch_buf = vim.api.nvim_get_current_buf()

    -- Call the function
    module.notify_buffer_change(scratch_buf, mock_client)

    -- Verify no notification was sent
    assert.equals(0, #notifications)
  end)
end)
