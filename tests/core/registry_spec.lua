--- Registry test suite.
---
--- Tests plugin registration, topological dependency sorting, boot order,
--- missing dependency detection, cycle detection, and shutdown behavior.

local Bus = require("src.core.bus")
local Context = require("src.core.context")
local Registry = require("src.core.registry")

--- Build a minimal ctx for boot tests.
local function make_ctx()
	local bus = Bus.new()
	return Context.new({ bus = bus, config = {} })
end

--- Build a simple plugin that records init/shutdown calls.
local function make_plugin(name, log)
	return {
		name = name,
		init = function(_self, _ctx)
			table.insert(log, "init:" .. name)
		end,
		shutdown = function(_self, _ctx)
			table.insert(log, "shutdown:" .. name)
		end,
	}
end

describe("Registry", function()
	describe("new()", function()
		it("creates a registry instance", function()
			local r = Registry.new()
			assert.is_not_nil(r)
		end)

		it("starts with no registered plugins", function()
			local r = Registry.new()
			-- boot on empty registry should succeed silently
			local ctx = make_ctx()
			assert.has_no.errors(function()
				r:boot(ctx)
			end)
		end)
	end)

	describe("register()", function()
		it("accepts a plugin with no dependencies", function()
			local r = Registry.new()
			local log = {}
			local plugin = make_plugin("alpha", log)
			assert.has_no.errors(function()
				r:register("alpha", plugin)
			end)
		end)

		it("accepts a plugin with explicit deps list", function()
			local r = Registry.new()
			local log = {}
			r:register("base", make_plugin("base", log))
			assert.has_no.errors(function()
				r:register("derived", make_plugin("derived", log), { deps = { "base" } })
			end)
		end)
	end)

	describe("boot()", function()
		it("calls init on all registered plugins", function()
			local r = Registry.new()
			local log = {}
			r:register("alpha", make_plugin("alpha", log))
			r:register("beta", make_plugin("beta", log))
			r:boot(make_ctx())
			assert.is_true(#log == 2)
			-- both should appear in log
			local found_alpha, found_beta = false, false
			for _, v in ipairs(log) do
				if v == "init:alpha" then
					found_alpha = true
				end
				if v == "init:beta" then
					found_beta = true
				end
			end
			assert.is_true(found_alpha)
			assert.is_true(found_beta)
		end)

		it("boots plugins without dependencies in registration order", function()
			local r = Registry.new()
			local log = {}
			r:register("first", make_plugin("first", log))
			r:register("second", make_plugin("second", log))
			r:register("third", make_plugin("third", log))
			r:boot(make_ctx())
			assert.are.equal("init:first", log[1])
			assert.are.equal("init:second", log[2])
			assert.are.equal("init:third", log[3])
		end)

		it("boots dependencies before dependents (topological order)", function()
			local r = Registry.new()
			local log = {}
			-- Register in reverse order to prove topological sort works
			r:register("derived", make_plugin("derived", log), { deps = { "base" } })
			r:register("base", make_plugin("base", log))
			r:boot(make_ctx())
			-- base must come before derived
			local base_pos, derived_pos
			for i, v in ipairs(log) do
				if v == "init:base" then
					base_pos = i
				end
				if v == "init:derived" then
					derived_pos = i
				end
			end
			assert.is_not_nil(base_pos)
			assert.is_not_nil(derived_pos)
			assert.is_true(base_pos < derived_pos)
		end)

		it("handles a diamond dependency (A->B, A->C, B->D, C->D)", function()
			local r = Registry.new()
			local log = {}
			r:register("d", make_plugin("d", log))
			r:register("b", make_plugin("b", log), { deps = { "d" } })
			r:register("c", make_plugin("c", log), { deps = { "d" } })
			r:register("a", make_plugin("a", log), { deps = { "b", "c" } })
			r:boot(make_ctx())
			-- d must come before b and c; b and c before a
			local pos = {}
			for i, v in ipairs(log) do
				local name = v:sub(6) -- strip "init:"
				pos[name] = i
			end
			assert.is_true(pos["d"] < pos["b"])
			assert.is_true(pos["d"] < pos["c"])
			assert.is_true(pos["b"] < pos["a"])
			assert.is_true(pos["c"] < pos["a"])
		end)

		it("errors on missing dependency before any plugin:init runs", function()
			local r = Registry.new()
			local log = {}
			r:register("plugin_a", make_plugin("plugin_a", log), { deps = { "missing_dep" } })
			local ok, err = pcall(function()
				r:boot(make_ctx())
			end)
			assert.is_false(ok)
			-- Error should name both the missing dep and the plugin that needs it
			assert.is_not_nil(err:find("missing_dep"))
			assert.is_not_nil(err:find("plugin_a"))
			-- No plugin:init should have been called
			assert.are.equal(0, #log)
		end)

		it("errors on cyclic dependency (A->B, B->A)", function()
			local r = Registry.new()
			local log = {}
			r:register("a", make_plugin("a", log), { deps = { "b" } })
			r:register("b", make_plugin("b", log), { deps = { "a" } })
			local ok, err = pcall(function()
				r:boot(make_ctx())
			end)
			assert.is_false(ok)
			-- Error should mention cycle
			assert.is_not_nil(err:find("ycl") or err:find("cycl") or err:find("Cycl"))
			-- No plugin:init should have been called
			assert.are.equal(0, #log)
		end)

		it("errors on longer cycle (A->B->C->A)", function()
			local r = Registry.new()
			local log = {}
			r:register("a", make_plugin("a", log), { deps = { "b" } })
			r:register("b", make_plugin("b", log), { deps = { "c" } })
			r:register("c", make_plugin("c", log), { deps = { "a" } })
			local ok, err = pcall(function()
				r:boot(make_ctx())
			end)
			assert.is_false(ok)
			assert.is_not_nil(err:find("ycl") or err:find("cycl") or err:find("Cycl"))
			assert.are.equal(0, #log)
		end)

		it("passes ctx to each plugin:init", function()
			local r = Registry.new()
			local received_ctx
			local plugin = {
				init = function(_self, ctx)
					received_ctx = ctx
				end,
			}
			r:register("pluginx", plugin)
			local ctx = make_ctx()
			r:boot(ctx)
			assert.are.equal(ctx, received_ctx)
		end)
	end)

	describe("shutdown()", function()
		it("calls shutdown on plugins that define it (in reverse boot order)", function()
			local r = Registry.new()
			local log = {}
			r:register("base", make_plugin("base", log))
			r:register("derived", make_plugin("derived", log), { deps = { "base" } })
			local ctx = make_ctx()
			r:boot(ctx)
			-- clear init log entries
			log = {}
			r:shutdown(ctx)
			-- shutdown should be in reverse boot order: derived first, then base
			assert.are.equal("shutdown:derived", log[1])
			assert.are.equal("shutdown:base", log[2])
		end)

		it("skips plugins that do not define shutdown", function()
			local r = Registry.new()
			local log = {}
			local plugin_no_shutdown = {
				init = function(_self, _ctx)
					table.insert(log, "init:no_shutdown")
				end,
				-- no shutdown field
			}
			r:register("no_shutdown", plugin_no_shutdown)
			local ctx = make_ctx()
			r:boot(ctx)
			log = {}
			assert.has_no.errors(function()
				r:shutdown(ctx)
			end)
			assert.are.equal(0, #log) -- no shutdown calls
		end)
	end)
end)

describe("plugin_list", function()
	it("returns a table (the plugin configuration list)", function()
		local list = require("src.core.plugin_list")
		assert.is_table(list)
	end)

	it("starts empty (no plugins registered yet)", function()
		local list = require("src.core.plugin_list")
		assert.are.equal(0, #list)
	end)
end)
