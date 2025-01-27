---@class RequestManager
---@field private last_request_id string|nil
---@field private active_cancellations table<string, function>
---@field generate_request_id fun(): string
---@field create_callback fun(request_id: string, callback_fn: function): function
---@field register_cancellation fun(request_id: string, cancel_fn: function)
---@field cancel_request fun(request_id: string)
---@field cancel_all_requests fun()
---@field is_last_request_id fun(request_id: string): boolean
local RequestManager = {}

-- Internal helper functions
---@return string
local function generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  local random = math.random

  return (string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return string.format('%x', v)
  end))
end

---Creates a new request manager instance
---@return RequestManager
function RequestManager.new()
  local self = {}

  -- Private state
  local last_request_id = nil
  local active_cancellations = {}

  ---Generate a new unique request ID
  ---@return string request_id
  function self.generate_request_id()
    local request_id = generate_uuid()

    -- Cancel all previous requests
    for prev_request_id, cancel_fn in pairs(active_cancellations) do
      if prev_request_id ~= request_id then
        cancel_fn()
        active_cancellations[prev_request_id] = nil
      end
    end

    last_request_id = request_id
    -- Set for noop until a proper cancel callback is assigned. Necessary to properly
    -- handle the case where the request is cancelled before the callback is called.
    active_cancellations[request_id] = function() end
    return request_id
  end

  ---Create a wrapped callback that only executes if this is still the latest request
  ---@param request_id string
  ---@param callback_fn function
  ---@return function wrapped_callback
  function self.create_callback(request_id, callback_fn)
    -- Return wrapped callback
    return function(...)
      -- To make sure cancel is not called unnecessarily
      active_cancellations[request_id] = nil

      if self.is_last_request_id(request_id) then
        callback_fn(...)
      end
    end
  end

  ---Register a cancellation function for a request
  ---@param request_id string
  ---@param cancel_fn function
  function self.register_cancellation(request_id, cancel_fn)
    active_cancellations[request_id] = cancel_fn
  end

  ---Cancel a specific request
  ---@param request_id string
  function self.cancel_request(request_id)
    local cancel_fn = active_cancellations[request_id]
    if cancel_fn then
      cancel_fn()
      active_cancellations[request_id] = nil
    end

    if self.is_last_request_id(request_id) then
      last_request_id = nil
    end
  end

  ---Cancel all active requests
  function self.cancel_all_requests()
    -- There is a chance we get the state of active cancellations before after
    -- the last_request_id set, but before the active_cancellations is
    -- populated, so reset it to avoid callback to run if we haven't cleaned it
    -- up from active_cancellations due to the race
    last_request_id = nil

    for request_id, _ in pairs(active_cancellations) do
      self.cancel_request(request_id)
    end
  end

  ---@param request_id string
  ---@return boolean
  function self.is_last_request_id(request_id)
    return request_id == last_request_id
  end

  -- Initialize random seed for UUID generation
  math.randomseed(os.time())

  return self
end

return RequestManager
