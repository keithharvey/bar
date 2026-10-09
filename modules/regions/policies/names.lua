local Policy = require("modules/policy")

---@class RegionNamesContext<R>
---@field type RegionType
---@field regions R[]
---@field proposed string[]

---@class RegionNamesPolicy: PolicySteps<RegionNamesContext<Region>, RegionNamesContext<Region>>
---@field Label "Label"
---@field Result "Result"

---@type RegionNamesPolicy
local Names = {
	Label = "Label",
	Result = "Result",
}
Policy.Single(Names)

Policies.On(Names)
	.Step(Names.Label, function(ctx)
		local label = ctx.type.label:lower():gsub(" ", "_")
		for i in ipairs(ctx.regions) do
			ctx.proposed[i] = label
		end
	end)
	.Return(Names.Result, function(ctx)
		return ctx
	end)

---@class (partial) RegionsContract
local Contract = {}
Contract.Names = Names

return Contract
