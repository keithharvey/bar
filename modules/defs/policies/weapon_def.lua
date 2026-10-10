local Policy = require("modules/policy")

-- Every weapon def passes through here once; the base game's post-processing is one named step of it
--
---@class DefsWeaponDefPolicy: PolicySteps<DefContext, DefContext>
---@field Base "Base"
---@field Result "Result"

---@type DefsWeaponDefPolicy
local WeaponDef = {
	Base = "Base",
	Result = "Result",
}
Policy.Single(WeaponDef)

Policies.On(WeaponDef)
	.Step(WeaponDef.Base, function(ctx)
		require("modules/defs/lib/base").Base().WeaponDef_Post(ctx.name, ctx.def)
	end)
	.Return(WeaponDef.Result, function(ctx)
		return ctx
	end)

---@class (partial) DefsContract
local Contract = {}
Contract.WeaponDef = WeaponDef

return Contract
