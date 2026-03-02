-- AssetLoader tests.
-- Pure Lua — no Love2D runtime required.
-- Tests all behaviors: load_manifest, load_single, update, is_complete, get_loaded, shutdown.
-- Uses a Lily stub and real Bus for event verification.

local AssetLoader = require("src.plugins.assets.asset_loader")
local Bus = require("src.core.bus")

-- Build a Lily stub that stores callbacks and can be triggered synchronously.
local function make_lily_stub()
	local stub = { _update_mode = nil, _quit_called = false, _last_multi = nil }

	function stub.setUpdateMode(mode)
		stub._update_mode = mode
	end

	function stub.update()
		-- In tests we trigger callbacks manually via handle:_simulate_complete()
		-- This is intentionally a no-op for stub — tests drive callbacks directly
	end

	function stub.quit()
		stub._quit_called = true
	end

	function stub.newImage(path)
		return { _path = path, _type = "image" }
	end

	function stub.newFont(path, size)
		return { _path = path, _size = size, _type = "font" }
	end

	function stub.newSource(path, mode)
		return { _path = path, _mode = mode, _type = "sound" }
	end

	function stub.loadMulti(items)
		local handle = { _items = items, _callbacks = {} }

		function handle:onLoaded(fn)
			self._callbacks.onLoaded = fn
		end

		function handle:onComplete(fn)
			self._callbacks.onComplete = fn
		end

		function handle:onError(fn)
			self._callbacks.onError = fn
		end

		-- Helper: simulate successful completion of all items
		function handle:_simulate_complete(values)
			for i, v in ipairs(values) do
				if self._callbacks.onLoaded then
					self._callbacks.onLoaded(self, i, v)
				end
			end
			if self._callbacks.onComplete then
				self._callbacks.onComplete(self, values)
			end
		end

		-- Helper: simulate an error
		function handle:_simulate_error(msg)
			if self._callbacks.onError then
				self._callbacks.onError(self, msg, "traceback")
			end
		end

		stub._last_multi = handle
		return handle
	end

	return stub
end

-- Collect all bus events into a list so tests can inspect them.
local function collect_events(bus, event_name)
	local events = {}
	bus:on(event_name, function(data)
		table.insert(events, data)
	end)
	return events
end

describe("AssetLoader", function()
	describe("construction", function()
		it("creates an AssetLoader with injected lily stub", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })
			assert.not_nil(loader)
		end)

		it("calls lily.setUpdateMode('manual') on construction", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			AssetLoader.new({ lily = lily, bus = bus })
			assert.equal("manual", lily._update_mode)
		end)

		it("is_complete returns true initially (no pending loads)", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })
			assert.is_true(loader:is_complete())
		end)

		it("get_loaded returns empty table initially", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })
			assert.same({}, loader:get_loaded())
		end)
	end)

	describe("load_manifest", function()
		it("calls lily.loadMulti with correct items for image requests", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local load_requests = {
				{ key = "player_idle", path = "assets/sprites/player_idle.png", type = "image", group = "sprites" },
			}
			loader:load_manifest(load_requests)

			assert.not_nil(lily._last_multi)
			assert.equal(1, #lily._last_multi._items)
			-- Items are { fn, path } tuples
			assert.equal(lily.newImage, lily._last_multi._items[1][1])
			assert.equal("assets/sprites/player_idle.png", lily._last_multi._items[1][2])
		end)

		it("calls lily.loadMulti with correct items for font requests", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local load_requests = {
				{ key = "ui_font", path = "assets/fonts/ui.ttf", type = "font", extra = { size = 16 } },
			}
			loader:load_manifest(load_requests)

			assert.not_nil(lily._last_multi)
			assert.equal(lily.newFont, lily._last_multi._items[1][1])
			assert.equal("assets/fonts/ui.ttf", lily._last_multi._items[1][2])
			assert.equal(16, lily._last_multi._items[1][3])
		end)

		it("calls lily.loadMulti with correct items for sound requests", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local load_requests = {
				{ key = "jump_sfx", path = "assets/sfx/jump.ogg", type = "sound", extra = { mode = "static" } },
			}
			loader:load_manifest(load_requests)

			assert.not_nil(lily._last_multi)
			assert.equal(lily.newSource, lily._last_multi._items[1][1])
			assert.equal("assets/sfx/jump.ogg", lily._last_multi._items[1][2])
			assert.equal("static", lily._last_multi._items[1][3])
		end)

		it("is_complete returns false after load_manifest (before callbacks)", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			loader:load_manifest({
				{ key = "player_idle", path = "assets/sprites/player_idle.png", type = "image" },
			})
			assert.is_false(loader:is_complete())
		end)

		it("onLoaded callback emits 'asset:loaded' bus event with key, type, path", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local loaded_events = collect_events(bus, "asset:loaded")

			local load_requests = {
				{ key = "player_idle", path = "assets/sprites/player_idle.png", type = "image" },
			}
			loader:load_manifest(load_requests)

			-- Simulate Lily completing the first item
			local fake_image = { _type = "image" }
			lily._last_multi:_simulate_complete({ fake_image })

			-- Flush bus to dispatch events
			bus:flush()

			assert.equal(1, #loaded_events)
			assert.equal("player_idle", loaded_events[1].key)
			assert.equal("image", loaded_events[1].type)
			assert.equal("assets/sprites/player_idle.png", loaded_events[1].path)
		end)

		it("onComplete callback emits 'asset:batch_complete' bus event with keys", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local batch_events = collect_events(bus, "asset:batch_complete")

			local load_requests = {
				{ key = "player_idle", path = "assets/sprites/player_idle.png", type = "image" },
				{ key = "enemy_walk",  path = "assets/enemies/enemy_walk.png",  type = "image" },
			}
			loader:load_manifest(load_requests)

			local fake_img1 = { _type = "image", _id = 1 }
			local fake_img2 = { _type = "image", _id = 2 }
			lily._last_multi:_simulate_complete({ fake_img1, fake_img2 })
			bus:flush()

			assert.equal(1, #batch_events)
			assert.equal(2, #batch_events[1].keys)
		end)

		it("stores loaded objects in get_loaded() after callbacks fire", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local load_requests = {
				{ key = "player_idle", path = "assets/sprites/player_idle.png", type = "image" },
			}
			loader:load_manifest(load_requests)

			local fake_image = { _type = "image" }
			lily._last_multi:_simulate_complete({ fake_image })

			local loaded = loader:get_loaded()
			assert.equal(fake_image, loaded["player_idle"])
		end)

		it("is_complete returns true after batch completes", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			loader:load_manifest({
				{ key = "player_idle", path = "assets/sprites/player_idle.png", type = "image" },
			})

			lily._last_multi:_simulate_complete({ { _type = "image" } })
			assert.is_true(loader:is_complete())
		end)

		it("handles mixed image/font/sound requests in one batch", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local loaded_events = collect_events(bus, "asset:loaded")

			loader:load_manifest({
				{ key = "player_idle", path = "assets/sprites/player_idle.png", type = "image" },
				{ key = "ui_font",     path = "assets/fonts/ui.ttf",            type = "font",  extra = { size = 16 } },
				{ key = "jump_sfx",    path = "assets/sfx/jump.ogg",            type = "sound", extra = { mode = "static" } },
			})

			assert.equal(3, #lily._last_multi._items)

			local fake_img   = { _type = "image" }
			local fake_font  = { _type = "font" }
			local fake_sound = { _type = "sound" }
			lily._last_multi:_simulate_complete({ fake_img, fake_font, fake_sound })
			bus:flush()

			assert.equal(3, #loaded_events)
		end)
	end)

	describe("error handling", function()
		it("strict mode: raises error when Lily reports an error", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus, error_mode = "strict" })

			loader:load_manifest({
				{ key = "missing_image", path = "assets/missing.png", type = "image" },
			})

			assert.has_error(function()
				lily._last_multi:_simulate_error("file not found")
			end)
		end)

		it("tolerant mode: logs warning but does not raise when Lily reports error", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local log_messages = {}
			local function capture_log(msg)
				table.insert(log_messages, msg)
			end

			local loader = AssetLoader.new({ lily = lily, bus = bus, error_mode = "tolerant", log = capture_log })

			loader:load_manifest({
				{ key = "missing_image", path = "assets/missing.png", type = "image" },
			})

			-- Should not raise
			assert.has_no_error(function()
				lily._last_multi:_simulate_error("file not found")
			end)

			-- Should have logged a warning
			assert.is_true(#log_messages > 0)
		end)
	end)

	describe("update", function()
		it("calls lily.update()", function()
			local lily = make_lily_stub()
			local update_calls = 0
			lily.update = function()
				update_calls = update_calls + 1
			end

			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })
			loader:update()
			assert.equal(1, update_calls)
		end)
	end)

	describe("load_single", function()
		it("loads a single image asynchronously", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			local loaded_events = collect_events(bus, "asset:loaded")

			loader:load_single("hero_portrait", "assets/ui/hero.png", "image", nil)

			assert.not_nil(lily._last_multi)

			local fake_image = { _type = "image" }
			lily._last_multi:_simulate_complete({ fake_image })
			bus:flush()

			assert.equal(1, #loaded_events)
			assert.equal("hero_portrait", loaded_events[1].key)
		end)

		it("load_single stores loaded object in get_loaded()", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })

			loader:load_single("hero_portrait", "assets/ui/hero.png", "image", nil)

			local fake_image = { _type = "image" }
			lily._last_multi:_simulate_complete({ fake_image })

			local loaded = loader:get_loaded()
			assert.equal(fake_image, loaded["hero_portrait"])
		end)
	end)

	describe("shutdown", function()
		it("calls lily.quit()", function()
			local lily = make_lily_stub()
			local bus = Bus.new()
			local loader = AssetLoader.new({ lily = lily, bus = bus })
			loader:shutdown()
			assert.is_true(lily._quit_called)
		end)
	end)

	describe("architecture enforcement", function()
		it("asset_loader.lua source does not contain evolved.spawn or evolved.id calls", function()
			-- Read source file and check for disallowed ECS calls
			local f = io.open("src/plugins/assets/asset_loader.lua", "r")
			if f then
				local src = f:read("*all")
				f:close()
				assert.is_falsy(src:find("evolved%.spawn"))
				assert.is_falsy(src:find("evolved%.id"))
			end
			-- If file doesn't exist yet (RED phase), test is skipped implicitly
		end)
	end)
end)
