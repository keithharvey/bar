local Policy = require("modules/policy")

-- Every unit def passes through here once, after the engine has read it; the base game's post-processing is one
-- named step of it, and a module adds its own before or after
--
---@class DefContext
---@field name string
---@field def table
---@field modOptions table

---@class DefsUnitDefPolicy: PolicySteps<DefContext, DefContext>
---@field Base "Base"

---@class (partial) DefsContract
---@field UnitDef DefsUnitDefPolicy

---@type DefsUnitDefPolicy
local UnitDef = {
	Base = "Base",
}
Policy.Fold(UnitDef)

Policies.On(UnitDef).Apply(UnitDef.Base, function(ctx)
	require("modules/defs/lib/base").Base().UnitDef_Post(ctx.name, ctx.def)
end)

return { UnitDef = UnitDef }
