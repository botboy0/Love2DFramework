--- love.thread channel transport layer with binser serialization.
---
--- Bridges server and client worlds by serializing events through a channel
--- abstraction. In production, channels are love.thread.Channel objects.
--- In tests, injectable mock channels are used so no love.thread is required.
---
--- Only events explicitly marked as networkable are forwarded. Events are
--- queued locally and flushed in batch once per tick (aligned with bus:flush).
---
--- Usage:
---   local Transport = require("src.core.transport")
---   local t = Transport.new({
---     outbound_channel = love.thread.getChannel("server_to_client"),
---     inbound_channel  = love.thread.getChannel("client_to_server"),
---   })
---   t:mark_networkable("player_moved")
---   -- each tick:
---   t:queue("player_moved", { x = 5, y = 10 })  -- called by bus handler
---   t:flush()                                     -- after bus:flush()
---   local msgs = t:receive_all()                  -- incoming from other side

local binser = require("lib.binser")

local Transport = {}
Transport.__index = Transport

--- Default warning threshold for outbound queue depth.
--- Warn (but do not drop) when more than this many messages are queued.
local DEFAULT_WARNING_THRESHOLD = 100

--- Create a new Transport instance.
--- @param opts table  options:
---   outbound_channel  love.thread.Channel or mock (push/pop/getCount)
---   inbound_channel   love.thread.Channel or mock (push/pop/getCount)
---   warning_threshold number|nil  queue depth that triggers a warning (default 100)
---   log               function|nil  logging function (default: print)
--- @return table transport
function Transport.new(opts)
	opts = opts or {}
	return setmetatable({
		_outbound = opts.outbound_channel,
		_inbound = opts.inbound_channel,
		_queue = {}, -- pending outbound messages (tables, not yet serialized)
		_networkable = {}, -- set: event_name -> true
		_warning_threshold = opts.warning_threshold or DEFAULT_WARNING_THRESHOLD,
		_log = opts.log or print,
	}, Transport)
end

--- Mark an event as networkable. Only networkable events are forwarded.
--- @param event_name string
function Transport:mark_networkable(event_name)
	self._networkable[event_name] = true
end

--- Check whether an event is marked as networkable.
--- @param event_name string
--- @return boolean
function Transport:is_networkable(event_name)
	return self._networkable[event_name] == true
end

--- Queue a networkable event for the next flush.
--- Non-networkable events are silently ignored.
--- Logs a warning (without dropping) if the queue exceeds the threshold.
--- @param event_name string
--- @param data table
function Transport:queue(event_name, data)
	if not self._networkable[event_name] then
		return
	end
	table.insert(self._queue, { event = event_name, data = data })
	-- Warn if queue depth exceeds threshold
	if #self._queue > self._warning_threshold then
		self._log(
			string.format(
				"[Transport] Queue depth %d exceeds warning threshold %d — consider flushing more frequently",
				#self._queue,
				self._warning_threshold
			)
		)
	end
end

--- Serialize a message table and push it directly to the outbound channel.
--- Bypasses the internal queue. Use queue() + flush() for batched sending.
--- @param message table  the message to serialize and send
function Transport:send(message)
	local raw = binser.serialize(message)
	self._outbound:push(raw)
end

--- Flush all queued outbound messages to the outbound channel.
--- Messages are serialized via binser and pushed in queue order.
--- The queue is cleared after all messages are sent.
function Transport:flush()
	if #self._queue == 0 then
		return
	end
	-- Snapshot the queue for clean flush
	local batch = self._queue
	self._queue = {}
	for i = 1, #batch do
		local raw = binser.serialize(batch[i])
		self._outbound:push(raw)
	end
end

--- Pop and deserialize one message from the inbound channel.
--- Returns nil if the channel is empty.
--- @return table|nil  deserialized message table, or nil
function Transport:receive()
	local raw = self._inbound:pop()
	if raw == nil then
		return nil
	end
	-- binser.deserialize returns (vals_array, n); our message is vals_array[1]
	local vals = binser.deserialize(raw)
	return vals[1]
end

--- Pop and deserialize all available messages from the inbound channel.
--- Returns an array of message tables (empty array if none available).
--- @return table[]  array of deserialized message tables
function Transport:receive_all()
	local messages = {}
	local msg = self:receive()
	while msg ~= nil do
		table.insert(messages, msg)
		msg = self:receive()
	end
	return messages
end

--- Null object transport stub.
--- All methods are no-ops. Used when transport is disabled so plugins
--- never need to guard with `if ctx.transport then`.
--- Transport.Null:is_networkable() always returns false.
--- Transport.Null:receive() always returns nil.
--- Transport.Null:receive_all() always returns an empty table.
local NullTransport = {}
NullTransport.__index = NullTransport

function NullTransport.new()
	return setmetatable({}, NullTransport)
end

function NullTransport:mark_networkable(_event_name) end

function NullTransport:is_networkable(_event_name)
	return false
end

function NullTransport:queue(_event_name, _data) end

function NullTransport:send(_message) end

function NullTransport:flush() end

function NullTransport:receive()
	return nil
end

function NullTransport:receive_all()
	return {}
end

Transport.Null = NullTransport

return Transport
