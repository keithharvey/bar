local PolicyBuilder = require("modules/policy_builder")
local Modules = require("modules/enums").Modules

---@class DefContext one def, on its way through post-processing
---@field name string the def's key in UnitDefs or WeaponDefs
---@field def table the def table, edited in place
---@field modOptions table

---@class UnitDefStages: PolicyStages<DefContext, DefContext>
---@field Base string the base game's post-processing, gamedata/alldefs_post.lua

---@type UnitDefStages
local UnitDef = {
	Base = "Base",
}

---@class WeaponDefStages: PolicyStages<DefContext, DefContext>
---@field Base string

---@type WeaponDefStages
local WeaponDef = {
	Base = "Base",
}

---@class DefsContract
---@field UnitDef UnitDefStages
---@field WeaponDef WeaponDefStages

return PolicyBuilder.Contract(Modules.Defs, {
	UnitDef = PolicyBuilder.Fold(UnitDef),
	WeaponDef = PolicyBuilder.Fold(WeaponDef),
}, function(Policies)
	local base = require("modules/defs/lib/base").Base

	Policies.On(UnitDef).Apply(UnitDef.Base, function(ctx)
		base().UnitDef_Post(ctx.name, ctx.def)
	end)

	Policies.On(WeaponDef).Apply(WeaponDef.Base, function(ctx)
		base().WeaponDef_Post(ctx.name, ctx.def)
	end)
end)
