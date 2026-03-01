--- Tests for src/core/components.lua
--- Shared component fragment definitions used across both ECS worlds.
---
--- Run with: busted tests/core/components_spec.lua

local Components = require("src.core.components")

describe("Components", function()
	it("exports Position fragment", function()
		assert.is_not_nil(Components.Position)
	end)

	it("exports Velocity fragment", function()
		assert.is_not_nil(Components.Velocity)
	end)

	it("exports Health fragment", function()
		assert.is_not_nil(Components.Health)
	end)

	it("fragment IDs are numbers", function()
		assert.is_number(Components.Position)
		assert.is_number(Components.Velocity)
		assert.is_number(Components.Health)
	end)

	it("all fragment IDs are unique", function()
		assert.are_not.equal(Components.Position, Components.Velocity)
		assert.are_not.equal(Components.Velocity, Components.Health)
		assert.are_not.equal(Components.Position, Components.Health)
	end)

	it("fragment IDs are positive integers", function()
		assert.is_true(Components.Position > 0)
		assert.is_true(Components.Velocity > 0)
		assert.is_true(Components.Health > 0)
	end)
end)
