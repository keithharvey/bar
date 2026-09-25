local Policy = require("modules/policy")
local Modules = require("modules/enums").Modules

---@class DefContext one def, on its way through post-processing
---@field name string the def's key in UnitDefs or WeaponDefs
---@field def table the def table, edited in place
---@field modOptions table

---@class UnitDefSteps: PolicySteps<DefContext, DefContext>
---@field Base string the base game's post-processing, gamedata/alldefs_post.lua

---@type UnitDefSteps
local UnitDef = {
	Base = "Base",
}

---@class WeaponDefSteps: PolicySteps<DefContext, DefContext>
---@field Base "Base"

---@type WeaponDefSteps
local WeaponDef = {
	Base = "Base",
}

---@class DefsContract
---@field UnitDef UnitDefSteps
---@field WeaponDef WeaponDefSteps

return Policy.Contract(Modules.Defs, {
	UnitDef = Policy.Fold(UnitDef),
	WeaponDef = Policy.Fold(WeaponDef),
}, function(Policies)
	local base = require("modules/defs/lib/base").Base

	Policies.On(UnitDef).Apply(UnitDef.Base, function(ctx)
		base().UnitDef_Post(ctx.name, ctx.def)
	end)

	Policies.On(WeaponDef).Apply(WeaponDef.Base, function(ctx)
		base().WeaponDef_Post(ctx.name, ctx.def)
	end)
end)
