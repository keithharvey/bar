local ModuleHandler = require("modules/module_handler")
local Policy = require("modules/policy")

---@class SpecCtx
---@field submerged boolean|nil
---@field far boolean|nil
---@field tank boolean|nil
---@field scripted string|nil
---@field reachable boolean|nil

---@class SpecProductCtx
---@field carriesCommander boolean|nil
---@field inMud boolean|nil

local function owner()
	---@type AssembledPolicy<SpecCtx, boolean|string|table>
	local steps = { result = "single" }
	Policy.Assemble(
		steps,
		Policy.Chain()
			.Unless("Submerged", function(ctx)
				return ctx.submerged
			end)
			.Unless("OutOfReach", function(ctx)
				return ctx.far
			end)
			.Answer("Allowed", function()
				return true
			end)
			.Build(),
		"owner"
	)
	return steps
end

local function names(steps)
	local out = {}
	for i, step in ipairs(steps) do
		out[i] = step.name
	end
	return out
end

local run = ModuleHandler.Evaluate

describe("a policy's identity", function()
	it("carries an inline policy when the contract has one, and including it runs nothing", function()
		local ran = 0
		local Contract = Policy.Contract("transport", {
			Load = Policy.Single({ Submerged = "Submerged" }),
		}, function(Policies)
			ran = ran + 1
		end)
		assert.is_function(Policy.InlinePolicies(Contract))
		assert.are.equal(0, ran)
		assert.is_nil(Policy.InlinePolicies(Policy.Contract("transport", {})))
		assert.has_error(function()
			Policy.Contract("transport", {}, "not a function")
		end)
	end)

	it("names the module a contract belongs to", function()
		local Contract = Policy.Contract("transport", {
			Load = Policy.Single({ Submerged = "Submerged" }),
		})
		assert.are.equal("transport", Policy.OwnerOf(Contract))
		assert.is_nil(Policy.OwnerOf({}))
		assert.is_nil(Policy.OwnerOf("transport"))
	end)

	it("carries owner, category and the declared result", function()
		local Contract = Policy.Contract("transport", {
			Load = Policy.Single({ Submerged = "Submerged" }),
			LoadedSpeed = Policy.Product({ CommanderDrag = "CommanderDrag" }),
		})
		assert.are.same({ owner = "transport", category = "load", result = "single" }, Policy.IdentityOf(Contract.Load))
		assert.are.same(
			{ owner = "transport", category = "loaded_speed", result = "product" },
			Policy.IdentityOf(Contract.LoadedSpeed)
		)
		assert.is_nil(Policy.IdentityOf({}))
		assert.are.equal(Contract.Load, Policy.Chain(Contract.Load).steps)
	end)

	it("requires every category to declare itself", function()
		assert.has_error(
			function()
				Policy.Contract("transport", { Load = { Submerged = "Submerged" } })
			end,
			"Policy.Contract: Load must declare itself: Single(...), Product(...), Fold(...), Contributes(...) or Facts(...)"
		)
	end)

	it("serializes a declaration's name to the key the runtime uses", function()
		assert.are.equal("unit_terms_notes", Policy.KeyOf("UnitTermsNotes"))
		assert.are.equal("take", Policy.KeyOf("Take"))
	end)
end)

describe("one chain for owners and contributors", function()
	it("a bare step joins the end of the checks, never past the terminal", function()
		local steps = owner()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Unless("NoTanks", function(ctx)
					return ctx.tank
				end)
				.Build(),
			"mod"
		)
		assert.are.same({ "Submerged", "OutOfReach", "NoTanks", "Allowed" }, names(steps))
		assert.is_false(run(steps, { tank = true }))
		assert.is_true(run(steps, {}))
	end)

	it("places a step after or before a named step", function()
		local steps = owner()
		local ops = Policy.Chain()
			.Unless("A", function() end)
			.After("Submerged")
			.Unless("B", function() end)
			.Before("Allowed")
			.Build()
		Policy.Assemble(steps, ops, "mod")
		assert.are.same({ "Submerged", "A", "OutOfReach", "B", "Allowed" }, names(steps))
	end)

	it("replaces a step in place, keeping its kind, the terminal included", function()
		local steps = owner()
		local ops = Policy.Chain()
			.Replace("OutOfReach", function() end)
			.Replace("Allowed", function()
				return "maybe"
			end)
			.Build()
		Policy.Assemble(steps, ops, "mod")
		assert.are.same({ "Submerged", "OutOfReach", "Allowed" }, names(steps))
		assert.are.equal("answer", steps[3].kind)
		assert.are.equal("maybe", run(steps, { far = true }))
	end)

	it("removes a step", function()
		local steps = owner()
		Policy.Assemble(steps, Policy.Chain().Remove("Submerged").Build(), "mod")
		assert.are.same({ "OutOfReach", "Allowed" }, names(steps))
		assert.is_true(run(steps, { submerged = true }))
	end)

	it("names are the contract: unknown or colliding names are load errors naming the file", function()
		assert.has_error(function()
			Policy.Assemble(owner(), Policy.Chain().Replace("Ghost", function() end).Build(), "mod.lua")
		end, "mod.lua: no step named Ghost to replace")
		assert.has_error(function()
			Policy.Assemble(owner(), Policy.Chain().Unless("Submerged", function() end).Build(), "mod.lua")
		end, "mod.lua: the policy already has a step named Submerged")
		assert.has_error(function()
			Policy.Chain().After("Submerged")
		end)
	end)
end)

describe("one chain for owners and contributors", function()
	it("If is the inclusive guard: it refuses when its condition does not hold", function()
		---@type AssembledPolicy<SpecCtx, boolean>
		local steps = { result = "single" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.If("WithinReach", function(ctx)
					return ctx.reachable
				end)
				.Answer("Allowed", function()
					return true
				end)
				.Build(),
			"owner"
		)
		assert.is_false(run(steps, {}))
		assert.is_true(run(steps, { reachable = true }))
	end)
end)

describe("facts", function()
	it("carries identity, and provisions are named or refused", function()
		local Contract = Policy.Contract("transfer", {
			TeamPairing = Policy.Facts({ TechBlocking = "techBlocking" }),
		})
		assert.are.same(
			{ owner = "transfer", category = "team_pairing", facts = true },
			Policy.IdentityOf(Contract.TeamPairing)
		)
		local ops = Policy.Enrichment(Contract.TeamPairing)
			.Provide(Contract.TeamPairing.TechBlocking, function(ctx)
				return { level = 2 }
			end)
			.Build()
		assert.are.same({ "techBlocking" }, ops[1].names)
	end)

	it("a provider may add a fact the contract did not declare, and never removes one", function()
		local Contract = Policy.Contract("transfer", {
			TeamPairing = Policy.Facts({ TaxRate = "taxRate" }),
		})
		local ops = Policy.Enrichment(Contract.TeamPairing)
			.Provide("stunSeconds", function()
				return 30
			end)
			.Build()
		assert.are.same({ "stunSeconds" }, ops[1].names)
		assert.are.equal("taxRate", Contract.TeamPairing.TaxRate)
	end)

	it("one producer can fill several provisions, in order", function()
		local ops = Policy.Enrichment()
			.Provide("a", "b", function()
				return 1, 2
			end)
			.Build()
		assert.are.same({ "a", "b" }, ops[1].names)
		assert.has_error(function()
			Policy.Enrichment().Provide("a")
		end)
	end)
end)

describe("module state", function()
	it("is one table per module across include instances", function()
		local A = require("modules/module_handler")
		local B = require("modules/module_handler")
		A.State("probe").count = 3
		assert.are.equal(3, B.State("probe").count)
		assert.are_not.equal(A.State("probe"), A.State("other"))
	end)
end)

describe("the refusal", function()
	it("is what every Answer declining becomes: nothing said yes is a no", function()
		local steps = { result = "single" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Stunned", function(ctx)
					if ctx.stunned then
						return true
					end
				end)
				.Build(),
			"owner"
		)
		assert.is_true(run(steps, { stunned = true }))
		assert.is_false(run(steps, {}))
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Refusal(function()
					return { allowed = false, reason = "nobody said yes" }
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ allowed = false, reason = "nobody said yes" }, run(steps, {}))
	end)

	it("a Product with no factor is a broken owner, and says so", function()
		local steps = { result = "product" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Factor("Base", function(ctx)
					return ctx.speed
				end)
				.Build(),
			"owner"
		)
		assert.are.equal(3, run(steps, { speed = 3 }))
		assert.has_error(function()
			run(steps, {})
		end)
	end)

	it("is false unless the policy declares its shape", function()
		local steps = owner()
		assert.is_false(run(steps, { submerged = true }))
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Refusal(function(ctx)
					return { allowed = false, deep = ctx.submerged }
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ allowed = false, deep = true }, run(steps, { submerged = true }))
		assert.is_true(run(steps, {}))
	end)

	it("is declared once", function()
		local steps = owner()
		local shape = Policy.Chain()
			.Refusal(function()
				return false
			end)
			.Build()
		Policy.Assemble(steps, shape, "owner")
		assert.has_error(function()
			Policy.Assemble(steps, shape, "mod.lua")
		end, "mod.lua: the policy already has a Refusal")
	end)
end)

describe("the declared result", function()
	it("single: ends with an Answer", function()
		Policy.Validate(owner(), "single", "transport.load")
		assert.has_error(function()
			local steps = owner()
			Policy.Assemble(steps, Policy.Chain().Remove("Allowed").Build(), "mod")
			Policy.Validate(steps, "single", "transport.load")
		end, "transport.load: a single-result policy ends with an Answer; OutOfReach is a guard")
		assert.has_error(function()
			local steps = owner()
			Policy.Assemble(steps, Policy.Chain().Unless("Late", function() end).After("Allowed").Build(), "mod")
			Policy.Validate(steps, "single", "transport.load")
		end, "transport.load: a single-result policy ends with an Answer; Late is a guard")
	end)

	it("single: an early Answer preempts — answering when it can, passing when it cannot", function()
		local steps = owner()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Scripted", function(ctx)
					return ctx.scripted
				end)
				.Before("Submerged")
				.Build(),
			"mod"
		)
		Policy.Validate(steps, "single", "transport.load")
		assert.are.equal("override", run(steps, { scripted = "override", submerged = true }))
		assert.is_false(run(steps, { submerged = true }))
		assert.is_true(run(steps, {}))
	end)

	it("product: factors from every module multiply into one answer", function()
		---@type AssembledPolicy<SpecProductCtx, number>
		local policy = { result = "product" }
		Policy.Assemble(
			policy,
			Policy.Chain()
				.Factor("CommanderDrag", function(ctx)
					return ctx.carriesCommander and 0.5 or nil
				end)
				.Factor("MudCrawl", function(ctx)
					return ctx.inMud and 0.25 or nil
				end)
				.Build(),
			"owner"
		)
		assert.are.equal(0.125, run(policy, { carriesCommander = true, inMud = true }))
		assert.are.equal(0.25, run(policy, { inMud = true }))
		assert.has_error(function()
			run(policy, {})
		end)
	end)

	it("product: every step is a Factor", function()
		local steps = {}
		Policy.Assemble(steps, Policy.Chain().Factor("CommanderDrag", function() end).Build(), "owner")
		Policy.Validate(steps, "product", "transport.loaded_speed")
		assert.has_error(function()
			Policy.Assemble(steps, Policy.Chain().Unless("NoMud", function() end).Build(), "mod")
			Policy.Validate(steps, "product", "transport.loaded_speed")
		end, "transport.loaded_speed: a product policy multiplies Factor results; NoMud is a guard")
	end)
end)

describe("the fold result", function()
	local function fold(ops, origin)
		---@type AssembledPolicy<table, table>
		local steps = { result = "fold" }
		Policy.Assemble(steps, ops, origin)
		return steps
	end

	it("hands one context through every Apply, owner's first, and returns it", function()
		local steps = fold(
			Policy.Chain()
				.Apply("Base", function(ctx)
					ctx.def.mass = (ctx.def.mass or 0) + 1
				end)
				.Build(),
			"owner"
		)
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Apply("Heavier", function(ctx)
					ctx.def.mass = ctx.def.mass * 10
				end)
				.Build(),
			"mod"
		)
		local ctx = { def = {} }
		assert.are.equal(ctx, ModuleHandler.Evaluate(steps, ctx))
		assert.are.equal(10, ctx.def.mass)
		assert.are.same({ "Base", "Heavier" }, names(steps))
	end)

	it("every step is an Apply: a fold has nothing to refuse", function()
		local steps = fold(
			Policy.Chain()
				.Unless("Never", function()
					return false
				end)
				.Build(),
			"owner"
		)
		assert.has_error(function()
			Policy.Validate(steps, "fold", "defs.unit_def")
		end, "defs.unit_def: a fold policy runs every Apply over the context; Never is a guard")
	end)
end)

describe("a declared contribution", function()
	local function target()
		return Policy.Contract("transport", {
			Load = Policy.Single({ Submerged = "Submerged", Allowed = "Allowed" }),
			Facts = Policy.Facts({ Reach = "reach" }),
		})
	end

	it("carries the target's identity and the contributor's own", function()
		local Contract = target()
		local mod = Policy.Contract("mod", {
			Load = Policy.Contributes(Contract.Load, { NoTanks = "NoTanks" }),
		})
		assert.are.same(
			{ owner = "mod", category = "load", contributes = Policy.IdentityOf(Contract.Load) },
			Policy.IdentityOf(mod.Load)
		)
		assert.are.equal("NoTanks", mod.Load.NoTanks)
	end)

	it("targets a policy, never a context", function()
		local Contract = target()
		assert.has_error(function()
			Policy.Contributes({}, { A = "A" })
		end, "Policy.Contributes(target, names): target must be a policy's steps")
		assert.has_error(function()
			Policy.Contributes(Contract.Facts, { A = "A" })
		end, "Policy.Contributes(target, names): target must be a policy's steps")
	end)

	it("is the only way to add a step: a name no contract declares is refused", function()
		local ops = Policy.Chain()
			.Unless("NoTanks", function()
				return true
			end)
			.Build()
		assert.is_nil(ModuleHandler.UndeclaredStep(ops, { NoTanks = true }))
		assert.are.equal("NoTanks", ModuleHandler.UndeclaredStep(ops, {}))
	end)

	it("holds the owner and a contributor to their contracts alike: a declared name must land", function()
		local landed = { Submerged = true, Allowed = true }
		assert.is_nil(ModuleHandler.UnbuiltStage({ Submerged = "Submerged", Allowed = "Allowed" }, landed))
		assert.are.equal(
			"WithinReach",
			ModuleHandler.UnbuiltStage({ Submerged = "Submerged", WithinReach = "WithinReach" }, landed)
		)
		assert.are.equal("NoTanks", ModuleHandler.UnbuiltStage({ "NoTanks" }, landed))
	end)

	it("moving, replacing or removing a step needs no declaration: the name already exists", function()
		local ops = Policy.Chain()
			.Replace("Submerged", function()
				return false
			end)
			.Remove("Allowed")
			.Build()
		assert.is_nil(ModuleHandler.UndeclaredStep(ops, {}))
	end)
end)

describe("a contract's facts", function()
	local function enrichment(module, ops)
		return { module = module, ops = ops, file = module .. "/policies/x.lua" }
	end
	local function defaults(...)
		local chain = Policy.Enrichment()
		for _, name in ipairs({ ... }) do
			chain.Default(name, function()
				return "default:" .. name
			end)
		end
		return chain.Build()
	end
	local function provides(name, value)
		return Policy.Enrichment()
			.Provide(name, function()
				return value
			end)
			.Build()
	end

	it("must every one be given a Default by the owner, so a slot is a promise", function()
		assert.has_error(
			function()
				ModuleHandler.ResolveProvisions("transfer.team_terms", "transfer", { "taxRate" }, {})
			end,
			"transfer.team_terms declares taxRate without a Default; transfer must say what the slot means when nobody provides it"
		)
		assert.has_error(function()
			ModuleHandler.ResolveProvisions("k", "transfer", { "taxRate" }, { enrichment("tech", defaults("taxRate")) })
		end, "tech/policies/x.lua: only transfer may Default taxRate on k")
		assert.has_error(function()
			ModuleHandler.ResolveProvisions(
				"k",
				"transfer",
				{ "taxRate" },
				{ enrichment("transfer", defaults("other", "taxRate")) }
			)
		end, "transfer/policies/x.lua: k declares no slot named other to Default")
	end)

	it("may be provided by any number of modules; the mode decides who is live", function()
		local resolved = ModuleHandler.ResolveProvisions("k", "transfer", { "taxRate" }, {
			enrichment("transfer", defaults("taxRate")),
			enrichment("tech", provides("taxRate", 0.5)),
			enrichment("other", provides("taxRate", 0.9)),
		})
		assert.are.equal(2, #resolved.providers)
		assert.are.equal("default:taxRate", ModuleHandler.EnrichWith(resolved, { transfer = true }, {}).taxRate)
		assert.are.equal(0.5, ModuleHandler.EnrichWith(resolved, { tech = true }, {}).taxRate)
		assert.are.equal(0.9, ModuleHandler.EnrichWith(resolved, { other = true }, {}).taxRate)
		assert.has_error(
			function()
				ModuleHandler.EnrichWith(resolved, { tech = true, other = true }, {})
			end,
			"taxRate answered by both tech/policies/x.lua and other/policies/x.lua in one ask: the mode leaves both live"
		)
	end)

	it("a provider that answers nil declines, and the Default steps in", function()
		local resolved = ModuleHandler.ResolveProvisions("k", "transfer", { "taxRate" }, {
			enrichment("transfer", defaults("taxRate")),
			enrichment("tech", provides("taxRate", nil)),
		})
		assert.are.equal("default:taxRate", ModuleHandler.EnrichWith(resolved, { tech = true }, {}).taxRate)
	end)
end)

describe("what a mode makes live", function()
	local byCategory = {
		transfer = {
			enabled = { key = "enabled", category = "transfer", module = "transfer", uses = {} },
			tech_core = { key = "tech_core", category = "transfer", module = "tech", uses = {} },
			customize = { key = "customize", category = "transfer", module = "transfer", uses = { "tech" } },
		},
		game = {
			standard = { key = "standard", category = "game", module = "modes", uses = {} },
		},
	}
	local alwaysLive = { economy = true, construction = true }

	it("is the preset's module, what it Uses, and every module that ships no presets", function()
		assert.are.same(
			{ economy = true, construction = true, transfer = true, modes = true },
			ModuleHandler.LiveModules(byCategory, alwaysLive, { transfer = "enabled", game = "standard" })
		)
		assert.are.same(
			{ economy = true, construction = true, tech = true, modes = true },
			ModuleHandler.LiveModules(byCategory, alwaysLive, { transfer = "tech_core", game = "standard" })
		)
		assert.are.same(
			{ economy = true, construction = true, transfer = true, tech = true, modes = true },
			ModuleHandler.LiveModules(byCategory, alwaysLive, { transfer = "customize", game = "standard" })
		)
	end)

	it("is walked, every combination, to prove no preset leaves two providers live for one slot", function()
		local function provider(module)
			return {
				op = { names = { "taxRate" }, evaluate = function() end },
				module = module,
				file = module .. "/p.lua",
			}
		end
		assert.are.same(
			{},
			ModuleHandler.IsolationConflicts(byCategory, alwaysLive, { provider("tech"), provider("other") })
		)
		local withOther = {
			transfer = byCategory.transfer,
			game = byCategory.game,
			experiments = { other = { key = "other", category = "experiments", module = "other", uses = {} } },
		}
		assert.are.same({
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=customize",
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=tech_core",
		}, ModuleHandler.IsolationConflicts(withOther, alwaysLive, { provider("other"), provider("tech") }))
	end)
end)
