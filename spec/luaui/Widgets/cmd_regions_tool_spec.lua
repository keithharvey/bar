-- What is under test is the boundary: the tool keeps drafts, regions keeps what checks out, and what leaves the
-- tool is regions' copy.
local Regions = require("modules/regions/api")
local Support = require("spec/luaui/Widgets/support/regions_tool")

describe("the regions tool", function()
	local R = {} ---@type table
	local api = {} ---@type table

	before_each(function()
		Regions.Clear()
		R, api = Support.Tool()
		R.setType("start")
	end)

	it("keeps what is drawn as its own draft, and hands regions a copy under the id regions gave", function()
		local box = Support.Draw(R, Support.Square(0))
		assert.is_nil(box.id, "no identity until regions admits it")
		assert.are.same({}, Regions.All(), "and drawing alone offers regions nothing")
		assert.are.equal(1, #api.getState().regions)
		assert.is_nil(R.validate().byRegion[box])
		assert.are.equal(1, #Regions.All("start"))
		local held = assert(Regions.All("start")[1]) --[[@as table]]
		assert.is_false(rawequal(held, box))
		assert.are.equal(held.id, box.id)
		assert.are.equal(0, held.team)
		assert.is_nil(held._fillDirty)
		assert.is_nil(held.problems)
	end)

	it("edits its draft freely; regions' copy changes only when the draft is offered again", function()
		local box = Support.Draw(R, Support.Square(0))
		R.validate()
		box.vertices[1].x = 25
		assert.are.equal(0, assert(assert(Regions.Get(box.id)).vertices[1]).x)
		R.bump()
		R.validate()
		assert.are.equal(25, assert(assert(Regions.Get(box.id)).vertices[1]).x)
		assert.are.equal(1, #Regions.All(), "the same region, under the same id")
	end)

	it("holds a draft that does not check out, says why, and keeps it from regions", function()
		local first = Support.Draw(R, Support.Square(0))
		local second = Support.Draw(R, Support.Square(500))
		R.validate()
		assert.are.equal(2, #Regions.All())
		second.team = first.team
		R.bump()
		assert.are.same({ "a start with team 0 already exists" }, R.validate().byRegion[second])
		assert.are.equal(1, #Regions.All())
		assert.are.equal(2, #api.getState().regions, "the draft is still the tool's to fix")
		second.team = 1
		R.bump()
		assert.is_nil(R.validate().byRegion[second])
		assert.are.equal(2, #Regions.All())
	end)

	it("takes a region back out of regions when its draft is removed", function()
		Support.Draw(R, Support.Square(0))
		R.validate()
		assert.are.equal(1, #Regions.All())
		api.removeRegion(1)
		R.validate()
		assert.are.same({}, Regions.All())
		assert.are.same({}, api.getState().regions)
	end)

	it("keeps a start that is only its positions as a point, and regions holds it as one", function()
		assert.is_true(api.addPosition(300, 400, 0, 1))
		assert.is_true(api.addPosition(350, 400, 0, 2))
		assert.are.same({}, R.validate().lines)
		assert.are.equal(1, #Regions.All("start"))
		local held = assert(Regions.All("start")[1]) --[[@as table]]
		assert.are.equal(0, held.team)
		assert.are.same({ { x = 300, z = 400 } }, held.vertices)
		assert.are.same({ { x = 300, z = 400 }, { x = 350, z = 400 } }, held.positions)
		api.clearAllPositions()
		R.validate()
		assert.are.same({}, Regions.All("start"))
	end)

	it("exports and saves regions' copy, and loads a file back as drafts regions already knows", function()
		local path = os.tmpname()
		local first = Support.Draw(R, Support.Square(0))
		local second = Support.Draw(R, Support.Square(500))
		second.team = first.team
		R.bump()
		assert.are.equal(1, #api.exportLayout().regions.start, "a draft that does not check out is not in the layout")
		assert.is_true(api.saveRegions(path))
		local saved = assert(assert(io.open(path, "r")):read("*a")) --[[@as string]]
		assert.matches("team = 0", saved)
		assert.is_nil(saved:find("x = 50,", 1, true), "nor in the file")

		local id = first.id
		api.removeRegion(2)
		api.removeRegion(1)
		assert.is_true(api.loadRegions(path))
		os.remove(path)
		local loaded = api.getState().regions
		assert.are.equal(1, #loaded)
		assert.are.equal(id, loaded[1].id)
		assert.is_false(rawequal(loaded[1], Regions.Get(id)), "the tool's draft is its own table")
		assert.are.same({}, R.validate().lines)
	end)
end)
