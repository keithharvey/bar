local Policy = require("modules/policy")

-- What redistribution costs one team: nothing, unless a module taxes it
--
---@class EconomyTeamContext
---@field teamId integer
---@field springRepo Spring

---@class EconomyDistributionFacts: PolicyFacts<EconomyTeamContext>
---@field TaxRate "taxRate"

---@class (partial) EconomyContract
---@field Distribution EconomyDistributionFacts

---@type EconomyDistributionFacts
local Distribution = {
	TaxRate = "taxRate",
}
Policy.Facts(Distribution)

Policies.On(Distribution).Default(Distribution.TaxRate, function()
	return 0
end)

return { Distribution = Distribution }
