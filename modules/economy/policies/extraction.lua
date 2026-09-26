local Policy = require("modules/policy")

-- What extraction pays each team this tick: what its extractors made, unless a mode answers otherwise
--
---@class EconomyExtractionContext
---@field springRepo Spring
---@field modOptions table<string, string|number|boolean>
---@field teams table<integer, EconomyTeamResources>
---@field seconds number
---@field income table<integer, table<ResourceName, number>> what each team's extractors made over the tick

---@class EconomyExtractionFacts: PolicyFacts<EconomyExtractionContext>
---@field Income "income"

---@class (partial) EconomyContract
---@field Extraction EconomyExtractionFacts

---@type EconomyExtractionFacts
local Extraction = {
	Income = "income",
}
Policy.Facts(Extraction)

return { Extraction = Extraction }
