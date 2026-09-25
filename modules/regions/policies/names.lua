local PolicyBuilder = require("modules/policy_builder")

---@class RegionNamesContext
---@field type RegionType
---@field regions Region[]
---@field bases string[]

---@class RegionNamesStages: PolicyStages<RegionNamesContext, RegionNamesContext>
---@field Label string

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
