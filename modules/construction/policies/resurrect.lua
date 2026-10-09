local Policy = require("modules/policy")

-- May a partly reclaimed wreck still be resurrected
--
---@class ConstructionResurrectContext
---@field partialAllowed boolean

---@class ConstructionResurrectPolicy: PolicySteps<ConstructionResurrectContext, boolean>
---@field PartialResurrectionDisabled "PartialResurrectionDisabled"
---@field Allowed "Allowed"

---@type ConstructionResurrectPolicy
local Resurrect = {
	PartialResurrectionDisabled = "PartialResurrectionDisabled",
	Allowed = "Allowed",
}
Policy.Single(Resurrect)

Policies.On(Resurrect)
	.Step(Resurrect.PartialResurrectionDisabled, function(ctx)
		if not ctx.partialAllowed then
			return false
		end
	end)
	.Return(Resurrect.Allowed, function()
		return true
	end)

---@class (partial) ConstructionContract
local Contract = {}
Contract.Resurrect = Resurrect

return Contract
