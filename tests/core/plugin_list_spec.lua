--- Tests for src/core/plugin_list.lua
--- Verifies the boot manifest structure and conventions.
---
--- Run with: busted tests/core/plugin_list_spec.lua

local plugin_list = require("src.core.plugin_list")

describe("plugin_list", function()
	it("is a table", function()
		assert.is_table(plugin_list)
	end)

	it("contains the input plugin", function()
		-- Phase 3 added the input plugin as the first boot manifest entry.
		assert.are.equal(1, #plugin_list)
		assert.are.equal("input", plugin_list[1].name)
	end)

	it("each entry has required fields when populated", function()
		-- Validate the shape contract for future entries.
		-- When plugins are added, each entry must have: name, module, deps.
		for _, entry in ipairs(plugin_list) do
			assert.is_string(entry.name, "entry.name must be a string")
			assert.is_string(entry.module, "entry.module must be a string")
			assert.is_table(entry.deps, "entry.deps must be a table")
		end
	end)
end)
