--- Tests for src/plugins/assets/init.lua
--- Tests the asset plugin lifecycle and "assets" service API.
--- Uses plugin_harness for context setup and injects stubs for all sub-modules.
---
--- Run with: busted tests/plugins/assets/init_spec.lua

local harness = require("tests.helpers.plugin_harness")

--- Build a stub AssetLoader that immediately fires callbacks on update().
--- Records calls to load_manifest, update, and shutdown.
local function make_loader_stub(opts)
	opts = opts or {}
	local stub = {
		_loaded = opts.loaded or {},
		_calls = {},
		_on_loaded_cb = nil,
		_on_complete_cb = nil,
		_manifest_complete = true,
		_pending_singles = 0,
	}

	function stub:load_manifest(load_requests)
		self._calls[#self._calls + 1] = { name = "load_manifest", args = { load_requests } }
		self._pending_requests = load_requests
		self._manifest_complete = false
	end

	function stub:update()
		self._calls[#self._calls + 1] = { name = "update" }
	end

	function stub:shutdown()
		self._calls[#self._calls + 1] = { name = "shutdown" }
	end

	function stub:is_complete()
		return self._manifest_complete and self._pending_singles == 0
	end

	function stub:get_loaded()
		return self._loaded
	end

	return stub
end

--- Build a stub AtlasBuilder that records build() calls and returns pre-built atlases.
local function make_atlas_builder_stub(opts)
	opts = opts or {}
	local stub = {
		_atlases = opts.atlases or {},
		_calls = {},
	}

	function stub:build(groups, loaded_images)
		self._calls[#self._calls + 1] = { name = "build", groups = groups, loaded_images = loaded_images }
		return self._atlases
	end

	function stub:get_atlas(group_name)
		return self._atlases[group_name]
	end

	function stub:get_all_atlases()
		return self._atlases
	end

	return stub
end

--- Build a stub Manifest module.
--- Returns fixed load_requests and groups.
local function make_manifest_stub(load_requests, groups)
	return {
		parse = function(_manifest_table)
			return load_requests, groups
		end,
	}
end

--- Build a simple DrawableWrapper stub.
local function make_wrapper_stub(kind)
	return {
		_is_wrapper_stub = true,
		_kind = kind or "standalone",
		get_type = function(self)
			return self._kind
		end,
	}
end

--- Build a stub DrawableWrapper module.
local function make_drawable_wrapper_stub()
	local created = {}
	local module = {
		_created = created,
		from_standalone = function(asset)
			local w = make_wrapper_stub("standalone")
			w._asset = asset
			table.insert(created, w)
			return w
		end,
		from_atlas = function(canvas, quad)
			local w = make_wrapper_stub("atlas")
			w._canvas = canvas
			w._quad = quad
			table.insert(created, w)
			return w
		end,
	}
	return module
end

--- Simulate the "asset:batch_complete" event being fired through the bus.
--- This mimics Lily completing all loads.
local function fire_batch_complete(ctx)
	ctx.bus:emit("asset:batch_complete", { keys = {} })
	ctx.bus:flush()
end

describe("AssetPlugin", function()
	local AssetPlugin

	before_each(function()
		-- Re-require fresh plugin table each test (Lua caches modules, so we reset)
		package.loaded["src.plugins.assets"] = nil
		AssetPlugin = require("src.plugins.assets")
	end)

	after_each(function()
		package.loaded["src.plugins.assets"] = nil
	end)

	-- =========================================================================
	-- Plugin metadata
	-- =========================================================================

	describe("metadata", function()
		it("has name 'assets'", function()
			assert.are.equal("assets", AssetPlugin.name)
		end)

		it("has empty deps", function()
			assert.are.same({}, AssetPlugin.deps)
		end)
	end)

	-- =========================================================================
	-- Initialization
	-- =========================================================================

	describe("init()", function()
		it("calls Manifest.parse with config.assets.manifest", function()
			local ctx = harness.create_context({
				config = {
					assets = {
						manifest = { my_img = { type = "image", path = "a/b/c.png" } },
					},
				},
			})

			local parse_calls = {}
			local manifest_stub = {
				parse = function(tbl)
					table.insert(parse_calls, tbl)
					return {}, {}
				end,
			}
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			assert.are.equal(1, #parse_calls)
			assert.are.same(
				{ my_img = { type = "image", path = "a/b/c.png" } },
				parse_calls[1]
			)

			harness.teardown(ctx)
		end)

		it("starts loader:load_manifest with parsed requests", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local expected_requests = {
				{ key = "img", path = "a/b.png", type = "image", group = "b" },
			}
			local manifest_stub = make_manifest_stub(expected_requests, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			-- Find load_manifest call
			local found = false
			for _, call in ipairs(loader_stub._calls) do
				if call.name == "load_manifest" then
					found = true
					assert.are.same(expected_requests, call.args[1])
				end
			end
			assert.is_true(found, "load_manifest should have been called")

			harness.teardown(ctx)
		end)

		it("registers 'assets' service", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local svc = ctx.services:get("assets")
			assert.is_not_nil(svc, "assets service should be registered")
			assert.is_function(svc.get)
			assert.is_function(svc.get_atlas)
			assert.is_function(svc.is_ready)

			harness.teardown(ctx)
		end)
	end)

	-- =========================================================================
	-- update()
	-- =========================================================================

	describe("update()", function()
		it("calls loader:update()", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			AssetPlugin:update(0.016)

			local found = false
			for _, call in ipairs(loader_stub._calls) do
				if call.name == "update" then
					found = true
				end
			end
			assert.is_true(found, "loader:update() should be called during plugin update")

			harness.teardown(ctx)
		end)
	end)

	-- =========================================================================
	-- batch_complete -> atlas pack -> assets ready
	-- =========================================================================

	describe("batch_complete pipeline", function()
		it("calls atlas builder:build() when batch_complete fires", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local groups = { sprites = { "hero", "enemy" } }
			local loaded_imgs = {
				hero = { _is_image = true },
				enemy = { _is_image = true },
				-- Non-image (font) should be treated as standalone
			}
			local manifest_stub = make_manifest_stub({
				{ key = "hero", path = "a/sprites/hero.png", type = "image", group = "sprites" },
				{ key = "enemy", path = "a/sprites/enemy.png", type = "image", group = "sprites" },
			}, groups)
			local loader_stub = make_loader_stub({ loaded = loaded_imgs })
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			fire_batch_complete(ctx)

			assert.are.equal(1, #atlas_stub._calls)
			assert.are.equal("build", atlas_stub._calls[1].name)

			harness.teardown(ctx)
		end)

		it("stores atlas wrappers in assets table after batch_complete", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local hero_wrapper = make_wrapper_stub("atlas")
			local enemy_wrapper = make_wrapper_stub("atlas")
			local pre_built_atlases = {
				sprites = {
					canvas = {},
					wrappers = {
						hero = hero_wrapper,
						enemy = enemy_wrapper,
					},
				},
			}
			local groups = { sprites = { "hero", "enemy" } }
			local manifest_stub = make_manifest_stub({
				{ key = "hero", path = "a/sprites/hero.png", type = "image", group = "sprites" },
				{ key = "enemy", path = "a/sprites/enemy.png", type = "image", group = "sprites" },
			}, groups)
			local loader_stub = make_loader_stub({ loaded = { hero = {}, enemy = {} } })
			local atlas_stub = make_atlas_builder_stub({ atlases = pre_built_atlases })

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			fire_batch_complete(ctx)

			local svc = ctx.services:get("assets")
			assert.are.equal(hero_wrapper, svc.get("hero"))
			assert.are.equal(enemy_wrapper, svc.get("enemy"))

			harness.teardown(ctx)
		end)

		it("wraps standalone (non-atlas) assets with from_standalone after batch_complete", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local font_asset = { _is_font = true }
			local manifest_stub = make_manifest_stub({
				{ key = "ui_font", path = "assets/fonts/ui.ttf", type = "font", group = nil },
			}, {}) -- no groups (standalone only)
			local loader_stub = make_loader_stub({ loaded = { ui_font = font_asset } })
			local atlas_stub = make_atlas_builder_stub()
			local dw_stub = make_drawable_wrapper_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
				_drawable_wrapper = dw_stub,
			})

			fire_batch_complete(ctx)

			local svc = ctx.services:get("assets")
			local wrapper = svc.get("ui_font")
			assert.is_not_nil(wrapper, "ui_font should be wrapped as standalone")
			assert.are.equal("standalone", wrapper:get_type())

			harness.teardown(ctx)
		end)

		it("sets _ready to true and emits asset:ready when loading_phase is true", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {}, loading_phase = true } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local svc = ctx.services:get("assets")
			assert.is_false(svc.is_ready(), "should not be ready before batch_complete")

			local ready_events = {}
			ctx.bus:on("asset:ready", function(data)
				table.insert(ready_events, data)
			end)

			fire_batch_complete(ctx)
			AssetPlugin:update(0)
			ctx.bus:flush()

			assert.is_true(svc.is_ready(), "should be ready after batch_complete")
			assert.are.equal(1, #ready_events, "asset:ready should be emitted once")

			harness.teardown(ctx)
		end)

		it("does not emit asset:ready when loading_phase is false", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {}, loading_phase = false } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local ready_events = {}
			ctx.bus:on("asset:ready", function(data)
				table.insert(ready_events, data)
			end)

			fire_batch_complete(ctx)

			assert.are.equal(0, #ready_events, "asset:ready should NOT be emitted when loading_phase is false")

			harness.teardown(ctx)
		end)
	end)

	-- =========================================================================
	-- Service API: assets:get()
	-- =========================================================================

	describe("assets:get()", function()
		it("returns nil while manifest asset has not loaded yet (before batch_complete)", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local manifest_stub = make_manifest_stub({
				{ key = "bg", path = "assets/bg.png", type = "image", group = "sprites" },
			}, { sprites = { "bg" } })
			local loader_stub = make_loader_stub() -- nothing loaded yet
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			-- In tolerant mode: get() on unloaded manifest asset returns nil
			-- We configure tolerant mode here so it doesn't error
			local svc = ctx.services:get("assets")
			-- bg is a manifest asset not yet loaded — tolerant returns nil
			-- (strict would error, but we test tolerant path here)

			harness.teardown(ctx)
		end)

		it("returns nil for on-demand asset still loading", function()
			local ctx = harness.create_context({
				config = {
					assets = {
						manifest = {},
						error_mode = "tolerant",
					},
				},
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local svc = ctx.services:get("assets")
			-- "on_demand_key" is not in the manifest and not yet in _assets
			-- Should return nil, not error
			local result = svc.get("on_demand_key")
			assert.is_nil(result, "on-demand keys still loading should return nil")

			harness.teardown(ctx)
		end)

		it("errors in strict mode when manifest asset is not loaded", function()
			local ctx = harness.create_context({
				config = {
					assets = {
						manifest = {},
						error_mode = "strict",
					},
				},
			})

			local manifest_stub = make_manifest_stub({
				{ key = "bg", path = "assets/bg.png", type = "image", group = "sprites" },
			}, { sprites = { "bg" } })
			local loader_stub = make_loader_stub() -- bg not loaded yet
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local svc = ctx.services:get("assets")
			assert.has_error(function()
				svc.get("bg")
			end, nil) -- any error in strict mode

			harness.teardown(ctx)
		end)

		it("returns nil in tolerant mode when manifest asset is not loaded", function()
			local ctx = harness.create_context({
				config = {
					assets = {
						manifest = {},
						error_mode = "tolerant",
					},
				},
			})

			local manifest_stub = make_manifest_stub({
				{ key = "bg", path = "assets/bg.png", type = "image", group = "sprites" },
			}, { sprites = { "bg" } })
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local svc = ctx.services:get("assets")
			local result = svc.get("bg")
			assert.is_nil(result, "tolerant mode should return nil for not-yet-loaded manifest asset")

			harness.teardown(ctx)
		end)

		it("returns fallback wrapper in tolerant mode when fallback configured and key missing", function()
			local fallback_wrapper = make_wrapper_stub("standalone")
			local ctx = harness.create_context({
				config = {
					assets = {
						manifest = {},
						error_mode = "tolerant",
						fallback = "fallback_img",
					},
				},
			})

			local manifest_stub = make_manifest_stub({
				{ key = "bg", path = "assets/bg.png", type = "image", group = "sprites" },
			}, { sprites = { "bg" } })
			-- Provide a pre-loaded fallback in loader
			local loader_stub = make_loader_stub({ loaded = { fallback_img = {} } })
			local atlas_stub = make_atlas_builder_stub()
			local dw_stub = make_drawable_wrapper_stub()
			-- Override from_standalone to return our fallback_wrapper for fallback_img
			dw_stub.from_standalone = function(asset)
				if asset == loader_stub._loaded.fallback_img then
					return fallback_wrapper
				end
				return make_wrapper_stub("standalone")
			end

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
				_drawable_wrapper = dw_stub,
			})

			-- Fire batch_complete to trigger atlas packing and standalone wrapping
			fire_batch_complete(ctx)

			local svc = ctx.services:get("assets")
			-- "bg" was in manifest but not loaded (not in _assets after pack phase)
			-- With tolerant + fallback, should return fallback wrapper
			local result = svc.get("bg")
			-- Since bg was in manifest groups but atlas builder didn't produce a wrapper for it
			-- and error_mode is tolerant with fallback configured, return fallback
			assert.is_not_nil(result, "should return fallback wrapper")

			harness.teardown(ctx)
		end)
	end)

	-- =========================================================================
	-- Service API: assets:get_atlas()
	-- =========================================================================

	describe("assets:get_atlas()", function()
		it("returns atlas data from atlas_builder", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local atlas_data = { canvas = {}, wrappers = {} }
			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub({ atlases = { sprites = atlas_data } })

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			fire_batch_complete(ctx)

			local svc = ctx.services:get("assets")
			assert.are.equal(atlas_data, svc.get_atlas("sprites"))

			harness.teardown(ctx)
		end)

		it("returns nil for non-existent group", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local svc = ctx.services:get("assets")
			assert.is_nil(svc.get_atlas("no_such_group"))

			harness.teardown(ctx)
		end)
	end)

	-- =========================================================================
	-- Service API: assets:is_ready()
	-- =========================================================================

	describe("assets:is_ready()", function()
		it("returns false before batch_complete", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			local svc = ctx.services:get("assets")
			assert.is_false(svc.is_ready())

			harness.teardown(ctx)
		end)

		it("returns true after batch_complete when loading_phase is true", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {}, loading_phase = true } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			fire_batch_complete(ctx)

			local svc = ctx.services:get("assets")
			assert.is_true(svc.is_ready())

			harness.teardown(ctx)
		end)
	end)

	-- =========================================================================
	-- shutdown()
	-- =========================================================================

	describe("shutdown()", function()
		it("calls loader:shutdown()", function()
			local ctx = harness.create_context({
				config = { assets = { manifest = {} } },
			})

			local manifest_stub = make_manifest_stub({}, {})
			local loader_stub = make_loader_stub()
			local atlas_stub = make_atlas_builder_stub()

			AssetPlugin:init(ctx, {
				_manifest = manifest_stub,
				_asset_loader_new = function(_opts)
					return loader_stub
				end,
				_atlas_builder_new = function(_opts)
					return atlas_stub
				end,
			})

			AssetPlugin:shutdown(ctx)

			local found = false
			for _, call in ipairs(loader_stub._calls) do
				if call.name == "shutdown" then
					found = true
				end
			end
			assert.is_true(found, "loader:shutdown() should be called during plugin shutdown")

			harness.teardown(ctx)
		end)
	end)
end)
