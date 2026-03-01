--- Deferred-dispatch event bus.
--
-- Events emitted during a tick are queued and not dispatched until flush()
-- is called. This prevents re-entrancy bugs where handlers trigger cascading
-- event chains mid-tick.
--
-- Error modes:
--   "tolerant" (default) — handler errors are caught, logged, and remaining
--     handlers for that event continue to fire. Bus is always safe to use.
--   "strict" — handler errors propagate up from flush(). Remaining handlers
--     for that event do NOT fire. The _flushing flag is reset before re-raising
--     so the bus is not left in a stuck state. Recommended for development.
--
-- Usage:
--   local Bus = require("src.core.bus")
--   local bus = Bus.new()                            -- tolerant, print log
--   local bus = Bus.new({ error_mode = "strict" })   -- strict mode
--   local bus = Bus.new(my_log_fn)                   -- backward compat (tolerant)
--   bus:on("resource_collected", function(data) ... end)
--   bus:emit("resource_collected", { amount = 1 })
--   bus:flush()  -- dispatches all queued events

local Bus = {}
Bus.__index = Bus

--- Create a new Bus instance.
-- @param opts table|function|nil
--   If a table: opts.log (logging fn, default print), opts.error_mode ("strict"|"tolerant", default "tolerant")
--   If a function: treated as the log function with tolerant mode (backward compat)
--   If nil: uses print for logging and tolerant mode
-- @return Bus instance
function Bus.new(opts)
	local log_fn
	local error_mode

	if type(opts) == "function" then
		-- Backward compatibility: Bus.new(log_fn)
		log_fn = opts
		error_mode = "tolerant"
	elseif type(opts) == "table" then
		log_fn = opts.log or print
		error_mode = opts.error_mode or "tolerant"
	else
		log_fn = print
		error_mode = "tolerant"
	end

	return setmetatable({
		_queue = {},
		_handlers = {},
		_flushing = false,
		_log = log_fn,
		_error_mode = error_mode,
	}, Bus)
end

--- Subscribe a handler function to an event.
-- Handlers for the same event fire in registration order.
-- @param event string  event name
-- @param handler function  called with data payload when event is flushed
function Bus:on(event, handler)
	if not self._handlers[event] then
		self._handlers[event] = {}
	end
	table.insert(self._handlers[event], handler)
end

--- Unsubscribe a specific handler from an event.
-- If the handler is not registered, this is a no-op.
-- @param event string  event name
-- @param handler function  the exact handler reference to remove
function Bus:off(event, handler)
	local list = self._handlers[event]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i] == handler then
			table.remove(list, i)
		end
	end
end

--- Queue an event for deferred dispatch.
-- Handlers are NOT called immediately. Call flush() to dispatch.
-- If called during flush(), logs a warning and discards the event (re-entrancy guard).
-- @param event string  event name
-- @param data any  payload passed to handlers
function Bus:emit(event, data)
	if self._flushing then
		self._log("[Bus] Re-entrancy guard: emit('" .. event .. "') called during flush — discarded")
		return
	end
	table.insert(self._queue, { event, data })
end

--- Dispatch all queued events to their registered handlers.
-- Events are dispatched in emit order. Handlers fire in registration order.
--
-- In tolerant mode (default): handler errors are caught, logged, and remaining
-- handlers continue to fire.
--
-- In strict mode: a handler error re-raises from flush(). Remaining handlers
-- for that event do NOT fire. The _flushing flag is reset before re-raising.
--
-- The queue is cleared after all events are dispatched (or on error in strict mode).
function Bus:flush()
	self._flushing = true

	-- Snapshot the queue so any (illegal) emits during flush see an empty queue
	local queue = self._queue
	self._queue = {}

	for i = 1, #queue do
		local event = queue[i][1]
		local data = queue[i][2]
		local list = self._handlers[event]
		if list then
			for j = 1, #list do
				local ok, err = pcall(list[j], data)
				if not ok then
					if self._error_mode == "strict" then
						-- Reset flushing flag before re-raising so the bus is not stuck
						self._flushing = false
						error(err, 0)
					else
						self._log("[Bus] Handler error for event '" .. event .. "': " .. tostring(err))
					end
				end
			end
		end
	end

	self._flushing = false
end

return Bus
