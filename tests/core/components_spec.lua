--- Tests for src/core/components.lua
--- Game-specific ECS fragment ID registry.
--- Now populated with stacker game fragments: StackBlock, MovingBlock, GameState.
---
--- Run with: busted tests/core/components_spec.lua

local Components = require("src.core.components")

describe("Components", function()
	it("returns a table", function()
		assert.is_table(Components)
	end)

	it("exports StackBlock fragment ID (stacker game)", function()
		assert.is_not_nil(Components.StackBlock)
		assert.is_number(Components.StackBlock)
	end)

	it("exports MovingBlock fragment ID (stacker game)", function()
		assert.is_not_nil(Components.MovingBlock)
		assert.is_number(Components.MovingBlock)
	end)

	it("exports GameState fragment ID (stacker game)", function()
		assert.is_not_nil(Components.GameState)
		assert.is_number(Components.GameState)
	end)

	it("all fragment IDs are distinct", function()
		assert.are_not.equal(Components.StackBlock, Components.MovingBlock)
		assert.are_not.equal(Components.MovingBlock, Components.GameState)
		assert.are_not.equal(Components.StackBlock, Components.GameState)
	end)

	it("has no Position fragment (framework is genre-agnostic)", function()
		assert.is_nil(Components.Position)
	end)

	it("has no Velocity fragment (framework is genre-agnostic)", function()
		assert.is_nil(Components.Velocity)
	end)
end)
