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
---@field product number|nil

-- Two guards and a Return. Each guard hands back the refusal itself: there is no other place for it to live.
local function owner()
	---@type AssembledPolicy<SpecCtx, boolean|string|table>
	local steps = {}
	Policy.Assemble(
		steps,
		Policy.Chain()
			.Step("Submerged", function(ctx)
				if ctx.submerged then
					return false
				end
			end)
			.Step("OutOfReach", function(ctx)
				if ctx.far then
					return false
				end
			end)
			.Return("Allowed", function()
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

---@generic T: table
---@param owner string
---@param members T
---@return T
local function declared(owner, members)
	Policy.Declare(owner, members, "spec")
	return members
end

describe("a policy's identity", function()
	it("carries owner and category: every policy is steps", function()
		local Contract = declared("transport", {
			Load = Policy.Single({ Submerged = "Submerged" }),
			LoadedSpeed = Policy.Single({ CommanderDrag = "CommanderDrag" }),
		})
		assert.are.same({ owner = "transport", category = "load", steps = true }, Policy.IdentityOf(Contract.Load))
		assert.are.same(
			{ owner = "transport", category = "loaded_speed", steps = true },
			Policy.IdentityOf(Contract.LoadedSpeed)
		)
		assert.is_nil(Policy.IdentityOf({}))
		assert.are.equal(Contract.Load, Policy.Chain(Contract.Load).steps)
	end)

	it("requires every category to declare itself", function()
		assert.has_error(function()
			declared("transport", { Load = { Submerged = "Submerged" } })
		end, "spec: Load must declare itself: Single(...), Contributes(...) or Facts(...)")
	end)

	it("serializes a declaration's name to the key the runtime uses", function()
		assert.are.equal("unit_terms_notes", Policy.KeyOf("UnitTermsNotes"))
		assert.are.equal("take", Policy.KeyOf("Take"))
	end)
end)

describe("one chain for owners and contributors", function()
	it("a bare step joins the end of the checks, never past the Return", function()
		local steps = owner()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Step("NoTanks", function(ctx)
					if ctx.tank then
						return false
					end
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
			.Step("A", function() end)
			.After("Submerged")
			.Step("B", function() end)
			.Before("Allowed")
			.Build()
		Policy.Assemble(steps, ops, "mod")
		assert.are.same({ "Submerged", "A", "OutOfReach", "B", "Allowed" }, names(steps))
	end)

	it("replaces a step in place, keeping its kind, the Return included", function()
		local steps = owner()
		local ops = Policy.Chain()
			.Replace("OutOfReach", function() end)
			.Replace("Allowed", function()
				return "maybe"
			end)
			.Build()
		Policy.Assemble(steps, ops, "mod")
		assert.are.same({ "Submerged", "OutOfReach", "Allowed" }, names(steps))
		assert.are.equal("return", steps[3].kind)
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
			Policy.Assemble(owner(), Policy.Chain().Step("Submerged", function() end).Build(), "mod.lua")
		end, "mod.lua: the policy already has a step named Submerged")
		assert.has_error(function()
			Policy.Chain().After("Submerged")
		end)
	end)
end)

describe("a guard", function()
	it("is a Step that returns the refusal itself when its condition does not hold", function()
		---@type AssembledPolicy<SpecCtx, boolean>
		local steps = {}
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Step("WithinReach", function(ctx)
					if not ctx.reachable then
						return false
					end
				end)
				.Return("Allowed", function()
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
		local Contract = declared("transfer", {
			TeamPairing = Policy.Facts({ Weather = "weather" }),
		})
		assert.are.same(
			{ owner = "transfer", category = "team_pairing", facts = true },
			Policy.IdentityOf(Contract.TeamPairing)
		)
		local ops = Policy.Enrichment(Contract.TeamPairing)
			.Provide(Contract.TeamPairing.Weather, function(ctx)
				return { level = 2 }
			end)
			.Build()
		assert.are.same({ "weather" }, ops[1].names)
	end)

	it("a provider may add a fact the contract did not declare, and never removes one", function()
		local Contract = declared("transfer", {
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

describe("what a guard returns", function()
	it("nothing said yes is nil, unless the owner's Return says no", function()
		local steps = {}
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Step("Stunned", function(ctx)
					if ctx.stunned then
						return true
					end
				end)
				.Build(),
			"owner"
		)
		assert.is_true(run(steps, { stunned = true }))
		assert.is_nil(run(steps, {}))
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Return("Refused", function()
					return { allowed = false, reason = "nobody said yes" }
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ allowed = false, reason = "nobody said yes" }, run(steps, {}))
	end)

	it("a product by hand says nothing about a missing factor, unless its Return remembers to", function()
		local steps = {}
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Step("Base", function(ctx)
					if ctx.speed ~= nil then
						ctx.product = (ctx.product or 1) * ctx.speed
					end
				end)
				.Return("Result", function(ctx)
					if ctx.product == nil then
						error("loaded_speed: no step gave a factor; the owner's Base must")
					end
					return ctx.product
				end)
				.Build(),
			"owner"
		)
		assert.are.equal(3, run(steps, { speed = 3 }))
		assert.has_error(function()
			run(steps, {})
		end)
	end)

	it("is whatever each guard returns: false here, a shape there, and nothing holds them to one", function()
		local steps = owner()
		assert.is_false(run(steps, { submerged = true }))
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Replace("Submerged", function(ctx)
					if ctx.submerged then
						return { allowed = false, deep = ctx.submerged }
					end
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ allowed = false, deep = true }, run(steps, { submerged = true }))
		assert.is_false(run(steps, { far = true }))
		assert.is_true(run(steps, {}))
	end)

	it("Return is declared once", function()
		local steps = owner()
		assert.has_error(function()
			Policy.Assemble(
				steps,
				Policy.Chain()
					.Return("Again", function()
						return false
					end)
					.Build(),
				"mod.lua"
			)
		end, "mod.lua: the policy already has a Return, Allowed")
	end)
end)

describe("the Return", function()
	it("is always last: nothing goes after it, and a step placed nowhere lands before it", function()
		assert.has_error(function()
			Policy.Assemble(owner(), Policy.Chain().Step("Late", function() end).After("Allowed").Build(), "mod")
		end, "mod: nothing goes after Allowed: it is the Return")
		local steps = owner()
		Policy.Assemble(steps, Policy.Chain().Step("Late", function() end).Build(), "mod")
		assert.are.same({ "Submerged", "OutOfReach", "Late", "Allowed" }, names(steps))
	end)

	it("an early Step preempts — answering when it can, passing when it cannot", function()
		local steps = owner()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Step("Scripted", function(ctx)
					return ctx.scripted
				end)
				.Before("Submerged")
				.Build(),
			"mod"
		)
		assert.are.equal("override", run(steps, { scripted = "override", submerged = true }))
		assert.is_false(run(steps, { submerged = true }))
		assert.is_true(run(steps, {}))
	end)

	it("a product, by hand: steps multiply into the context and the Return hands it back", function()
		---@type AssembledPolicy<SpecProductCtx, number>
		local policy = {}
		Policy.Assemble(
			policy,
			Policy.Chain()
				.Step("CommanderDrag", function(ctx)
					if ctx.carriesCommander then
						ctx.product = (ctx.product or 1) * 0.5
					end
				end)
				.Step("MudCrawl", function(ctx)
					if ctx.inMud then
						ctx.product = (ctx.product or 1) * 0.25
					end
				end)
				.Return("Result", function(ctx)
					if ctx.product == nil then
						error("no step gave a factor")
					end
					return ctx.product
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

	it("nothing follows Return in one chain, and nothing places it", function()
		assert.has_error(function()
			Policy.Chain()
				.Return("Allowed", function()
					return true
				end)
				.Step("Late", function() end)
		end, "PolicyChain: no step follows Return")
		assert.has_error(function()
			Policy.Chain()
				.Return("Allowed", function()
					return true
				end)
				.After("Submerged")
		end, "PolicyChain: Return is always last; .After cannot place it")
	end)
end)

describe("a fold, by hand", function()
	local function fold(ops, origin)
		---@type AssembledPolicy<table, table>
		local steps = {}
		Policy.Assemble(steps, ops, origin)
		return steps
	end

	it("hands one context through every step, owner's first, and the Return gives it back", function()
		local steps = fold(
			Policy.Chain()
				.Step("Base", function(ctx)
					ctx.def.mass = (ctx.def.mass or 0) + 1
				end)
				.Return("Context", function(ctx)
					return ctx
				end)
				.Build(),
			"owner"
		)
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Step("Heavier", function(ctx)
					ctx.def.mass = ctx.def.mass * 10
				end)
				.Build(),
			"mod"
		)
		local ctx = { def = {} }
		assert.are.equal(ctx, ModuleHandler.Evaluate(steps, ctx))
		assert.are.equal(10, ctx.def.mass)
		assert.are.same({ "Base", "Heavier", "Context" }, names(steps))
	end)

	it("a step that returns ends the fold there: every step after it is skipped, with no word said", function()
		local steps = fold(
			Policy.Chain()
				.Step("Base", function(ctx)
					ctx.def.mass = 1
				end)
				.Return("Context", function(ctx)
					return ctx
				end)
				.Build(),
			"owner"
		)
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Step("Stop", function()
					return "stop"
				end)
				.Step("Heavier", function(ctx)
					ctx.def.mass = ctx.def.mass * 10
				end)
				.Build(),
			"mod"
		)
		local ctx = { def = {} }
		assert.are.equal("stop", ModuleHandler.Evaluate(steps, ctx))
		assert.are.equal(1, ctx.def.mass)
		assert.are.same({ "Base", "Stop", "Heavier", "Context" }, names(steps))
	end)
end)

describe("a declared contribution", function()
	local function target()
		return declared("transport", {
			Load = Policy.Single({ Submerged = "Submerged", Allowed = "Allowed" }),
			Facts = Policy.Facts({ Reach = "reach" }),
		})
	end

	it("carries the target's identity and the contributor's own", function()
		local Contract = target()
		local mod = declared("mod", {
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
			.Step("NoTanks", function()
				return false
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

	it("a slot nobody Defaults or provides is the context's field of its name", function()
		local resolved = ModuleHandler.ResolveProvisions("transfer.team_terms", "transfer", { "taxRate" }, {})
		assert.are.equal(0.3, ModuleHandler.EnrichWith(resolved, {}, { taxRate = 0.3 }).taxRate)
		assert.is_nil(ModuleHandler.EnrichWith(resolved, {}, {}).taxRate)
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
			enabled = { key = "enabled", category = "transfer", module = "transfer", modules = { "transfer" } },
			tech_core = { key = "tech_core", category = "transfer", module = "tech", modules = { "tech" } },
			customize = {
				key = "customize",
				category = "transfer",
				module = "transfer",
				modules = { "tech", "transfer" },
			},
		},
		game = {
			standard = { key = "standard", category = "game", module = "modes", modules = { "modes" } },
		},
	}
	local alwaysLive = { economy = true, construction = true }

	it("is what the picked presets make live, and every module that ships no presets", function()
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
			experiments = {
				other = { key = "other", category = "experiments", module = "other", modules = { "other" } },
			},
		}
		assert.are.same({
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=customize",
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=tech_core",
		}, ModuleHandler.IsolationConflicts(withOther, alwaysLive, { provider("other"), provider("tech") }))
	end)

	it("a step conditioned inside itself steps aside when the condition does not hold: it returns nothing", function()
		local steps = Policy.Single({ Bar = "Bar", Quick = "Quick", Slow = "Slow" })
		Policy.Declare("t", { Steps = steps })
		local ops = Policy.Chain(steps)
			.Step(steps.Bar, function(ctx)
				if ctx.barred then
					return false
				end
			end)
			.Step(steps.Quick, function(ctx)
				if ctx.hurry then
					return "quick"
				end
			end)
			.Return(steps.Slow, function()
				return "slow"
			end)
			.Build()
		local policy = {}
		Policy.Assemble(policy, ops, "t")
		assert.are.equal("slow", run(policy, {}))
		assert.are.equal("quick", run(policy, { hurry = true }))
		assert.are.equal(false, run(policy, { barred = true, hurry = true }))
	end)
end)
