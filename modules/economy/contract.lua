local Policy = require("modules/policy")
local Modules = require("modules/enums").Modules

---@class EconomyTeamResult
---@field teamId integer
---@field resourceType ResourceName
---@field delta number Net change vs the snapshot (informational; conservation/tests)
---@field sent number
---@field received number
---@field excess number Wasted overflow this tick

---@class EconomyTeamContext one team, asked what redistribution costs it
---@field teamId integer
---@field springRepo Spring

---@class EconomyDistributionFacts: PolicyFacts<EconomyTeamContext>
---@field TaxRate "taxRate"

---@type EconomyDistributionFacts
local Distribution = {
	TaxRate = "taxRate",
}

---@class EconomyRedistributionContext one cadence tick's results, before they are published
---@field results EconomyTeamResult[]

---@class EconomyRedistributionFacts: PolicyFacts<EconomyRedistributionContext>
---@field Results "results"

---@type EconomyRedistributionFacts
local Redistribution = {
	Results = "results",
}

---@class EconomyTransfer metal or energy one team hands another before the tick is solved
---@field from integer
---@field to integer
---@field resourceType ResourceName
---@field amount number

---@class EconomyPoolingContext one cadence tick's snapshot, before it is solved
---@field springRepo Spring
---@field teams table<integer, EconomyTeamResources> by team id
---@field seconds number since the last tick

---@class EconomyPoolingFacts: PolicyFacts<EconomyPoolingContext>
---@field Transfers "transfers"

---@type EconomyPoolingFacts
local Pooling = {
	Transfers = "transfers",
}

---@class EconomyContract
---@field Distribution EconomyDistributionFacts
---@field Redistribution EconomyRedistributionFacts
---@field Pooling EconomyPoolingFacts

return Policy.Contract(Modules.Economy, {
	Distribution = Policy.Facts(Distribution),
	Redistribution = Policy.Facts(Redistribution),
	Pooling = Policy.Facts(Pooling),
})
