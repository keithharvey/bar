local PolicyBuilder = require("modules/policy_builder")

---@class RegionNamesContext the context for naming every region of one type. Stages fill in a base name for each region that has none
---@field type RegionType
---@field regions Region[]
---@field bases string[] base name per region, by index, for regions with no name of their own. Siblings that share a base are numbered afterwards

---@class RegionNamesStages: PolicyStages<RegionNamesContext, RegionNamesContext> the module that owns a type contributes the stage that names that type's regions
---@field Label string fallback: the type's label

---@class (partial) RegionsContract
---@field Names RegionNamesStages

---@class (partial) RegionsPipelines
---@field names AssembledPipeline<RegionNamesContext, RegionNamesContext>

---@type RegionNamesStages
local Names = PolicyBuilder.Fold({
	Label = "Label",
})

Policies.On(Names).Apply(Names.Label, function(ctx)
	local label = ctx.type.label:lower():gsub(" ", "_")
	for i in ipairs(ctx.regions) do
		ctx.bases[i] = label
	end
end)

return { Names = Names }
