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
