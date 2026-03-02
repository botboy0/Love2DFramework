--- Registry test suite.
---
--- Tests plugin registration, topological dependency sorting, boot order,
--- missing dependency detection, cycle detection, shutdown behavior,
--- error_mode (strict/tolerant), and side enforcement.

local Bus = require("src.core.bus")
local Context = require("src.core.context")
local Registry = require("src.core.registry")
local Worlds = require("src.core.worlds")

--- Build a minimal ctx for boot tests (single-world).
local function make_ctx()
	local bus = Bus.new()
	return Context.new({ bus = bus, config = {} })
end

--- Build a ctx with a dual-world handle (for side enforcement tests).
local function make_dual_ctx()
	local bus = Bus.new()
	local worlds = Worlds.create({ dual = true })
	return Context.new({ bus = bus, worlds = worlds, config = {} })
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

--- Build a plugin whose init always errors.
local function make_failing_plugin(name, log)
	return {
		name = name,
		init = function(_self, _ctx)
			table.insert(log, "init_attempt:" .. name)
			error("plugin " .. name .. " init failed intentionally")
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
			-- clear init log entries in-place so plugin closures still point to the same table
			while #log > 0 do
				table.remove(log)
			end
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

	describe("error_mode", function()
		it("strict mode (default): plugin init error propagates from boot()", function()
			local r = Registry.new() -- default = strict
			local log = {}
			r:register("bad_plugin", make_failing_plugin("bad_plugin", log))
			local ok, err = pcall(function()
				r:boot(make_ctx())
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("bad_plugin"))
		end)

		it("strict mode: error propagates even when other plugins registered", function()
			local r = Registry.new()
			local log = {}
			r:register("good_plugin", make_plugin("good_plugin", log))
			r:register("bad_plugin", make_failing_plugin("bad_plugin", log))
			local ok, _err = pcall(function()
				r:boot(make_ctx())
			end)
			assert.is_false(ok)
		end)

		it("tolerant mode: plugin init error is logged, boot continues", function()
			local logged = {}
			local r = Registry.new({
				config = { error_mode = "tolerant" },
				log = function(msg)
					table.insert(logged, msg)
				end,
			})
			local log = {}
			r:register("bad_plugin", make_failing_plugin("bad_plugin", log))
			r:register("good_plugin", make_plugin("good_plugin", log))

			local ok = pcall(function()
				r:boot(make_ctx())
			end)

			-- Boot should NOT throw in tolerant mode
			assert.is_true(ok)
			-- good_plugin should still have been initialized
			local found_good = false
			for _, v in ipairs(log) do
				if v == "init:good_plugin" then
					found_good = true
				end
			end
			assert.is_true(found_good)
		end)

		it("tolerant mode: error is logged (not silently swallowed)", function()
			local logged = {}
			local r = Registry.new({
				config = { error_mode = "tolerant" },
				log = function(msg)
					table.insert(logged, msg)
				end,
			})
			local log = {}
			r:register("bad_plugin", make_failing_plugin("bad_plugin", log))
			pcall(function()
				r:boot(make_ctx())
			end)

			assert.is_true(#logged > 0)
			-- Log message should mention the plugin or the error
			local found_mention = false
			for _, msg in ipairs(logged) do
				if type(msg) == "string" and (msg:find("bad_plugin") or msg:find("failed")) then
					found_mention = true
				end
			end
			assert.is_true(found_mention)
		end)

		it("tolerant mode: failed plugin is excluded from shutdown order", function()
			local logged = {}
			local r = Registry.new({
				config = { error_mode = "tolerant" },
				log = function(msg)
					table.insert(logged, msg)
				end,
			})
			local log = {}
			r:register("bad_plugin", make_failing_plugin("bad_plugin", log))
			r:register("good_plugin", make_plugin("good_plugin", log))
			local ctx = make_ctx()
			pcall(function()
				r:boot(ctx)
			end)
			-- Clear log
			while #log > 0 do
				table.remove(log)
			end

			r:shutdown(ctx)

			-- Only good_plugin should appear in shutdown log
			local found_bad_shutdown = false
			for _, v in ipairs(log) do
				if v == "shutdown:bad_plugin" then
					found_bad_shutdown = true
				end
			end
			assert.is_false(found_bad_shutdown)
		end)

		it("tolerant mode via per-module config override", function()
			local logged = {}
			local r = Registry.new({
				config = { error_modes = { registry = "tolerant" } },
				log = function(msg)
					table.insert(logged, msg)
				end,
			})
			local log = {}
			r:register("bad_plugin", make_failing_plugin("bad_plugin", log))

			local ok = pcall(function()
				r:boot(make_ctx())
			end)
			assert.is_true(ok)
		end)
	end)

	describe("side enforcement", function()
		it("dual-world: server plugin depending on client plugin errors", function()
			local r = Registry.new()
			local log = {}
			r:register("client_plugin", make_plugin("client_plugin", log), { side = "client" })
			r:register("server_plugin", make_plugin("server_plugin", log), {
				side = "server",
				deps = { "client_plugin" },
			})

			local ok, err = pcall(function()
				r:boot(make_dual_ctx())
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("side") or err:find("server") or err:find("client"))
		end)

		it("dual-world: client plugin depending on server plugin errors", function()
			local r = Registry.new()
			local log = {}
			r:register("server_plugin", make_plugin("server_plugin", log), { side = "server" })
			r:register("client_plugin", make_plugin("client_plugin", log), {
				side = "client",
				deps = { "server_plugin" },
			})

			local ok, err = pcall(function()
				r:boot(make_dual_ctx())
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("side") or err:find("server") or err:find("client"))
		end)

		it("dual-world: server plugin depending on server plugin is ok", function()
			local r = Registry.new()
			local log = {}
			r:register("server_a", make_plugin("server_a", log), { side = "server" })
			r:register("server_b", make_plugin("server_b", log), {
				side = "server",
				deps = { "server_a" },
			})

			assert.has_no.errors(function()
				r:boot(make_dual_ctx())
			end)
		end)

		it("dual-world: client plugin depending on client plugin is ok", function()
			local r = Registry.new()
			local log = {}
			r:register("client_a", make_plugin("client_a", log), { side = "client" })
			r:register("client_b", make_plugin("client_b", log), {
				side = "client",
				deps = { "client_a" },
			})

			assert.has_no.errors(function()
				r:boot(make_dual_ctx())
			end)
		end)

		it("dual-world: plugin with no side can depend on either side", function()
			local r = Registry.new()
			local log = {}
			r:register("server_plugin", make_plugin("server_plugin", log), { side = "server" })
			r:register("neutral_plugin", make_plugin("neutral_plugin", log), {
				-- no side set
				deps = { "server_plugin" },
			})

			assert.has_no.errors(function()
				r:boot(make_dual_ctx())
			end)
		end)

		it("single-world: side declarations are ignored (no enforcement)", function()
			local r = Registry.new()
			local log = {}
			-- Same cross-side dep that would fail in dual-world is OK in single-world
			r:register("client_plugin", make_plugin("client_plugin", log), { side = "client" })
			r:register("server_plugin", make_plugin("server_plugin", log), {
				side = "server",
				deps = { "client_plugin" },
			})

			assert.has_no.errors(function()
				r:boot(make_ctx()) -- make_ctx() uses single-world
			end)
		end)
	end)

	describe("update_all()", function()
		it("calls update(dt) on plugins that have an update method", function()
			local r = Registry.new()
			local log = {}
			local plugin = {
				init = function(_self, _ctx)
					table.insert(log, "init:p")
				end,
				update = function(_self, _dt)
					table.insert(log, "update:p")
				end,
			}
			r:register("p", plugin)
			local ctx = make_ctx()
			r:boot(ctx)
			log = {}
			r:update_all(0.016)
			assert.are.equal(1, #log)
			assert.are.equal("update:p", log[1])
		end)

		it("skips plugins without update method (no error)", function()
			local r = Registry.new()
			local log = {}
			local plugin = {
				init = function(_self, _ctx)
					table.insert(log, "init:p")
				end,
				-- no update field
			}
			r:register("p", plugin)
			local ctx = make_ctx()
			r:boot(ctx)
			log = {}
			assert.has_no.errors(function()
				r:update_all(0.016)
			end)
			assert.are.equal(0, #log)
		end)

		it("passes dt argument through correctly", function()
			local r = Registry.new()
			local received_dt
			local plugin = {
				init = function(_self, _ctx) end,
				update = function(_self, dt)
					received_dt = dt
				end,
			}
			r:register("p", plugin)
			r:boot(make_ctx())
			r:update_all(0.123)
			assert.are.equal(0.123, received_dt)
		end)

		it("update_all before boot is a no-op (no error)", function()
			local r = Registry.new()
			local plugin = {
				init = function(_self, _ctx) end,
				update = function(_self, _dt)
					error("should not be called before boot")
				end,
			}
			r:register("p", plugin)
			assert.has_no.errors(function()
				r:update_all(0.016)
			end)
		end)

		it("tolerant mode: logs and continues when a plugin update() errors", function()
			local logged = {}
			local r = Registry.new({
				config = { error_mode = "tolerant" },
				log = function(msg)
					table.insert(logged, msg)
				end,
			})
			local update_log = {}
			local bad_plugin = {
				init = function(_self, _ctx) end,
				update = function(_self, _dt)
					error("update failed intentionally")
				end,
			}
			local good_plugin = {
				init = function(_self, _ctx) end,
				update = function(_self, _dt)
					table.insert(update_log, "update:good")
				end,
			}
			r:register("bad", bad_plugin)
			r:register("good", good_plugin)
			r:boot(make_ctx())
			assert.has_no.errors(function()
				r:update_all(0.016)
			end)
			-- good_plugin should still update
			assert.are.equal(1, #update_log)
			assert.are.equal("update:good", update_log[1])
			-- error should be logged
			assert.is_true(#logged > 0)
		end)

		it("strict mode: propagates plugin update() error", function()
			local r = Registry.new() -- default = strict
			local bad_plugin = {
				init = function(_self, _ctx) end,
				update = function(_self, _dt)
					error("update failed in strict mode")
				end,
			}
			r:register("bad", bad_plugin)
			r:boot(make_ctx())
			local ok, err = pcall(function()
				r:update_all(0.016)
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("strict mode") or err:find("update failed"))
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
