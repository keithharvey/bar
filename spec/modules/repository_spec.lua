local Repository = require("modules/repository")

---@class SpecThing
---@field id string|nil
---@field name string
---@field colour string|nil

describe("a repository", function()
	local things = Repository.New() ---@type Repository<SpecThing>

	before_each(function()
		things = Repository.New()
	end)

	it("holds what it is given, in order, each under an id that counts up", function()
		local given = { name = "a" }
		local a = things.Put(given)
		local b = things.Put({ name = "b" })
		assert.is_true(rawequal(a, given), "the entity itself, not a copy")
		assert.are.equal("1", a.id)
		assert.are.equal("2", b.id)
		assert.are.same({ a, b }, things.All())
		assert.is_true(rawequal(a, things.Get("1")))
	end)

	it("keeps the id an entity brings, and never gives that id to another", function()
		local loaded = things.Put({ id = "2", name = "loaded" })
		assert.are.equal("2", loaded.id)
		assert.are.equal("3", things.Put({ name = "drawn" }).id)
		things.Remove("2")
		assert.are.equal("4", things.Put({ name = "later" }).id, "an id once seen is not given again")
	end)

	it("puts an entity where the one under its id stood", function()
		local a = things.Put({ name = "a" })
		local b = things.Put({ name = "b" })
		local renamed = things.Put({ id = a.id, name = "first" })
		assert.are.same({ renamed, b }, things.All())
		assert.is_true(rawequal(renamed, things.Get("1")))
	end)

	it("lists only what is asked for", function()
		local a = things.Put({ name = "a", colour = "red" })
		things.Put({ name = "b", colour = "blue" })
		local c = things.Put({ name = "c", colour = "red" })
		assert.are.same(
			{ a, c },
			things.All(function(thing)
				return thing.colour == "red"
			end)
		)
	end)

	it("removes by id, clears what is asked for, and counts every change", function()
		local before = things.Revision()
		local a = things.Put({ name = "a", colour = "red" })
		local b = things.Put({ name = "b", colour = "blue" })
		assert.is_true(rawequal(a, things.Remove("1")))
		assert.is_nil(things.Remove("1"))
		assert.are.same(
			{ b },
			things.Clear(function(thing)
				return thing.colour == "blue"
			end)
		)
		assert.are.same({}, things.All())
		assert.are.equal(before + 4, things.Revision())
	end)

	it("is assigned a set: exactly those, in the set's order", function()
		things.Put({ name = "gone" })
		local b, a = { name = "b" }, { id = "9", name = "a" }
		assert.are.same({ b, a }, things.Assign({ b, a }))
		assert.are.same({ b, a }, things.All())
		assert.is_nil(things.Get("1"))
		assert.is_true(rawequal(a, things.Get("9")))
	end)

	it("gives no new entity of a set an id that another of the set brings", function()
		local held = things.Assign({ { name = "drawn" }, { id = "1", name = "loaded" } })
		assert.are.equal("2", assert(held[1]).id)
		assert.are.equal("1", assert(held[2]).id)
	end)

	it("will not hold two entities under one id", function()
		assert.has_error(function()
			things.Assign({ { id = "1", name = "a" }, { id = "1", name = "b" } })
		end, "Repository: two entities under id 1")
	end)
end)
