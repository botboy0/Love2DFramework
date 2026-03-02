--- Tests for tests/helpers/plugin_harness.lua
--- Verifies the plugin harness create_context API and dep enforcement proxy.
---
--- Run with: busted tests/helpers/plugin_harness_spec.lua

local harness = require("tests.helpers.plugin_harness")

describe("plugin_harness.create_context", function()
	it("returns ctx with worlds, bus, config, services", function()
		local ctx = harness.create_context()
		assert.is_not_nil(ctx.worlds)
		assert.is_not_nil(ctx.bus)
		assert.is_not_nil(ctx.config)
		assert.is_not_nil(ctx.services)
	end)

	it("pre-registers deps passed as name->service table", function()
		local stub_service = { do_thing = function() end }
		local ctx = harness.create_context({ deps = { inventory = stub_service } })
		local retrieved = ctx.services:get("inventory")
		assert.are.equal(stub_service, retrieved)
	end)

	describe("dep enforcement", function()
		it("errors when plugin accesses undeclared service in strict mode", function()
			local inventory_svc = { _name = "inventory" }
			local crafting_svc = { _name = "crafting" }
			local ctx = harness.create_context({
				deps = { inventory = inventory_svc, crafting = crafting_svc },
				allowed_deps = { "inventory" },
				-- error_mode defaults to "strict"
			})

			-- Declared service: should succeed
			assert.has_no_error(function()
				ctx.services:get("inventory")
			end)

			-- Undeclared service: should error in strict mode
			assert.has_error(function()
				ctx.services:get("crafting")
			end)
		end)

		it("allows access to a declared service", function()
			local svc = { value = 42 }
			local ctx = harness.create_context({
				deps = { my_service = svc },
				allowed_deps = { "my_service" },
			})
			local retrieved = ctx.services:get("my_service")
			assert.are.equal(svc, retrieved)
		end)

		it("does not error in tolerant mode for undeclared service", function()
			local crafting_svc = { _name = "crafting" }
			local ctx = harness.create_context({
				deps = { crafting = crafting_svc },
				allowed_deps = {},
				error_mode = "tolerant",
			})
			local original_print = _G.print
			_G.print = function() end
			-- In tolerant mode, accessing an undeclared service warns but does not error
			assert.has_no_error(function()
				ctx.services:get("crafting")
			end)
			_G.print = original_print
		end)

		it("delegates register() through the proxy", function()
			local ctx = harness.create_context({
				allowed_deps = { "new_service" },
			})
			local new_svc = { _name = "new_service" }
			-- register() should work through the proxy
			assert.has_no_error(function()
				ctx.services:register("new_service", new_svc)
			end)
			-- And the declared service should be retrievable
			local retrieved = ctx.services:get("new_service")
			assert.are.equal(new_svc, retrieved)
		end)

		it("does not install proxy when allowed_deps is nil", function()
			local svc = { _name = "any_service" }
			local ctx = harness.create_context({
				deps = { any_service = svc },
				-- no allowed_deps — no proxy
			})
			-- Any registered service should be accessible normally
			assert.has_no_error(function()
				ctx.services:get("any_service")
			end)
			local retrieved = ctx.services:get("any_service")
			assert.are.equal(svc, retrieved)
		end)
	end)
end)
