--- Asset Plugin
--- Orchestrates the load-then-pack pipeline for all game assets.
---
--- Registers the "assets" service for accessing loaded assets:
---   get(key)               -- returns DrawableWrapper for loaded asset
---   get_atlas(group_name)  -- returns raw atlas { canvas, wrappers } or nil
---   is_ready()             -- true when manifest batch load + atlas pack complete
---
--- Pipeline:
---   1. init() parses manifest, starts Lily async batch load
---   2. update() polls Lily each frame (fires loader callbacks)
---   3. asset:batch_complete fires -> AtlasBuilder packs images -> wrappers stored
---   4. asset:ready emitted (if loading_phase enabled)
---
--- Bus events emitted:
---   asset:ready  {}  — emitted once when all manifest assets are ready
---
--- Config keys (under ctx.config.assets):
---   manifest      table   asset key -> { type, path, ... } definitions
---   loading_phase bool    whether to emit asset:ready (default true)
---   error_mode    string  "strict"|"tolerant" (default from ctx.config.error_mode or "strict")
---   fallback      string  key of a pre-loaded fallback asset (tolerant mode only)
---
--- Follow canonical_plugin.lua pattern exactly.
--- See CLAUDE.md for architectural rules.

local AssetLoader = require("src.plugins.assets.asset_loader")
local AtlasBuilder = require("src.plugins.assets.atlas_builder")
local DrawableWrapper = require("src.plugins.assets.drawable_wrapper")
local Manifest = require("src.plugins.assets.manifest")

local AssetPlugin = {}
AssetPlugin.__index = AssetPlugin

--- Plugin metadata
AssetPlugin.name = "assets"
AssetPlugin.deps = {}

--- Resolve error mode from config.
--- Priority: config.error_modes.assets > config.error_mode > default "strict"
--- @param assets_config table  ctx.config.assets
--- @param global_config table  ctx.config (full config table)
--- @return string  "strict" | "tolerant"
local function resolve_error_mode(assets_config, global_config)
	if assets_config and assets_config.error_mode then
		return assets_config.error_mode
	end
	if global_config and global_config.error_modes and global_config.error_modes.assets then
		return global_config.error_modes.assets
	end
	if global_config and global_config.error_mode then
		return global_config.error_mode
	end
	return "strict"
end

--- Initialize the asset plugin.
--- @param ctx  table  { worlds, bus, config, services }
--- @param _opts table|nil  Dependency injection for testing:
---   { _manifest, _asset_loader_new, _atlas_builder_new, _drawable_wrapper }
function AssetPlugin:init(ctx, _opts)
	_opts = _opts or {}

	-- Dependency injection (for testing isolation)
	local manifest_mod = _opts._manifest or Manifest
	local asset_loader_new = _opts._asset_loader_new or function(o)
		return AssetLoader.new(o)
	end
	local atlas_builder_new = _opts._atlas_builder_new or function(o)
		return AtlasBuilder.new(o)
	end
	local drawable_wrapper_mod = _opts._drawable_wrapper or DrawableWrapper

	self._bus = ctx.bus

	-- Read config
	local assets_config = (ctx.config and ctx.config.assets) or {}
	local error_mode = resolve_error_mode(assets_config, ctx.config)
	local loading_phase = assets_config.loading_phase ~= false -- default true
	local fallback_key = assets_config.fallback -- optional fallback asset key

	-- Parse manifest into load requests and group map
	local load_requests, groups = manifest_mod.parse(assets_config.manifest or {})

	-- Build a set of manifest keys for strict-mode get() enforcement
	local manifest_keys = {}
	for _, req in ipairs(load_requests) do
		manifest_keys[req.key] = true
	end

	-- Create the async asset loader
	self._loader = asset_loader_new({
		bus = ctx.bus,
		error_mode = error_mode,
		log = print,
	})

	-- Create the atlas builder (no love.graphics yet — deferred to build time)
	self._atlas_builder = atlas_builder_new({
		log = print,
		max_size = 4096,
	})

	-- Plugin state
	self._assets = {} -- key -> DrawableWrapper (populated after batch_complete)
	self._ready = false
	self._loading_phase = loading_phase
	self._error_mode = error_mode
	self._manifest_keys = manifest_keys
	self._groups = groups
	self._drawable_wrapper_mod = drawable_wrapper_mod

	-- Resolve fallback wrapper (standalone, loaded synchronously if pre-loaded)
	self._fallback_wrapper = nil
	if fallback_key then
		local loaded = self._loader:get_loaded()
		if loaded[fallback_key] then
			self._fallback_wrapper = drawable_wrapper_mod.from_standalone(loaded[fallback_key])
		end
	end

	-- Pending ready flag: set by _on_batch_complete, emitted in next update()
	-- This avoids emitting during a flush() call (bus re-entrancy guard would discard it).
	self._pending_ready = false

	-- Subscribe to batch_complete to trigger atlas packing
	ctx.bus:on("asset:batch_complete", function(_data)
		self:_on_batch_complete()
	end)

	-- Start async manifest load
	self._loader:load_manifest(load_requests)

	-- Register the "assets" service
	-- Service methods are plain functions (not :methods) — callers use svc.get("key")
	ctx.services:register("assets", {
		get = function(key)
			return self:_get(key)
		end,
		get_atlas = function(group_name)
			return self._atlas_builder:get_atlas(group_name)
		end,
		is_ready = function()
			return self._ready
		end,
	})
end

--- Internal batch_complete handler.
--- Called when Lily finishes loading all manifest assets.
--- Packs atlas-eligible images, wraps standalones, marks ready.
function AssetPlugin:_on_batch_complete()
	local loaded = self._loader:get_loaded()

	-- Separate atlas-eligible images from standalone assets
	local atlas_images = {} -- key -> image (for atlas builder)
	for group_name, keys in pairs(self._groups) do
		for _, key in ipairs(keys) do
			if loaded[key] then
				atlas_images[key] = loaded[key]
			end
		end
		_ = group_name -- prevent unused warning
	end

	-- Build atlases and collect all atlas wrappers
	local atlases = self._atlas_builder:build(self._groups, atlas_images)
	for _group_name, atlas_data in pairs(atlases) do
		if atlas_data.wrappers then
			for key, wrapper in pairs(atlas_data.wrappers) do
				self._assets[key] = wrapper
			end
		end
	end

	-- Wrap standalone assets (fonts, sounds, non-atlas images)
	-- Any loaded asset not already in self._assets (not atlas-packed) is standalone
	for key, asset in pairs(loaded) do
		if not self._assets[key] then
			self._assets[key] = self._drawable_wrapper_mod.from_standalone(asset)
		end
	end

	-- Mark ready; defer asset:ready emit to next update() to avoid bus re-entrancy.
	-- The batch_complete handler fires during bus:flush() — emitting here would be discarded.
	if self._loading_phase then
		self._ready = true
		self._pending_ready = true
	end
end

--- Internal get() implementation — returns DrawableWrapper or handles missing asset.
--- @param key string  Asset key
--- @return table|nil  DrawableWrapper or nil
function AssetPlugin:_get(key)
	-- Fast path: asset is loaded and wrapped
	if self._assets[key] then
		return self._assets[key]
	end

	-- Key is in the manifest but not yet available
	if self._manifest_keys[key] then
		if self._error_mode == "strict" then
			error(
				string.format(
					"[AssetPlugin] assets:get('%s') — manifest asset not loaded yet. "
						.. "Wait for asset:ready event before accessing assets.",
					key
				),
				2
			)
		else
			-- Tolerant: return fallback or nil
			return self._fallback_wrapper
		end
	end

	-- Key is not in manifest — treat as on-demand (still loading or never started)
	-- On-demand assets return nil while loading, never error
	return nil
end

--- Per-frame update: polls Lily to fire completed callbacks, then emits deferred events.
--- Order: loader:update() (fires Lily callbacks -> queues bus events) -> emit pending_ready
--- The asset:ready event is emitted here (not inside batch_complete handler) to avoid
--- bus re-entrancy: handlers cannot safely emit events during flush().
--- @param _dt number  Delta time (unused — loader handles timing)
function AssetPlugin:update(_dt)
	self._loader:update()

	-- Emit deferred asset:ready (set by _on_batch_complete after the flush cycle)
	if self._pending_ready then
		self._pending_ready = false
		self._bus:emit("asset:ready", {})
	end
end

--- Shutdown: release Lily worker threads.
--- @param _ctx table  Context (unused)
function AssetPlugin:shutdown(_ctx)
	self._loader:shutdown()
end

return AssetPlugin
