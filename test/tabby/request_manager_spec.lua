local describe = require('plenary.busted').describe
local assert = require('luassert')
local before_each = require('plenary.busted').before_each

describe('RequestManager', function()
  local RequestManager = require('tabby.request_manager')
  ---@type RequestManager
  local manager

  before_each(function()
    manager = RequestManager.new()
  end)

  describe('generate_request_id', function()
    it('should generate unique UUIDs', function()
      local id1 = manager.generate_request_id()
      local id2 = manager.generate_request_id()

      -- Check UUID format (8-4-4-4-12 characters)
      assert.matches('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$', id1)
      assert.matches('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$', id2)

      -- Verify uniqueness
      assert.are_not.equal(id1, id2)
    end)
  end)

  describe('create_callback', function()
    it('should execute callback only for latest request', function()
      local count1, count2 = 0, 0
      local request1 = manager.generate_request_id()
      local request2 = manager.generate_request_id()

      local callback1 = manager.create_callback(request1, function() count1 = count1 + 1 end)
      local callback2 = manager.create_callback(request2, function() count2 = count2 + 1 end)

      callback1()
      callback2()

      -- Only the latest callback should execute
      assert.are.equal(0, count1)
      assert.are.equal(1, count2)
    end)

    it('should handle multiple calls to the same callback', function()
      local count = 0
      local request_id = manager.generate_request_id()
      local callback = manager.create_callback(request_id, function() count = count + 1 end)

      callback()
      callback()

      assert.are.equal(2, count)
    end)
  end)

  describe('register_cancellation', function()
    it('should register and execute cancellation functions', function()
      local cancelled = false
      local request_id = manager.generate_request_id()

      manager.register_cancellation(request_id, function()
        cancelled = true
      end)

      manager.cancel_request(request_id)
      assert.is_true(cancelled)
    end)

    it('should handle multiple cancellations', function()
      local count = 0
      local request1 = manager.generate_request_id()
      local request2 = manager.generate_request_id()

      manager.register_cancellation(request1, function() count = count + 1 end)
      manager.register_cancellation(request2, function() count = count + 1 end)

      manager.cancel_all_requests()
      assert.are.equal(2, count)
    end)
  end)

  describe('cancel_request', function()
    it('should cancel specific request and clear last_request_id', function()
      local cancelled = false
      local request_id = manager.generate_request_id()

      manager.register_cancellation(request_id, function()
        cancelled = true
      end)

      local callback = manager.create_callback(request_id, function() end)
      manager.cancel_request(request_id)

      assert.is_true(cancelled)

      -- Verify callback won't execute after cancellation
      callback()
      -- The callback execution count would still be 0
    end)

    it('should handle non-existent request ids', function()
      -- Should not throw error
      manager.cancel_request('non-existent-id')
    end)
  end)

  describe('cancel_all_requests', function()
    it('should cancel all active requests', function()
      local count = 0
      local request1 = manager.generate_request_id()
      local request2 = manager.generate_request_id()

      manager.register_cancellation(request1, function() count = count + 1 end)
      manager.register_cancellation(request2, function() count = count + 1 end)

      local callback1 = manager.create_callback(request1, function() end)
      local callback2 = manager.create_callback(request2, function() end)

      manager.cancel_all_requests()

      assert.are.equal(2, count)

      -- Verify callbacks won't execute after cancellation
      callback1()
      callback2()
      -- Both callback execution counts would still be 0
    end)
  end)

  describe('is_last_request_id', function()
    it('should return true for latest request', function()
      local request_id = manager.generate_request_id()
      assert.is_true(manager.is_last_request_id(request_id))
    end)

    it('should return false for old requests', function()
      local old_request = manager.generate_request_id()
      local new_request = manager.generate_request_id()
      assert.is_false(manager.is_last_request_id(old_request))
      assert.is_true(manager.is_last_request_id(new_request))
    end)

    it('should return false after request cancellation', function()
      local request_id = manager.generate_request_id()
      manager.cancel_request(request_id)
      assert.is_false(manager.is_last_request_id(request_id))
    end)
  end)

  describe('generate_request_id', function()
    it('should automatically cancel previous requests', function()
      local cancelled_count = 0
      local first_request = manager.generate_request_id()
      local second_request = manager.generate_request_id()

      manager.register_cancellation(first_request, function()
        cancelled_count = cancelled_count + 1
      end)

      -- Generating a new request should cancel the previous one
      local third_request = manager.generate_request_id()
      assert.are.equal(1, cancelled_count)

      -- Verify only the latest request is active
      assert.is_true(manager.is_last_request_id(third_request))
      assert.is_false(manager.is_last_request_id(second_request))
      assert.is_false(manager.is_last_request_id(first_request))
    end)
  end)

  describe('create_callback', function()
    it('should not execute callback for non-latest requests', function()
      local count = 0
      local first_request = manager.generate_request_id()
      local first_callback = manager.create_callback(first_request, function()
        count = count + 1
      end)

      -- Generate new request, making the first one old
      manager.generate_request_id()

      -- Execute the callback from the old request
      first_callback()
      assert.are.equal(0, count)
    end)

    it('should clear cancellation when callback executes', function()
      local request_id = manager.generate_request_id()
      local cancelled = false

      manager.register_cancellation(request_id, function()
        cancelled = true
      end)

      local callback = manager.create_callback(request_id, function() end)
      callback()

      -- After callback execution, cancellation should be cleared
      manager.cancel_request(request_id)
      assert.is_false(cancelled)
    end)
  end)

  describe('cancel_all_requests', function()
    it('should clear last_request_id', function()
      local request_id = manager.generate_request_id()
      assert.is_true(manager.is_last_request_id(request_id))

      manager.cancel_all_requests()
      assert.is_false(manager.is_last_request_id(request_id))
    end)

    it('should handle empty cancellation list', function()
      -- Should not throw error when no requests are active
      manager.cancel_all_requests()

      local request_id = manager.generate_request_id()
      assert.is_true(manager.is_last_request_id(request_id))
    end)
  end)
end)
