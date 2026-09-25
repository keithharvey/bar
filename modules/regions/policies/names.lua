local Policy = require("modules/policy")

---@class RegionNamesContext
---@field type RegionType
---@field regions Region[]
---@field proposed string[]

---@class RegionNamesSteps: PolicySteps<RegionNamesContext, RegionNamesContext>
---@field Label string

---@class (partial) RegionsContract
---@field Names RegionNamesSteps

---@type RegionNamesSteps
local Names = Policy.Fold({
	Label = "Label",
})

Policies.On(Names).Apply(Names.Label, function(ctx)
	local label = ctx.type.label:lower():gsub(" ", "_")
	for i in ipairs(ctx.regions) do
		ctx.proposed[i] = label
	end
end)

return { Names = Names }
