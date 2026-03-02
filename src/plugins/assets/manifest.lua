--- Manifest parser for the asset pipeline.
--- Converts ctx.config.assets.manifest into typed load requests and group maps.
---
--- Usage:
---   local Manifest = require("src.plugins.assets.manifest")
---   local load_requests, groups = Manifest.parse(ctx.config.assets.manifest)
---
--- Returns:
---   load_requests: array of { key, path, type, group, extra }
---   groups: table mapping group_name -> array of keys (atlas-eligible images only)
---
--- Pure Lua — no Love2D runtime dependency.

local Manifest = {}

--- Derive the atlas group name from an image path.
--- Extracts the second-to-last path segment (the directory containing the file).
--- E.g. "assets/sprites/player.png" -> "sprites"
---      "assets/bg/title.png"       -> "bg"
--- @param path string  File path
--- @return string|nil  Directory segment, or nil if path has fewer than 2 segments
local function derive_group(path)
	-- Split on "/" and grab the second-to-last component
	local segments = {}
	for segment in path:gmatch("[^/]+") do
		segments[#segments + 1] = segment
	end
	-- Need at least 2 segments: [directory, filename]
	if #segments >= 2 then
		return segments[#segments - 1]
	end
	return nil
end

--- Parse a manifest table into load requests and group map.
--- @param manifest_table table|nil  The ctx.config.assets.manifest table
--- @return table load_requests  Array of { key, path, type, group, extra }
--- @return table groups         Map of group_name -> { keys } (atlas-eligible only)
function Manifest.parse(manifest_table)
	local load_requests = {}
	local groups = {}

	if not manifest_table then
		return load_requests, groups
	end

	for key, entry in pairs(manifest_table) do
		local asset_type = entry.type

		if asset_type == "image" then
			local group

			if entry.atlas == false then
				-- Explicitly standalone — no atlas group
				group = nil
			elseif entry.group ~= nil then
				-- Explicit group override
				group = entry.group
			else
				-- Default: derive from directory segment
				group = derive_group(entry.path)
			end

			load_requests[#load_requests + 1] = {
				key = key,
				path = entry.path,
				type = "image",
				group = group,
				extra = nil,
			}

			-- Register in group index only if atlas-eligible
			if group ~= nil then
				if not groups[group] then
					groups[group] = {}
				end
				groups[group][#groups[group] + 1] = key
			end
		elseif asset_type == "font" then
			load_requests[#load_requests + 1] = {
				key = key,
				path = entry.path,
				type = "font",
				group = nil,
				extra = { size = entry.size or 12 },
			}
		elseif asset_type == "sound" then
			load_requests[#load_requests + 1] = {
				key = key,
				path = entry.path,
				type = "sound",
				group = nil,
				extra = { mode = entry.mode or "static" },
			}
		else
			error(
				string.format(
					"[Manifest] Unknown asset type '%s' for key '%s'. " .. "Expected 'image', 'font', or 'sound'.",
					tostring(asset_type),
					tostring(key)
				)
			)
		end
	end

	return load_requests, groups
end

return Manifest
