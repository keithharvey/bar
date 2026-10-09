local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local TechDefs = require("modules/tech/defs")
local TechEnums = require("modules/tech/enums")

---@type DefsContract
local Defs = Policies.Contract(Modules.Defs)

-- Tech blocking shapes the unit defs: cheaper T2 labs, the Keystone in every general T1 constructor's menu
--
---@class TechUnitDefSteps: PolicySteps<DefContext, DefContext>
---@field TechBlocking "TechBlocking"

---@type TechUnitDefSteps
local UnitDef = {
	TechBlocking = "TechBlocking",
}
Policy.Contributes(Defs.UnitDef, UnitDef)

Policies.On(UnitDef).Step(UnitDef.TechBlocking, function(ctx)
	if ctx.modOptions[TechEnums.ModOptions.TechBlocking] then
		TechDefs.Apply(ctx.name, ctx.def)
	end
end)

---@class (partial) TechContract
local Contract = {}
Contract.UnitDef = UnitDef

return Contract
