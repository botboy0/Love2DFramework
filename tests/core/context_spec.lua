--- Tests for src/core/context.lua
--- Context object bundles worlds, bus, config, and services for plugin:init(ctx).
---
--- Run with: busted tests/core/context_spec.lua

local Context = require("src.core.context")
local Worlds = require("src.core.worlds")

--- Create a minimal stub bus for testing.
--- @return table bus
local function make_bus()
	return { _handlers = {}, on = function() end, emit = function() end, flush = function() end }
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

		it("ctx.worlds.server is accessible", function()
			local worlds = Worlds.create()
			local ctx = Context.new({ worlds = worlds })
			assert.is_not_nil(ctx.worlds.server)
		end)

		it("ctx.worlds.client is accessible", function()
			local worlds = Worlds.create()
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
