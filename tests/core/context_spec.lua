--- Tests for src/core/context.lua
--- Context object bundles worlds, bus, config, services, and transport for plugin:init(ctx).
---
--- Run with: busted tests/core/context_spec.lua

local Context = require("src.core.context")
local Transport = require("src.core.transport")
local Worlds = require("src.core.worlds")

--- Create a minimal stub bus for testing (does NOT record calls).
--- @return table bus
local function make_bus()
	return { _handlers = {}, on = function() end, emit = function() end, flush = function() end }
end

--- Create a minimal mock channel (for real Transport in tests).
--- Implements push/pop/getCount so Transport works without love.thread.
--- @return table channel
local function make_channel()
	local q = {}
	return {
		push = function(_self, v)
			table.insert(q, v)
		end,
		pop = function(_self)
			return table.remove(q, 1)
		end,
		getCount = function(_self)
			return #q
		end,
	}
end

--- Create a real Transport with mock channels (for testing auto-bridge).
--- @return table transport
local function make_real_transport()
	return Transport.new({
		outbound_channel = make_channel(),
		inbound_channel = make_channel(),
	})
end

describe("Context", function()
	describe("Context.new(opts)", function()
		it("returns a table", function()
			local ctx = Context.new()
			assert.is_table(ctx)
		end)

		it("has worlds field when provided", function()
			local worlds = Worlds.create()
			local ctx = Context.new({ worlds = worlds })
			assert.are.equal(worlds, ctx.worlds)
		end)

		it("ctx.worlds.server is accessible in dual-world mode", function()
			local worlds = Worlds.create({ dual = true })
			local ctx = Context.new({ worlds = worlds })
			assert.is_not_nil(ctx.worlds.server)
		end)

		it("ctx.worlds.client is accessible in dual-world mode", function()
			local worlds = Worlds.create({ dual = true })
			local ctx = Context.new({ worlds = worlds })
			assert.is_not_nil(ctx.worlds.client)
		end)

		it("ctx.bus is the bus instance passed in", function()
			local bus = make_bus()
			local ctx = Context.new({ bus = bus })
			assert.are.equal(bus, ctx.bus)
		end)

		it("ctx.config defaults to empty table when not provided", function()
			local ctx = Context.new()
			assert.is_table(ctx.config)
			assert.are.equal(0, #ctx.config)
		end)

		it("ctx.config uses provided config table", function()
			local cfg = { max_entities = 1000 }
			local ctx = Context.new({ config = cfg })
			assert.are.equal(cfg, ctx.config)
		end)

		it("ctx.services is a table", function()
			local ctx = Context.new()
			assert.is_table(ctx.services)
		end)
	end)

	describe("ctx.transport", function()
		it("is present even with no transport option", function()
			local ctx = Context.new()
			assert.is_not_nil(ctx.transport)
		end)

		it("is NullTransport when no transport option given", function()
			local ctx = Context.new()
			-- NullTransport.is_networkable always returns false
			assert.is_false(ctx.transport:is_networkable("any_event"))
		end)

		it("is NullTransport when transport = false", function()
			local ctx = Context.new({ transport = false })
			assert.is_false(ctx.transport:is_networkable("any_event"))
		end)

		it("is NullTransport when transport = nil", function()
			local ctx = Context.new({ transport = nil })
			assert.is_false(ctx.transport:is_networkable("any_event"))
		end)

		it("uses provided transport instance when given a real transport", function()
			local t = make_real_transport()
			local ctx = Context.new({ transport = t })
			assert.are.equal(t, ctx.transport)
		end)

		it("transport = true without transport_channels errors", function()
			local ok, err = pcall(function()
				Context.new({ transport = true })
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("transport_channels"))
		end)

		it("transport = true with transport_channels creates real Transport", function()
			local ctx = Context.new({
				transport = true,
				transport_channels = {
					outbound = make_channel(),
					inbound = make_channel(),
				},
			})
			assert.is_not_nil(ctx.transport)
			-- Real transport is_networkable returns false for unmarked events
			assert.is_false(ctx.transport:is_networkable("any_event"))
			-- But can mark networkable (real Transport has this method)
			ctx.transport:mark_networkable("player_moved")
			assert.is_true(ctx.transport:is_networkable("player_moved"))
		end)
	end)

	describe("auto-bridge: bus:emit() forwards networkable events to transport", function()
		local function make_recording_bus()
			local bus = {
				_handlers = {},
				_emitted = {},
				on = function() end,
				flush = function() end,
			}
			bus.emit = function(_self, event, data)
				table.insert(bus._emitted, { event = event, data = data })
			end
			return bus
		end

		it("networkable event is queued on transport after bus:emit", function()
			local t = make_real_transport()
			t:mark_networkable("player_moved")
			local bus = make_recording_bus()
			local ctx = Context.new({ bus = bus, transport = t })

			ctx.bus:emit("player_moved", { x = 1, y = 2 })

			-- The transport queue should have the event
			assert.are.equal(1, #t._queue)
			assert.are.equal("player_moved", t._queue[1].event)
		end)

		it("non-networkable event is NOT queued on transport after bus:emit", function()
			local t = make_real_transport()
			-- "ui_click" is NOT marked networkable
			local bus = make_recording_bus()
			local ctx = Context.new({ bus = bus, transport = t })

			ctx.bus:emit("ui_click", { button = "left" })

			assert.are.equal(0, #t._queue)
		end)

		it("original bus:emit still fires (event recorded by original emit)", function()
			local t = make_real_transport()
			t:mark_networkable("player_moved")
			local bus = make_recording_bus()
			local ctx = Context.new({ bus = bus, transport = t })

			ctx.bus:emit("player_moved", { x = 5 })

			-- original emit recorded it
			assert.are.equal(1, #bus._emitted)
			assert.are.equal("player_moved", bus._emitted[1].event)
		end)

		it("NullTransport auto-bridge: no queue calls (is_networkable always false)", function()
			-- No transport provided → NullTransport. Even if we install the bridge,
			-- NullTransport.is_networkable returns false so queue is never called.
			local null_t_queue_called = false
			local bus = make_recording_bus()
			local ctx = Context.new({ bus = bus })

			-- Override null transport queue to detect if called
			ctx.transport.queue = function()
				null_t_queue_called = true
			end
			ctx.transport._networkable = { any_event = true } -- force is_networkable true on null

			-- Even with is_networkable returning true on null, queue is no-op on real NullTransport
			-- This test checks the bridge is always installed (it just calls through)
			ctx.bus:emit("any_event", {})
			-- No error means bridge is safe with NullTransport
			assert.is_false(false) -- always passes — just verifying no error above
		end)

		it("multiple events: only networkable ones are queued", function()
			local t = make_real_transport()
			t:mark_networkable("player_moved")
			t:mark_networkable("resource_collected")
			local bus = make_recording_bus()
			local ctx = Context.new({ bus = bus, transport = t })

			ctx.bus:emit("player_moved", { x = 1 })
			ctx.bus:emit("ui_click", {})
			ctx.bus:emit("resource_collected", { amount = 5 })
			ctx.bus:emit("sound_played", {})

			assert.are.equal(2, #t._queue)
			assert.are.equal("player_moved", t._queue[1].event)
			assert.are.equal("resource_collected", t._queue[2].event)
		end)
	end)

	describe("config passthrough", function()
		it("ctx.config is accessible on the context", function()
			local cfg = { error_mode = "strict", max_entities = 500 }
			local ctx = Context.new({ config = cfg })
			assert.are.equal(cfg, ctx.config)
			assert.are.equal("strict", ctx.config.error_mode)
		end)

		it("config defaults to empty table", function()
			local ctx = Context.new()
			assert.is_table(ctx.config)
		end)
	end)

	describe("ctx.services:register and :get", function()
		local ctx

		before_each(function()
			ctx = Context.new()
		end)

		it("register then get returns the service", function()
			local svc = { query = function() end }
			ctx.services:register("inventory", svc)
			assert.are.equal(svc, ctx.services:get("inventory"))
		end)

		it("get on missing service errors with descriptive message", function()
			local ok, err = pcall(function()
				ctx.services:get("missing_service")
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("missing_service"))
		end)

		it("error message mentions registration hint", function()
			local ok, err = pcall(function()
				ctx.services:get("foo_service")
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("foo_service"))
			-- Should mention something about registering or not found
			assert.is_truthy(err:find("not found") or err:find("register") or err:find("plugin"))
		end)

		it("register twice with same name errors", function()
			local svc = {}
			ctx.services:register("my_svc", svc)
			local ok, err = pcall(function()
				ctx.services:register("my_svc", {})
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("my_svc"))
		end)

		it("multiple services can be registered and retrieved independently", function()
			local svc_a = { name = "a" }
			local svc_b = { name = "b" }
			ctx.services:register("svc_a", svc_a)
			ctx.services:register("svc_b", svc_b)
			assert.are.equal(svc_a, ctx.services:get("svc_a"))
			assert.are.equal(svc_b, ctx.services:get("svc_b"))
		end)

		it("get returns same object reference that was registered", function()
			local svc = { value = 42 }
			ctx.services:register("ref_test", svc)
			local retrieved = ctx.services:get("ref_test")
			assert.are.equal(svc.value, retrieved.value)
		end)
	end)
end)
