local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")

---@type ConstructionContract
local Construction = Policies.Contract(Modules.Construction)

-- A team's tier is its tech level, and a lab above it stays out of the build menu
--
---@class TechConstructionCreationSteps: PolicySteps<ConstructionCreationContext, boolean>
---@field BelowTier "BelowTier"

---@type TechConstructionCreationSteps
local Creation = {
	BelowTier = "BelowTier",
}
Policy.Contributes(Construction.Creation, Creation)

Policies.For(Construction.CreationFacts).Provide(Construction.CreationFacts.Tier, function(ctx)
	local raw = ctx.springRepo.GetTeamRulesParam(ctx.teamID, "tech_level")
	if raw == nil then
		return nil
	end
	return tonumber(raw) or 1
end)

-- construction's Creation refuses with false; this guard has to know that, and say it itself
Policies.On(Creation).Step(Creation.BelowTier, function(ctx)
	if ctx.tier == nil or not ctx.unitDef.isFactory then
		return
	end
	local required = tonumber(ctx.unitDef.customParams and ctx.unitDef.customParams.techlevel) or 1
	if required >= 2 and ctx.tier < required then
		return false
	end
end)

---@class (partial) TechContract
local Contract = {}
Contract.Creation = Creation

return Contract
