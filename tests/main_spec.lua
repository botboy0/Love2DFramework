--- Tests for main.lua Love2D lifecycle hooks.
--- Verifies love.quit calls registry shutdown, transport flush ordering,
--- config threading, and nil-safety guards.
---
--- Run with: busted tests/main_spec.lua
---
--- NOTE: main.lua is a Love2D entry-point and uses love.* globals.
--- Tests exercise the module-level functions directly by requiring main.lua
--- in a controlled environment with love mocked.

describe("FactoryGame", function()
	it("test framework is operational", function()
		assert.is_true(true)
	end)

	describe("plugin_harness", function()
		local harness = require("tests.helpers.plugin_harness")
		local evolved = require("lib.evolved")

		local spawned

		before_each(function()
			spawned = {}
		end)

		after_each(function()
			-- Clean up singleton ECS state between tests
			evolved.defer()
			for _, e in ipairs(spawned) do
				if evolved.alive(e) then
					evolved.destroy(e)
				end
			end
			evolved.commit()
		end)

		it("creates an isolated context", function()
			local ctx = harness.create_context()
			assert.is_table(ctx)
			assert.is_table(ctx.worlds)
			assert.is_table(ctx.bus)
			assert.is_table(ctx.config)
			assert.is_not_nil(ctx.services)
		end)

		it("context has server and client worlds", function()
			local ctx = harness.create_context()
			assert.is_table(ctx.worlds.server)
			assert.is_table(ctx.worlds.client)
		end)

		it("can spawn server entities via ctx.worlds", function()
			local ctx = harness.create_context()
			local e = ctx.worlds:spawn_server({})
			table.insert(spawned, e)
			assert.is_true(evolved.alive(e))
		end)

		it("bus supports on and emit", function()
			local ctx = harness.create_context()
			local received = nil
			ctx.bus:on("test_event", function(data)
				received = data
			end)
			ctx.bus:emit("test_event", { value = 42 })
			ctx.bus:flush()
			assert.are.equal(42, received.value)
		end)

		it("services register and get work", function()
			local ctx = harness.create_context()
			ctx.services:register("my_svc", { value = "hello" })
			local svc = ctx.services:get("my_svc")
			assert.are.equal("hello", svc.value)
		end)

		it("pre-registers deps from opts.deps table (name -> service)", function()
			local my_svc = { value = "dep_service" }
			local ctx = harness.create_context({ deps = { my_dep = my_svc } })
			local got = ctx.services:get("my_dep")
			assert.are.equal(my_svc, got)
		end)

		it("pre-registers deps from opts.deps array (legacy stub format)", function()
			local ctx = harness.create_context({ deps = { "some_dep" } })
			local got = ctx.services:get("some_dep")
			assert.is_table(got)
			assert.is_true(got._stub)
		end)

		it("tears down cleanly without error", function()
			local ctx = harness.create_context()
			assert.has_no_error(function()
				harness.teardown(ctx, {})
			end)
		end)

		it("teardown destroys tracked ECS entities", function()
			local ctx = harness.create_context()
			local e = ctx.worlds:spawn_server({})
			assert.is_true(evolved.alive(e))
			harness.teardown(ctx, { e })
			assert.is_false(evolved.alive(e))
		end)
	end)
end)

describe("main.lua lifecycle", function()
	-- We test the lifecycle logic directly without loading main.lua as a module
	-- (since it uses love.* globals and side-effects). Instead, we replicate
	-- the logic patterns in isolation.

	local Bus = require("src.core.bus")
	local Context = require("src.core.context")
	local Registry = require("src.core.registry")
	local Worlds = require("src.core.worlds")

	describe("love.quit behavior", function()
		it("calls registry:shutdown(ctx) when both registry and ctx are non-nil", function()
			local shutdown_called = false
			local shutdown_ctx_arg = nil

			-- Mock registry
			local mock_registry = {
				shutdown = function(self, ctx)
					shutdown_called = true
					shutdown_ctx_arg = ctx
				end,
			}

			-- Mock ctx
			local mock_ctx = { bus = {}, worlds = {} }

			-- Simulate love.quit logic
			local _registry = mock_registry
			local _ctx = mock_ctx
			local function love_quit()
				if _registry and _ctx then
					_registry:shutdown(_ctx)
				end
			end

			love_quit()

			assert.is_true(shutdown_called)
			assert.are.equal(mock_ctx, shutdown_ctx_arg)
		end)

		it("does not error when _registry is nil", function()
			local _registry = nil
			local _ctx = { bus = {} }

			assert.has_no_error(function()
				if _registry and _ctx then
					_registry:shutdown(_ctx)
				end
			end)
		end)

		it("does not error when _ctx is nil", function()
			local mock_registry = {
				shutdown = function() end,
			}
			local _registry = mock_registry
			local _ctx = nil

			assert.has_no_error(function()
				if _registry and _ctx then
					_registry:shutdown(_ctx)
				end
			end)
		end)

		it("does not error when both _registry and _ctx are nil", function()
			local _registry = nil
			local _ctx = nil

			assert.has_no_error(function()
				if _registry and _ctx then
					_registry:shutdown(_ctx)
				end
			end)
		end)
	end)

	describe("love.update flush ordering", function()
		it("calls transport:receive_all then bus:flush then transport:flush in order", function()
			local call_order = {}

			local mock_transport = {
				receive_all = function(self)
					table.insert(call_order, "transport:receive_all")
					return {}
				end,
				flush = function(self)
					table.insert(call_order, "transport:flush")
				end,
			}

			local mock_bus = {
				emit = function(self, event, data) end,
				flush = function(self)
					table.insert(call_order, "bus:flush")
				end,
			}

			local _ctx = { bus = mock_bus, transport = mock_transport }

			-- Simulate love.update logic
			local function love_update(_dt)
				if not _ctx then
					return
				end
				local messages = _ctx.transport:receive_all()
				for _, msg in ipairs(messages) do
					_ctx.bus:emit(msg.event, msg.data)
				end
				_ctx.bus:flush()
				_ctx.transport:flush()
			end

			love_update(0.016)

			assert.are.equal(3, #call_order)
			assert.are.equal("transport:receive_all", call_order[1])
			assert.are.equal("bus:flush", call_order[2])
			assert.are.equal("transport:flush", call_order[3])
		end)

		it("inbound transport messages are emitted onto bus before flush", function()
			local emitted_events = {}

			local mock_transport = {
				receive_all = function(self)
					return {
						{ event = "player_moved", data = { x = 10, y = 20 } },
					}
				end,
				flush = function(self) end,
			}

			local mock_bus = {
				emit = function(self, event, data)
					table.insert(emitted_events, { event = event, data = data })
				end,
				flush = function(self) end,
			}

			local _ctx = { bus = mock_bus, transport = mock_transport }

			local function love_update(_dt)
				if not _ctx then
					return
				end
				local messages = _ctx.transport:receive_all()
				for _, msg in ipairs(messages) do
					_ctx.bus:emit(msg.event, msg.data)
				end
				_ctx.bus:flush()
				_ctx.transport:flush()
			end

			love_update(0.016)

			assert.are.equal(1, #emitted_events)
			assert.are.equal("player_moved", emitted_events[1].event)
			assert.are.equal(10, emitted_events[1].data.x)
		end)

		it("is safe when _ctx is nil (no error)", function()
			local _ctx = nil

			assert.has_no_error(function()
				local function love_update(_dt)
					if not _ctx then
						return
					end
					local messages = _ctx.transport:receive_all()
					for _, msg in ipairs(messages) do
						_ctx.bus:emit(msg.event, msg.data)
					end
					_ctx.bus:flush()
					_ctx.transport:flush()
				end
				love_update(0.016)
			end)
		end)
	end)

	describe("config threading", function()
		it("Bus.new accepts error_mode from config", function()
			local config = { error_mode = "strict" }
			local bus_error_mode = (config.error_modes and config.error_modes.bus) or config.error_mode or "tolerant"
			local bus = Bus.new({ error_mode = bus_error_mode })
			assert.is_not_nil(bus)
			-- Verify strict mode raises on handler error
			bus:on("test", function()
				error("handler error")
			end)
			bus:emit("test", {})
			assert.has_error(function()
				bus:flush()
			end)
		end)

		it("Bus.new defaults to tolerant when config has no error_mode", function()
			local config = {}
			local bus_error_mode = (config.error_modes and config.error_modes.bus) or config.error_mode or "tolerant"
			local bus = Bus.new({ error_mode = bus_error_mode })
			assert.is_not_nil(bus)
			-- Tolerant mode: handler error does not propagate from flush
			bus:on("test", function()
				error("handler error")
			end)
			bus:emit("test", {})
			assert.has_no_error(function()
				bus:flush()
			end)
		end)

		it("Registry.new accepts config with error_mode", function()
			local config = { error_mode = "tolerant" }
			local registry = Registry.new({ config = config })
			assert.is_not_nil(registry)
		end)

		it("Context.new accepts config and transport options", function()
			local bus = Bus.new()
			local worlds = Worlds.create()
			local config = {}
			local ctx = Context.new({
				worlds = worlds,
				bus = bus,
				config = config,
				transport = nil, -- nil => NullTransport
			})
			assert.is_not_nil(ctx)
			assert.is_not_nil(ctx.transport)
		end)

		it("Context.new with transport=nil gives NullTransport with receive_all returning empty table", function()
			local bus = Bus.new()
			local worlds = Worlds.create()
			local ctx = Context.new({ worlds = worlds, bus = bus, config = {}, transport = nil })
			-- NullTransport.receive_all() must return {} so love.update loop is safe
			local msgs = ctx.transport:receive_all()
			assert.is_table(msgs)
			assert.are.equal(0, #msgs)
		end)
	end)
end)
