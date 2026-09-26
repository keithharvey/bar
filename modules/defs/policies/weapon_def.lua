local Policy = require("modules/policy")

-- Every weapon def passes through here once; the base game's post-processing is one named step of it
--
---@class DefsWeaponDefPolicy: PolicySteps<DefContext, DefContext>
---@field Base "Base"

---@class (partial) DefsContract
---@field WeaponDef DefsWeaponDefPolicy

---@type DefsWeaponDefPolicy
local WeaponDef = {
	Base = "Base",
}
Policy.Fold(WeaponDef)

Policies.On(WeaponDef).Apply(WeaponDef.Base, function(ctx)
	require("modules/defs/lib/base").Base().WeaponDef_Post(ctx.name, ctx.def)
end)

return { WeaponDef = WeaponDef }
