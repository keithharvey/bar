local Policy = require("modules/policy")

---@class RegionNamesContext<R>
---@field type RegionType
---@field regions R[]
---@field proposed string[]

---@class RegionNamesPolicy: PolicySteps<RegionNamesContext<Region>, RegionNamesContext<Region>>
---@field Label "Label"

---@class (partial) RegionsContract
---@field Names RegionNamesPolicy

---@type RegionNamesPolicy
local Names = {
	Label = "Label",
}
Policy.Fold(Names)

Policies.On(Names).Apply(Names.Label, function(ctx)
	local label = ctx.type.label:lower():gsub(" ", "_")
	for i in ipairs(ctx.regions) do
		ctx.proposed[i] = label
	end
end)

return { Names = Names }
