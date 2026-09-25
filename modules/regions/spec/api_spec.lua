local Enums = require("modules/regions/enums")
local ModuleHandler = require("modules/module_handler")
local Regions = require("modules/regions/api")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

---@param team integer
---@param name string|nil
---@return StartRegion
local function start(team, name)
	return { type = Enums.Types.Start, team = team, name = name, vertices = square }
end

describe("a new region", function()
	it("is given its type and an id by Create, and keeps an id it already has", function()
		local a = Regions.Create(Enums.Types.Start, { team = 1 })
		local b = Regions.Create(Enums.Types.Start, { team = 2 })
		assert.are.equal("start", a.type)
		assert.is_string(a.id)
		assert.are_not.equal(a.id, b.id)
		assert.are.equal("kept", Regions.Create(Enums.Types.Start, { id = "kept" }).id)
	end)
end)

describe("the region store", function()
	before_each(function()
		Regions.Clear()
	end)

	it("keeps regions in the order they were put, keyed by id, and gives an id to one that has none", function()
		local a = Regions.Put(start(1))
		local b = Regions.Put(start(2))
		assert.is_string(a.id)
		assert.are_not.equal(a.id, b.id)
		assert.are.same({ a, b }, Regions.All())
		assert.are.same({ a, b }, Regions.All(Enums.Types.Start))
		assert.are.same({}, Regions.All("nobody_knows" --[[@as RegionTypeKey]]))
		assert.is_true(rawequal(a, Regions.Get(a.id)))
	end)

	it("puts ahead of another region on request, and keeps a region already stored where it is", function()
		local a = Regions.Put(start(1))
		local b = Regions.Put(start(2))
		local c = Regions.Put(start(3), b.id)
		assert.are.same({ a, c, b }, Regions.All())
		Regions.Put(c)
		assert.are.same({ a, c, b }, Regions.All(), "a second Put of the same table moves nothing")
	end)

	it("removes by id, clears by type, and bumps its revision on every change", function()
		local before = Regions.Revision()
		local a = Regions.Put(start(1))
		Regions.Put(start(2))
		assert.is_true(rawequal(a, Regions.Remove(a.id)))
		assert.is_nil(Regions.Remove(a.id))
		assert.are.equal(1, #Regions.All())
		assert.are.equal(0, #Regions.Clear("nobody_knows" --[[@as RegionTypeKey]]))
		assert.are.equal(1, #Regions.Clear(Enums.Types.Start))
		assert.are.same({}, Regions.All())
		assert.is_true(Regions.Revision() > before)
	end)

	it("edits a declared field through the type's definition, refusing a non-number for an integer field", function()
		local a = Regions.Put(start(1))
		assert.is_true(Regions.Set(a.id, "name", "north"))
		assert.are.equal("north", a.name)
		assert.is_true(Regions.Set(a.id, "name", ""))
		assert.is_nil(a.name, "an empty value clears the field")
		assert.is_true(Regions.Set(a.id, "team", "3"))
		assert.are.equal(3, a.team, "a numeric string is coerced")
		local ok, reason = Regions.Set(a.id, "team", "x")
		assert.is_false(ok)
		assert.are.equal("Team must be a number", reason)
		assert.are.equal(3, a.team)
		assert.is_false((Regions.Set(a.id, "colour", "red")), "an undeclared field is refused")
		assert.is_false((Regions.Set("nobody", "name", "x")))
	end)

	it("answers the set check and the names over what it holds", function()
		Regions.Put(start(1))
		local b = Regions.Put(start(1, "twin"))
		b.vertices = { { x = 500, z = 500 }, { x = 600, z = 500 }, { x = 600, z = 600 } }
		local problems = Regions.Problems(Enums.Types.Start)
		assert.are.equal(2, #problems, "both carry team 1; apart, so no overlap")
		assert.is_true(rawequal(b, assert(problems[2]).region))
		local names = Regions.NamesById(Enums.Types.Start)
		assert.are.equal("twin", names[b.id])
		assert.are.same({}, Regions.Suggestions(Enums.Types.Start), "no start field offers suggestions")
	end)

	it("is one per Lua state, shared by every include of the api", function()
		local a = Regions.Put(start(1))
		local Again = require("modules/regions/api")
		assert.is_true(rawequal(a, Again.Get(a.id)))
		ModuleHandler.ResetCaches()
	end)
end)

describe("the layout as a file", function()
	before_each(function()
		Regions.Clear()
	end)

	it(
		"serializes the store as Lua that returns the layout, and reads it back with ids, fields and curvature",
		function()
			local flat = Regions.Put(start(1, "north"))
			local curved = Regions.Put({
				type = Enums.Types.Start,
				team = 2,
				kind = "spline",
				controls = {
					{ x = 500, z = 500, strength = 0.5 },
					{ x = 900, z = 500 },
					{ x = 900, z = 900 },
					{ x = 500, z = 900 },
				},
				vertices = {},
			})
			local source = Regions.SerializeLayout(Regions.All(), 1000, 1000, "Map: Some Map")
			assert.matches("Map: Some Map", source)
			local layout = assert(loadstring(source))()
			local back = Regions.ParseAllLayout(layout, 1000, 1000)
			assert.are.equal(2, #back)
			local first, second = assert(back[1]), assert(back[2])
			assert.are.equal(flat.id, first.id)
			assert.are.equal("north", first.name)
			assert.are.equal("polygon", first.kind)
			assert.are.same(square, first.vertices)
			assert.are.equal(curved.id, second.id)
			assert.are.equal("spline", second.kind)
			assert.are.equal(0.5, assert(assert(second.controls)[1]).strength)
			assert.is_true(#assert(second.vertices) > 4, "the outline is derived from the control ring")
		end
	)

	it("carries a points field normalised like the anchors, and reads it back in elmos", function()
		local one = Regions.Put(start(1))
		one.positions = { { x = 250, z = 500 }, { x = 1000, z = 0 } }
		local source = Regions.SerializeLayout(Regions.All(), 1000, 1000)
		assert.matches("positions = { { x = 50, y = 100 }, { x = 200, y = 0 } }", source)
		local back = Regions.ParseAllLayout(assert(loadstring(source))(), 1000, 1000)
		assert.are.same({ { x = 250, z = 500 }, { x = 1000, z = 0 } }, assert(back[1]).positions)
	end)

	it("reads only the types the registry knows", function()
		local regions = Regions.ParseAllLayout({
			regions = {
				nobody_knows = { { id = "x", x = 1, y = 1 } },
				start = { { id = "s", team = 1, x = 1, y = 1 } },
			},
		}, 200, 200)
		assert.are.equal(1, #regions)
		assert.are.equal("point", assert(regions[1]).kind)
	end)
end)
