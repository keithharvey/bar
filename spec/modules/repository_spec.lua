local Repository = require("modules/repository")

---@class SpecThing
---@field id string
---@field name string
---@field colour string|nil

---@return Repository<SpecThing>
local function strict()
	return Repository.New(function(candidate, _, held)
		if type(candidate.name) ~= "string" or candidate.name == "" then
			return nil, { "a thing needs a name" }
		end
		for _, other in ipairs(held) do
			if other.name == candidate.name then
				return nil, { "a thing named " .. candidate.name .. " already exists" }
			end
		end
		return { name = candidate.name, colour = candidate.colour }
	end)
end

describe("a repository", function()
	it("holds what it is given, in order, each under an id that counts up", function()
		local things = Repository.New()
		local a = assert(things.Put({ name = "a" }))
		local b = assert(things.Put({ name = "b" }))
		assert.are.equal("1", a.id)
		assert.are.equal("2", b.id)
		assert.are.same({ a, b }, things.All())
		assert.is_true(rawequal(a, things.Get("1")))
	end)

	it("keeps the id an entity brings, and never gives that id to another", function()
		local things = strict()
		local loaded = assert(things.Put({ id = "2", name = "loaded" }))
		assert.are.equal("2", loaded.id)
		assert.are.equal("3", assert(things.Put({ name = "drawn" })).id)
		things.Remove("2")
		assert.are.equal("4", assert(things.Put({ name = "later" })).id, "an id once seen is not given again")
	end)

	it("puts ahead of another on request, and lists only what is asked for", function()
		local things = Repository.New()
		local a = assert(things.Put({ name = "a", colour = "red" }))
		local b = assert(things.Put({ name = "b", colour = "blue" }))
		local c = assert(things.Put({ name = "c", colour = "red" }, b.id))
		assert.are.same({ a, c, b }, things.All())
		assert.are.same(
			{ a, c },
			things.All(function(thing)
				return thing.colour == "red"
			end)
		)
	end)

	it("removes by id, clears what is asked for, and counts every change", function()
		local things = Repository.New()
		local before = things.Revision()
		local a = assert(things.Put({ name = "a", colour = "red" }))
		local b = assert(things.Put({ name = "b", colour = "blue" }))
		assert.is_true(rawequal(a, things.Remove(a.id)))
		assert.is_nil(things.Remove(a.id))
		assert.are.same(
			{ b },
			things.Clear(function(thing)
				return thing.colour == "blue"
			end)
		)
		assert.are.same({}, things.All())
		assert.are.equal(before + 4, things.Revision())
	end)
end)

describe("a repository that admits", function()
	it("stores what the candidate becomes, not the candidate", function()
		local things = strict()
		local candidate = { name = "a", scratch = true }
		local a = assert(things.Put(candidate))
		assert.is_false(rawequal(a, candidate))
		assert.is_nil(a.scratch)
		assert.is_nil(candidate.id, "the candidate is left as it was")
	end)

	it("refuses a candidate with what is wrong with it, and changes nothing", function()
		local things = strict()
		assert(things.Put({ name = "a" }))
		local before = things.Revision()
		local entity, problems = things.Put({ name = "" })
		assert.is_nil(entity)
		assert.are.same({ "a thing needs a name" }, problems)
		assert.are.same({ "a thing named a already exists" }, select(2, things.Put({ name = "a" })))
		assert.are.equal(1, #things.All())
		assert.are.equal(before, things.Revision())
		assert.are.equal("2", assert(things.Put({ name = "b" })).id, "a refusal spends no id")
	end)

	it("replaces an entity whole, where it stood, or leaves it as it was", function()
		local things = strict()
		local a = assert(things.Put({ name = "a" }))
		local b = assert(things.Put({ name = "b" }))
		local renamed = assert(things.Put({ id = a.id, name = "first" }), "it is not its own sibling")
		assert.are.same({ renamed, b }, things.All())
		assert.is_nil((things.Put({ id = a.id, name = "b" })))
		assert.are.equal("first", things.Get(a.id).name)
	end)
end)

describe("a repository assigned a set", function()
	it("holds what of the set is admissible, in the set's order, and says what was refused", function()
		local things = strict()
		assert(things.Put({ name = "gone" }))
		local nameless = { name = "" }
		local admitted, refused = things.Assign({ { name = "b" }, nameless, { id = "9", name = "a" } })
		assert.are.same({ "b", "a" }, { admitted[1].name, admitted[2].name })
		assert.are.same(admitted, things.All())
		assert.are.same({ { candidate = nameless, problems = { "a thing needs a name" } } }, refused)
	end)

	it("checks each against the set it arrives with, not against what was held", function()
		local things = strict()
		local a = assert(things.Put({ name = "a" }))
		local b = assert(things.Put({ name = "b" }))
		local admitted, refused = things.Assign({ { id = a.id, name = "b" }, { id = b.id, name = "a" } })
		assert.are.equal(2, #admitted)
		assert.are.same({}, refused)
		assert.are.equal("b", things.Get(a.id).name)
	end)

	it("gives no new entity an id that another of the set brings", function()
		local things = strict()
		local admitted = things.Assign({ { name = "drawn" }, { id = "1", name = "loaded" } })
		assert.are.equal("2", admitted[1].id)
		assert.are.equal("1", admitted[2].id)
	end)
end)
