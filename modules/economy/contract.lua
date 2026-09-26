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

---@class EconomyExtractionContext one cadence tick, as the engine paid it
---@field springRepo Spring
---@field teams table<integer, EconomyTeamResources> by team id
---@field seconds number the tick's length
---@field income table<integer, table<ResourceName, number>> what each team's extractors made over the tick, by team id: the engine's answer, the fact's unless a mode provides

---@class EconomyExtractionFacts: PolicyFacts<EconomyExtractionContext>
---@field Income "income"

---@type EconomyExtractionFacts
local Extraction = {
	Income = "income",
}

---@class EconomyContract
---@field Distribution EconomyDistributionFacts
---@field Redistribution EconomyRedistributionFacts
---@field Extraction EconomyExtractionFacts

return Policy.Contract(Modules.Economy, {
	Distribution = Policy.Facts(Distribution),
	Redistribution = Policy.Facts(Redistribution),
	Extraction = Policy.Facts(Extraction),
})
