local ModuleHandler = require("modules/module_handler")
local Regions = require("modules/regions/api")

---@return { x: number, z: number }[]
local function square()
	return { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }
end

---@param team integer|nil
---@param name string|nil
---@param at number|nil where its corner sits, on both axes
---@return table what an editor would offer: a start's data, and no identity yet
local function start(team, name, at)
	at = at or 0
	return {
		type = Regions.Enums.Types.Start,
		team = team,
		name = name,
		vertices = {
			{ x = at, z = at },
			{ x = at + 100, z = at },
			{ x = at + 100, z = at + 100 },
			{ x = at, z = at + 100 },
		},
	}
end

describe("a region that is not the repository's", function()
	it("is given its type by Create, under the id its maker gave it", function()
		local a = Regions.Create(Regions.Enums.Types.Start, { id = "start@0", team = 0 })
		assert.are.equal("start", a.type)
		assert.are.equal("start@0", a.id)
		assert.are.same({}, a.vertices)
		assert.has_error(function()
			Regions.Create(Regions.Enums.Types.Start, { team = 1 })
		end, "Regions.Create: a region has an id")
	end)
end)

describe("the region repository", function()
	before_each(function()
		Regions.Clear()
	end)

	it("holds its own copy of what is offered, in the order it came, under an id it gives", function()
		local offered = start(1)
		local a = assert(Regions.Put(offered))
		local b = assert(Regions.Put(start(2, nil, 500)))
		assert.is_false(rawequal(a, offered))
		assert.is_nil(offered.id, "what was offered is left as it was")
		offered.vertices[1].x = 50
		assert.are.same(square(), a.vertices, "and a later change to it does not reach the region")
		assert.is_string(a.id)
		assert.are_not.equal(a.id, b.id)
		assert.are.same({ a, b }, Regions.All())
		assert.are.same({ a, b }, Regions.All(Regions.Enums.Types.Start))
		assert.are.same({}, Regions.All("nobody_knows"))
		assert.is_true(rawequal(a, Regions.Get(a.id)))
	end)

	it("keeps only what its type declares, and the shape", function()
		local offered = start(1, "north")
		offered._fillList = 7
		offered.stray = "dropped"
		local a = assert(Regions.Put(offered))
		assert.are.equal("north", a.name)
		assert.is_nil(a._fillList)
		assert.is_nil(a.stray)
	end)

	it("admits only what checks out, and says what is wrong with the rest", function()
		assert(Regions.Put(start(1)))
		local before = Regions.Revision()
		local twin, problems = Regions.Put(start(1, "twin", 500))
		assert.is_nil(twin)
		assert.are.same({ "a start with team 1 already exists" }, problems)
		assert.are.same({ "a start needs a team" }, select(2, Regions.Put(start(nil))))
		assert.are.same({ "unknown region type nobody_knows" }, select(2, Regions.Put({ type = "nobody_knows" })))
		assert.are.equal(1, #Regions.All())
		assert.are.equal(before, Regions.Revision())
	end)

	it("replaces a region whole under its id, or leaves it as it was", function()
		local a = assert(Regions.Put(start(1)))
		local named = start(1, "north")
		named.id = a.id
		assert.are.equal("north", assert(Regions.Put(named)).name)
		local broken = start(nil, "south")
		broken.id = a.id
		assert.is_nil((Regions.Put(broken)))
		assert.are.equal("north", assert(Regions.Get(a.id)).name)
		assert.are.equal(1, assert(Regions.Get(a.id)).team)
	end)

	it("is assigned a set whole, each region checked against the set it came with", function()
		local a = assert(Regions.Put(start(1)))
		local b = assert(Regions.Put(start(2, nil, 500)))
		local first, second, nobody = start(2), start(1, nil, 500), start(nil, nil, 900)
		first.id, second.id = a.id, b.id
		local admitted, refused = Regions.Assign({ first, second, nobody })
		assert.are.equal(2, #admitted)
		assert.are.equal(2, assert(Regions.Get(a.id)).team, "two starts may swap teams in one step")
		assert.are.equal(1, #refused)
		local refusal = assert(refused[1])
		assert.is_true(rawequal(nobody, refusal.candidate))
		assert.are.same({ "a start needs a team" }, refusal.problems)
	end)

	it("refuses the second of two offered under one id", function()
		local first, second = start(1), start(2, nil, 500)
		first.id, second.id = "north", "north"
		local admitted, refused = Regions.Assign({ first, second })
		assert.are.equal(1, #admitted)
		assert.are.same({ "another with id north was offered first" }, assert(refused[1]).problems)
	end)

	it("removes by id, clears by type, and bumps its revision on every change", function()
		local before = Regions.Revision()
		local a = assert(Regions.Put(start(1)))
		assert(Regions.Put(start(2, nil, 500)))
		assert.is_true(rawequal(a, Regions.Remove(a.id)))
		assert.is_nil(Regions.Remove(a.id))
		assert.are.equal(1, #Regions.All())
		assert.are.equal(0, #Regions.Clear("nobody_knows"))
		assert.are.equal(1, #Regions.Clear(Regions.Enums.Types.Start))
		assert.are.same({}, Regions.All())
		assert.is_true(Regions.Revision() > before)
	end)

	it("answers the set check and the names over what it holds", function()
		assert(Regions.Put(start(1)))
		local b = assert(Regions.Put(start(2, "twin", 50)))
		local problems = Regions.Problems(Regions.Enums.Types.Start)
		assert.are.equal(2, #problems, "each is valid alone; as a set, the two share ground")
		assert.is_true(rawequal(b, assert(problems[2]).region))
		local names = Regions.NamesById(Regions.Enums.Types.Start)
		assert.are.equal("twin", names[b.id])
		assert.are.same({}, Regions.Suggestions(Regions.Enums.Types.Start), "no start field offers suggestions")
	end)

	it("is one per Lua state, shared by every include of the api", function()
		local a = assert(Regions.Put(start(1)))
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
		"serializes what it holds as Lua that returns the layout, and reads it back with ids, fields and curvature",
		function()
			local flat = assert(Regions.Put(start(1, "north")))
			local curved = assert(Regions.Put({
				type = Regions.Enums.Types.Start,
				team = 2,
				kind = "spline",
				controls = {
					{ x = 500, z = 500, strength = 0.5 },
					{ x = 900, z = 500 },
					{ x = 900, z = 900 },
					{ x = 500, z = 900 },
				},
				vertices = {},
			}))
			local source = Regions.SerializeLayout(Regions.All(), 1000, 1000, "Map: Some Map")
			assert.matches("Map: Some Map", source)
			local layout = assert(loadstring(source))()
			local back = Regions.ParseAllLayout(layout, 1000, 1000)
			assert.are.equal(2, #back)
			local first, second = assert(back[1]), assert(back[2])
			assert.are.equal(flat.id, first.id)
			assert.are.equal("north", first.name)
			assert.are.equal("polygon", first.kind)
			assert.are.same(square(), first.vertices)
			assert.are.equal(curved.id, second.id)
			assert.are.equal("spline", second.kind)
			assert.are.equal(0.5, assert(assert(second.controls)[1]).strength)
			assert.is_true(#assert(second.vertices) > 4, "the outline is derived from the control ring")
		end
	)

	it("carries a points field normalised like the anchors, and reads it back in elmos", function()
		local offered = start(1)
		offered.positions = { { x = 250, z = 500 }, { x = 1000, z = 0 } }
		assert(Regions.Put(offered))
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
