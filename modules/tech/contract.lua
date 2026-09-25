local PolicyBuilder = require("modules/policy_builder")
local Modules = require("modules/enums").Modules
local ConstructionContract = require("modules/construction/contract")

---@class TechTierRequest
---@field level integer the team's current tech level
---@field points number keystone points the team holds
---@field opts table<string, string|number|boolean> the modoption snapshot
---@field t2Threshold number keystones per player for tech 2
---@field t3Threshold number keystones per player for tech 3

---@class TechCreationStages the guard tech adds to construction's creation pipeline
---@field BelowTier string a lab whose tier the team has not reached

---@type TechCreationStages
local Creation = {
	BelowTier = "BelowTier",
}

---@class TechCoreStages: PolicyStages<TechTierRequest, TechCoreLadder>
---@field TechCoreLadder string

---@type TechCoreStages
local TechCore = {
	TechCoreLadder = "TechCoreLadder",
}

---@class TechContract
---@field TechCore TechCoreStages
---@field Creation TechCreationStages

return PolicyBuilder.Contract(Modules.Tech, {
	TechCore = PolicyBuilder.Single(TechCore),
	Creation = PolicyBuilder.Contributes(ConstructionContract.Creation, Creation),
})
