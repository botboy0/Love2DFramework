local Bus = require("src.core.bus")

describe("Bus", function()
	describe("Bus.new", function()
		it("creates a new bus instance", function()
			local bus = Bus.new()
			assert.is_not_nil(bus)
		end)

		it("starts with empty queue and no handlers", function()
			local bus = Bus.new()
			assert.is_table(bus._queue)
			assert.is_table(bus._handlers)
			assert.equal(0, #bus._queue)
		end)
	end)

	describe("bus:on", function()
		it("registers a handler for an event", function()
			local bus = Bus.new()
			local handler = function(_data) end
			bus:on("test_event", handler)
			assert.is_table(bus._handlers["test_event"])
			assert.equal(1, #bus._handlers["test_event"])
		end)

		it("registers multiple handlers for the same event", function()
			local bus = Bus.new()
			local handler1 = function(_data) end
			local handler2 = function(_data) end
			bus:on("test_event", handler1)
			bus:on("test_event", handler2)
			assert.equal(2, #bus._handlers["test_event"])
		end)
	end)

	describe("bus:off", function()
		it("unsubscribes a specific handler", function()
			local bus = Bus.new()
			local handler1 = function(_data) end
			local handler2 = function(_data) end
			bus:on("test_event", handler1)
			bus:on("test_event", handler2)
			bus:off("test_event", handler1)
			assert.equal(1, #bus._handlers["test_event"])
			assert.equal(handler2, bus._handlers["test_event"][1])
		end)

		it("does nothing if handler is not registered", function()
			local bus = Bus.new()
			local handler = function(_data) end
			bus:off("test_event", handler)
			-- should not error
			assert.is_nil(bus._handlers["test_event"])
		end)
	end)

	describe("bus:emit", function()
		it("queues an event without calling handlers immediately", function()
			local bus = Bus.new()
			local called = false
			bus:on("test_event", function(_data)
				called = true
			end)
			bus:emit("test_event", {})
			assert.is_false(called)
			assert.equal(1, #bus._queue)
		end)

		it("queues multiple events in emit order", function()
			local bus = Bus.new()
			bus:emit("event_a", { order = 1 })
			bus:emit("event_b", { order = 2 })
			bus:emit("event_c", { order = 3 })
			assert.equal(3, #bus._queue)
			assert.equal("event_a", bus._queue[1][1])
			assert.equal("event_b", bus._queue[2][1])
			assert.equal("event_c", bus._queue[3][1])
		end)

		it("passes data payload through to the queue unchanged", function()
			local bus = Bus.new()
			local payload = { x = 10, y = 20, name = "test" }
			bus:emit("test_event", payload)
			assert.equal(payload, bus._queue[1][2])
		end)

		it("logs error and does not queue if called during flush (re-entrancy guard)", function()
			local log_calls = {}
			local bus = Bus.new(function(msg)
				table.insert(log_calls, msg)
			end)
			local queued_during_flush = false

			bus:on("outer_event", function(_data)
				bus:emit("inner_event", {})
				queued_during_flush = #bus._queue > 0
			end)

			bus:emit("outer_event", {})
			bus:flush()

			assert.is_false(queued_during_flush)
			-- A warning should have been logged
			local warned = false
			for _, msg in ipairs(log_calls) do
				if msg:find("re.entr") or msg:find("flushing") or msg:find("inner_event") then
					warned = true
					break
				end
			end
			assert.is_true(warned)
		end)
	end)

	describe("bus:flush", function()
		it("dispatches all queued events to registered handlers", function()
			local bus = Bus.new()
			local received = {}
			bus:on("test_event", function(data)
				table.insert(received, data)
			end)
			bus:emit("test_event", { value = 1 })
			bus:emit("test_event", { value = 2 })
			bus:flush()
			assert.equal(2, #received)
			assert.equal(1, received[1].value)
			assert.equal(2, received[2].value)
		end)

		it("dispatches handlers in registration order", function()
			local bus = Bus.new()
			local order = {}
			bus:on("test_event", function(_data)
				table.insert(order, 1)
			end)
			bus:on("test_event", function(_data)
				table.insert(order, 2)
			end)
			bus:on("test_event", function(_data)
				table.insert(order, 3)
			end)
			bus:emit("test_event", {})
			bus:flush()
			assert.same({ 1, 2, 3 }, order)
		end)

		it("clears the queue after flushing", function()
			local bus = Bus.new()
			bus:on("test_event", function(_data) end)
			bus:emit("test_event", {})
			bus:flush()
			assert.equal(0, #bus._queue)
		end)

		it("dispatches multiple events in emit order", function()
			local bus = Bus.new()
			local received_events = {}
			bus:on("event_a", function(_data)
				table.insert(received_events, "a")
			end)
			bus:on("event_b", function(_data)
				table.insert(received_events, "b")
			end)
			bus:on("event_c", function(_data)
				table.insert(received_events, "c")
			end)
			bus:emit("event_a", {})
			bus:emit("event_b", {})
			bus:emit("event_c", {})
			bus:flush()
			assert.same({ "a", "b", "c" }, received_events)
		end)

		it("silently discards events with no subscribers", function()
			local bus = Bus.new()
			bus:emit("unhandled_event", { data = "ignored" })
			-- Should not error
			bus:flush()
			assert.equal(0, #bus._queue)
		end)

		it("catches handler errors and continues to next handler", function()
			local log_calls = {}
			local bus = Bus.new(function(msg)
				table.insert(log_calls, msg)
			end)
			local second_called = false

			bus:on("test_event", function(_data)
				error("intentional error")
			end)
			bus:on("test_event", function(_data)
				second_called = true
			end)

			bus:emit("test_event", {})
			bus:flush()

			assert.is_true(second_called)
			-- Error should have been logged
			local error_logged = false
			for _, msg in ipairs(log_calls) do
				if msg:find("intentional error") or msg:find("handler error") or msg:find("Error") then
					error_logged = true
					break
				end
			end
			assert.is_true(error_logged)
		end)

		it("passes data payload through from emit to handler unchanged", function()
			local bus = Bus.new()
			local received_data = nil
			local payload = { entity = 42, resource = "wood", amount = 5 }
			bus:on("resource_collected", function(data)
				received_data = data
			end)
			bus:emit("resource_collected", payload)
			bus:flush()
			assert.equal(payload, received_data)
		end)
	end)
end)
