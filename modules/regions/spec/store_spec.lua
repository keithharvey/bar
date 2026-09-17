local Enums = require("modules/regions/enums")
local ModuleHandler = require("modules/module_handler")
local Regions = require("modules/regions/api")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

---@param team integer
---@param name string|nil
---@return Region
local function start(team, name)
	return { type = Enums.Types.Start, team = team, name = name, vertices = square }
end

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
		assert.are.same({}, Regions.All("nobody_knows"))
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
		assert.are.equal(0, #Regions.Clear("nobody_knows"))
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

	it("tags and untags, trimming and refusing duplicates", function()
		local a = Regions.Put(start(1))
		assert.is_true(Regions.Tag(a.id, "  north  "))
		assert.is_false(Regions.Tag(a.id, "north"))
		assert.is_false(Regions.Tag(a.id, "   "))
		assert.are.same({ "north" }, a.tags)
		assert.is_true(Regions.Untag(a.id, 1))
		assert.is_false(Regions.Untag(a.id, 1))
		assert.are.same({}, a.tags)
	end)

	it("answers the set check and the names over what it holds", function()
		Regions.Put(start(1))
		local b = Regions.Put(start(1, "twin"))
		b.vertices = { { x = 500, z = 500 }, { x = 600, z = 500 }, { x = 600, z = 600 } }
		local problems = Regions.Problems(Enums.Types.Start)
		assert.are.equal(2, #problems, "both carry team 1; apart, so no overlap")
		assert.is_true(rawequal(b, problems[2].region))
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
		"serializes the store as Lua that returns the layout, and reads it back with ids, fields, tags and curvature",
		function()
			local flat = Regions.Put(start(1, "north"))
			Regions.Tag(flat.id, "cold")
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
			assert.are.equal(flat.id, back[1].id)
			assert.are.equal("north", back[1].name)
			assert.are.same({ "cold" }, back[1].tags)
			assert.are.equal("polygon", back[1].kind)
			assert.are.same(square, back[1].vertices)
			assert.are.equal(curved.id, back[2].id)
			assert.are.equal("spline", back[2].kind)
			assert.are.equal(0.5, back[2].controls[1].strength)
			assert.is_true(#back[2].vertices > 4, "the outline is derived from the control ring")
		end
	)

	it("reads only the types the registry knows", function()
		local regions = Regions.ParseAllLayout({
			regions = {
				nobody_knows = { { id = "x", x = 1, y = 1 } },
				start = { { id = "s", team = 1, x = 1, y = 1 } },
			},
		}, 200, 200)
		assert.are.equal(1, #regions)
		assert.are.equal("point", regions[1].kind)
	end)
end)
