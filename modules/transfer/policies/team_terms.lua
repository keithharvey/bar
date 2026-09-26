local Policy = require("modules/policy")
local Tax = require("modules/transfer/resource/tax")

-- One team's terms, no pairing: what it pays in tax, from the modoption unless a module says otherwise
--
---@class TransferTeamContext: PolicyContext
---@field teamId integer
---@field springRepo Spring

---@class TransferTeamTermsFacts: PolicyFacts<TransferTeamContext>
---@field TaxRate "taxRate"

---@class (partial) TransferContract
---@field TeamTerms TransferTeamTermsFacts

---@type TransferTeamTermsFacts
local TeamTerms = {
	TaxRate = "taxRate",
}
Policy.Facts(TeamTerms)

Policies.On(TeamTerms).Default(TeamTerms.TaxRate, function(ctx)
	return Tax.ModOption(ctx.modOptions)
end)

return { TeamTerms = TeamTerms }
