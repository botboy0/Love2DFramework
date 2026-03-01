--- Transport test suite.
---
--- Tests the love.thread channel transport layer with binser serialization.
--- Uses injectable mock channels so tests run without love.thread.

local Transport = require("src.core.transport")

--- Create a mock channel (mimics love.thread.Channel interface).
local function mock_channel()
	local items = {}
	return {
		push = function(_self, v)
			table.insert(items, v)
		end,
		pop = function(_self)
			return table.remove(items, 1)
		end,
		getCount = function(_self)
			return #items
		end,
	}
end

--- Create a transport with two mock channels for testing.
local function make_transport(opts)
	opts = opts or {}
	local outbound = opts.outbound or mock_channel()
	local inbound = opts.inbound or mock_channel()
	local t = Transport.new({
		outbound_channel = outbound,
		inbound_channel = inbound,
		warning_threshold = opts.warning_threshold,
		log = opts.log,
	})
	return t, outbound, inbound
end

describe("Transport", function()
	describe("new()", function()
		it("creates a transport instance", function()
			local t = make_transport()
			assert.is_not_nil(t)
		end)

		it("exposes send, receive, flush, mark_networkable, queue methods", function()
			local t = make_transport()
			assert.is_function(t.send)
			assert.is_function(t.receive)
			assert.is_function(t.flush)
			assert.is_function(t.mark_networkable)
			assert.is_function(t.queue)
		end)
	end)

	describe("mark_networkable() / is_networkable()", function()
		it("returns false for unmarked events", function()
			local t = make_transport()
			assert.is_false(t:is_networkable("some_event"))
		end)

		it("returns true after marking an event as networkable", function()
			local t = make_transport()
			t:mark_networkable("player_moved")
			assert.is_true(t:is_networkable("player_moved"))
		end)

		it("marking one event does not affect others", function()
			local t = make_transport()
			t:mark_networkable("player_moved")
			assert.is_false(t:is_networkable("other_event"))
		end)
	end)

	describe("queue()", function()
		it("does not enqueue non-networkable events", function()
			local t, outbound = make_transport()
			t:queue("non_networkable_event", { x = 1 })
			t:flush()
			assert.are.equal(0, outbound:getCount())
		end)

		it("enqueues networkable events", function()
			local t = make_transport()
			t:mark_networkable("player_moved")
			assert.has_no.errors(function()
				t:queue("player_moved", { x = 5, y = 10 })
			end)
		end)
	end)

	describe("send()", function()
		it("serializes a Lua table and pushes to outbound channel", function()
			local t, outbound = make_transport()
			t:send({ event = "test_event", data = { x = 1 } })
			assert.are.equal(1, outbound:getCount())
		end)

		it("pushed value is a string (serialized bytes)", function()
			local t, outbound = make_transport()
			t:send({ event = "test_event", data = {} })
			local raw = outbound:pop()
			assert.is_string(raw)
		end)
	end)

	describe("receive()", function()
		it("returns nil when channel is empty", function()
			local t = make_transport()
			local msg = t:receive()
			assert.is_nil(msg)
		end)

		it("pops one message from inbound channel and deserializes it", function()
			local t, _outbound, inbound = make_transport()
			-- Manually push a serialized message to inbound
			local binser = require("lib.binser")
			local raw = binser.serialize({ event = "test_event", data = { val = 42 } })
			inbound:push(raw)
			local msg = t:receive()
			assert.is_table(msg)
			assert.are.equal("test_event", msg.event)
			assert.are.equal(42, msg.data.val)
		end)

		it("calling receive again on empty channel returns nil", function()
			local t, _outbound, inbound = make_transport()
			local binser = require("lib.binser")
			local raw = binser.serialize({ event = "e", data = {} })
			inbound:push(raw)
			t:receive() -- consume it
			assert.is_nil(t:receive())
		end)
	end)

	describe("flush()", function()
		it("is a no-op when queue is empty", function()
			local t, outbound = make_transport()
			assert.has_no.errors(function()
				t:flush()
			end)
			assert.are.equal(0, outbound:getCount())
		end)

		it("pushes queued networkable events to outbound channel", function()
			local t, outbound = make_transport()
			t:mark_networkable("player_moved")
			t:queue("player_moved", { x = 1, y = 2 })
			t:queue("player_moved", { x = 3, y = 4 })
			t:flush()
			assert.are.equal(2, outbound:getCount())
		end)

		it("clears the queue after flushing", function()
			local t, outbound = make_transport()
			t:mark_networkable("player_moved")
			t:queue("player_moved", { x = 1 })
			t:flush()
			outbound:pop() -- consume
			t:flush() -- second flush — should push nothing new
			assert.are.equal(0, outbound:getCount())
		end)
	end)

	describe("round-trip: queue -> flush -> receive", function()
		it("table sent matches table received after serialize/deserialize", function()
			-- Use same channel as both outbound and inbound for loopback test
			local loopback = mock_channel()
			local t = Transport.new({
				outbound_channel = loopback,
				inbound_channel = loopback,
			})
			t:mark_networkable("crafting_complete")
			t:queue("crafting_complete", { recipe = "iron_plate", count = 5 })
			t:flush()

			local msg = t:receive()
			assert.is_table(msg)
			assert.are.equal("crafting_complete", msg.event)
			assert.are.equal("iron_plate", msg.data.recipe)
			assert.are.equal(5, msg.data.count)
		end)

		it("multiple events round-trip in order", function()
			local loopback = mock_channel()
			local t = Transport.new({
				outbound_channel = loopback,
				inbound_channel = loopback,
			})
			t:mark_networkable("ev_a")
			t:mark_networkable("ev_b")
			t:queue("ev_a", { n = 1 })
			t:queue("ev_b", { n = 2 })
			t:flush()

			local m1 = t:receive()
			local m2 = t:receive()
			assert.are.equal("ev_a", m1.event)
			assert.are.equal("ev_b", m2.event)
			assert.are.equal(1, m1.data.n)
			assert.are.equal(2, m2.data.n)
		end)
	end)

	describe("receive_all()", function()
		it("returns empty table when no messages", function()
			local t = make_transport()
			local msgs = t:receive_all()
			assert.is_table(msgs)
			assert.are.equal(0, #msgs)
		end)

		it("returns all available messages", function()
			local loopback = mock_channel()
			local t = Transport.new({
				outbound_channel = loopback,
				inbound_channel = loopback,
			})
			t:mark_networkable("ev")
			t:queue("ev", { n = 1 })
			t:queue("ev", { n = 2 })
			t:queue("ev", { n = 3 })
			t:flush()

			local msgs = t:receive_all()
			assert.are.equal(3, #msgs)
			assert.are.equal(1, msgs[1].data.n)
			assert.are.equal(2, msgs[2].data.n)
			assert.are.equal(3, msgs[3].data.n)
		end)
	end)

	describe("warning threshold", function()
		it("logs a warning when queue exceeds threshold", function()
			local warnings = {}
			local t, outbound = make_transport({
				warning_threshold = 3,
				log = function(msg)
					table.insert(warnings, msg)
				end,
			})
			t:mark_networkable("ev")
			-- Queue more than threshold without flushing
			t:queue("ev", { n = 1 })
			t:queue("ev", { n = 2 })
			t:queue("ev", { n = 3 })
			t:queue("ev", { n = 4 }) -- this one pushes past threshold
			-- A warning should have been logged
			assert.is_true(#warnings > 0)
			-- Messages are NOT dropped
			t:flush()
			assert.are.equal(4, outbound:getCount())
		end)

		it("does not log warning when queue is below threshold", function()
			local warnings = {}
			local t = make_transport({
				warning_threshold = 10,
				log = function(msg)
					table.insert(warnings, msg)
				end,
			})
			t:mark_networkable("ev")
			t:queue("ev", { n = 1 })
			t:queue("ev", { n = 2 })
			assert.are.equal(0, #warnings)
		end)
	end)
end)
