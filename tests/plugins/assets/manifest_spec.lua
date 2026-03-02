-- Manifest parser tests.
-- Pure Lua — no Love2D runtime required.
-- Tests all behaviors: image grouping, font extras, sound extras, error on unknown type.

local Manifest = require("src.plugins.assets.manifest")

describe("Manifest.parse", function()
	describe("empty input", function()
		it("returns empty load_requests and groups for empty table", function()
			local load_requests, groups = Manifest.parse({})
			assert.same({}, load_requests)
			assert.same({}, groups)
		end)

		it("returns empty load_requests and groups for nil input", function()
			local load_requests, groups = Manifest.parse(nil)
			assert.same({}, load_requests)
			assert.same({}, groups)
		end)
	end)

	describe("image entries", function()
		it("derives group from directory segment when no explicit group", function()
			local manifest = {
				player_idle = { path = "assets/sprites/player_idle.png", type = "image" },
			}
			local load_requests, groups = Manifest.parse(manifest)

			assert.equal(1, #load_requests)
			local req = load_requests[1]
			assert.equal("player_idle", req.key)
			assert.equal("assets/sprites/player_idle.png", req.path)
			assert.equal("image", req.type)
			assert.equal("sprites", req.group)

			-- Group index should contain the key
			assert.not_nil(groups["sprites"])
			local found = false
			for _, k in ipairs(groups["sprites"]) do
				if k == "player_idle" then
					found = true
				end
			end
			assert.is_true(found)
		end)

		it("uses explicit group override", function()
			local manifest = {
				player_run = { path = "assets/sprites/player_run.png", type = "image", group = "player" },
			}
			local load_requests, groups = Manifest.parse(manifest)

			assert.equal(1, #load_requests)
			local req = load_requests[1]
			assert.equal("player", req.group)
			assert.not_nil(groups["player"])
		end)

		it("marks atlas=false images as standalone (group=nil)", function()
			local manifest = {
				background = { path = "assets/bg/title.png", type = "image", atlas = false },
			}
			local load_requests, groups = Manifest.parse(manifest)

			assert.equal(1, #load_requests)
			local req = load_requests[1]
			assert.is_nil(req.group)

			-- No group entry should be created for standalone
			assert.same({}, groups)
		end)

		it("groups multiple images in the same directory together", function()
			local manifest = {
				player_idle = { path = "assets/sprites/player_idle.png", type = "image" },
				player_run  = { path = "assets/sprites/player_run.png",  type = "image" },
			}
			local _load_requests, groups = Manifest.parse(manifest)

			assert.not_nil(groups["sprites"])
			assert.equal(2, #groups["sprites"])
		end)

		it("images in different directories go into different groups", function()
			local manifest = {
				player_idle = { path = "assets/sprites/player_idle.png", type = "image" },
				enemy_walk  = { path = "assets/enemies/enemy_walk.png",  type = "image" },
			}
			local _load_requests, groups = Manifest.parse(manifest)

			assert.not_nil(groups["sprites"])
			assert.not_nil(groups["enemies"])
			assert.equal(1, #groups["sprites"])
			assert.equal(1, #groups["enemies"])
		end)

		it("sets extra to nil for standard image entries", function()
			local manifest = {
				player_idle = { path = "assets/sprites/player_idle.png", type = "image" },
			}
			local load_requests, _groups = Manifest.parse(manifest)
			local req = load_requests[1]
			assert.is_nil(req.extra)
		end)
	end)

	describe("font entries", function()
		it("parses font entry with size in extra", function()
			local manifest = {
				ui_font = { path = "assets/fonts/ui.ttf", type = "font", size = 16 },
			}
			local load_requests, groups = Manifest.parse(manifest)

			assert.equal(1, #load_requests)
			local req = load_requests[1]
			assert.equal("ui_font", req.key)
			assert.equal("assets/fonts/ui.ttf", req.path)
			assert.equal("font", req.type)
			assert.is_nil(req.group)
			assert.not_nil(req.extra)
			assert.equal(16, req.extra.size)

			-- Fonts never create atlas groups
			assert.same({}, groups)
		end)

		it("defaults font size to 12 when not specified", function()
			local manifest = {
				ui_font = { path = "assets/fonts/ui.ttf", type = "font" },
			}
			local load_requests, _groups = Manifest.parse(manifest)
			local req = load_requests[1]
			assert.equal(12, req.extra.size)
		end)

		it("fonts are always standalone (group=nil)", function()
			local manifest = {
				ui_font = { path = "assets/fonts/ui.ttf", type = "font", size = 14 },
			}
			local load_requests, _groups = Manifest.parse(manifest)
			assert.is_nil(load_requests[1].group)
		end)
	end)

	describe("sound entries", function()
		it("parses sound entry with mode in extra", function()
			local manifest = {
				jump_sfx = { path = "assets/sfx/jump.ogg", type = "sound", mode = "static" },
			}
			local load_requests, groups = Manifest.parse(manifest)

			assert.equal(1, #load_requests)
			local req = load_requests[1]
			assert.equal("jump_sfx", req.key)
			assert.equal("assets/sfx/jump.ogg", req.path)
			assert.equal("sound", req.type)
			assert.is_nil(req.group)
			assert.not_nil(req.extra)
			assert.equal("static", req.extra.mode)

			-- Sounds never create atlas groups
			assert.same({}, groups)
		end)

		it("defaults sound mode to 'static' when not specified", function()
			local manifest = {
				jump_sfx = { path = "assets/sfx/jump.ogg", type = "sound" },
			}
			local load_requests, _groups = Manifest.parse(manifest)
			local req = load_requests[1]
			assert.equal("static", req.extra.mode)
		end)

		it("sounds are always standalone (group=nil)", function()
			local manifest = {
				jump_sfx = { path = "assets/sfx/jump.ogg", type = "sound" },
			}
			local load_requests, _groups = Manifest.parse(manifest)
			assert.is_nil(load_requests[1].group)
		end)
	end)

	describe("error handling", function()
		it("raises an error for unknown asset type", function()
			local manifest = {
				mystery = { path = "assets/mystery.bin", type = "video" },
			}
			assert.has_error(function()
				Manifest.parse(manifest)
			end)
		end)

		it("error message includes the unknown type name", function()
			local manifest = {
				mystery = { path = "assets/mystery.bin", type = "video" },
			}
			local ok, err = pcall(Manifest.parse, manifest)
			assert.is_false(ok)
			assert.is_truthy(err:find("video"))
		end)
	end)

	describe("mixed manifest", function()
		it("parses all three types in one call", function()
			local manifest = {
				player_idle = { path = "assets/sprites/player_idle.png", type = "image" },
				player_run  = { path = "assets/sprites/player_run.png",  type = "image", group = "player" },
				ui_font     = { path = "assets/fonts/ui.ttf",            type = "font",  size = 16 },
				jump_sfx    = { path = "assets/sfx/jump.ogg",            type = "sound", mode = "static" },
				background  = { path = "assets/bg/title.png",            type = "image", atlas = false },
			}
			local load_requests, groups = Manifest.parse(manifest)

			-- Five entries total
			assert.equal(5, #load_requests)

			-- Groups: "sprites" (player_idle only — player_run overridden to "player"), "player"
			assert.not_nil(groups["sprites"])
			assert.not_nil(groups["player"])

			-- background is standalone — no group
			local bg_req
			for _, r in ipairs(load_requests) do
				if r.key == "background" then
					bg_req = r
				end
			end
			assert.not_nil(bg_req)
			assert.is_nil(bg_req.group)

			-- Fonts and sounds not in any group
			local font_in_groups = false
			for _, keys in pairs(groups) do
				for _, k in ipairs(keys) do
					if k == "ui_font" or k == "jump_sfx" then
						font_in_groups = true
					end
				end
			end
			assert.is_false(font_in_groups)
		end)
	end)
end)
