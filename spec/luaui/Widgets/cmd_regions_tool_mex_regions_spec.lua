local Regions = require("modules/regions/api")
local Support = require("spec/luaui/Widgets/support/regions_tool")

describe("a mex region in the regions tool", function()
	local R = {} ---@type table
	local api = {} ---@type table

	before_each(function()
		Regions.Clear()
		R, api = Support.Tool()
		R.setType("mex_region")
	end)

	it("is a draft until it has its team and its group, and regions holds it once it does", function()
		local box = Support.Draw(R, Support.Square(0))
		assert.are.same({ "a mex region needs a team", "a mex region needs a group" }, R.validate().byRegion[box])
		assert.are.same({}, Regions.All())
		assert.is_true(api.setRegionField("team", "0"))
		assert.is_true(api.setRegionField("group", "anti"))
		assert.is_nil(R.validate().byRegion[box])
		local held = assert(Regions.All("mex_region")[1]) --[[@as table]]
		assert.are.equal("anti", held.group)
		assert.are.equal(held.id, box.id)
		api.setRegionField("group", "")
		assert.are.same({ "a mex region needs a group" }, R.validate().byRegion[box])
		assert.are.same({}, Regions.All())
	end)

	it("is checked against the map's starts only once a start is drawn", function()
		local box = Support.Draw(R, Support.Square(0))
		api.setRegionField("team", "3")
		api.setRegionField("group", "anti")
		assert.is_nil(R.validate().byRegion[box], "with no start drawn, the count is not the tool's to say")
		R.setType("start")
		Support.Draw(R, Support.Square(500))
		R.setType("mex_region")
		assert.are.same({ "bound to start 3; the map's starts are 0 to 0" }, R.validate().byRegion[box])
	end)
end)
