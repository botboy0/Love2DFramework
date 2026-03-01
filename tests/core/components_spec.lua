--- Tests for src/core/components.lua
--- Framework-agnostic component registry placeholder.
--- Ships empty — each game defines its own fragment IDs.
---
--- Run with: busted tests/core/components_spec.lua

local Components = require("src.core.components")

describe("Components", function()
	it("returns a table", function()
		assert.is_table(Components)
	end)

	it("ships empty — no pre-defined fragments", function()
		assert.is_nil(next(Components))
	end)

	it("has no Position fragment", function()
		assert.is_nil(Components.Position)
	end)

	it("has no Velocity fragment", function()
		assert.is_nil(Components.Velocity)
	end)

	it("has no Health fragment", function()
		assert.is_nil(Components.Health)
	end)
end)
