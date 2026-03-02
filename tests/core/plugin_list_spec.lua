--- Tests for src/core/plugin_list.lua
--- Verifies the boot manifest structure and conventions.
---
--- Run with: busted tests/core/plugin_list_spec.lua

local plugin_list = require("src.core.plugin_list")

describe("plugin_list", function()
	it("is a table", function()
		assert.is_table(plugin_list)
	end)

	it("contains the input plugin as the first entry", function()
		-- Phase 3 added the input plugin as the first boot manifest entry.
		assert.are.equal("input", plugin_list[1].name)
	end)

	it("contains the assets plugin as the second entry", function()
		-- Phase 4 added the assets plugin after the input plugin.
		assert.are.equal("assets", plugin_list[2].name)
		assert.are.equal("src.plugins.assets", plugin_list[2].module)
		assert.are.same({}, plugin_list[2].deps)
	end)

	it("contains the stacker plugin as the third entry", function()
		assert.are.equal("stacker", plugin_list[3].name)
		assert.are.equal("src.plugins.stacker", plugin_list[3].module)
		assert.are.same({}, plugin_list[3].deps)
	end)

	it("has three entries total (input + assets + stacker)", function()
		assert.are.equal(3, #plugin_list)
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
