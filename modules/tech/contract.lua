local Policy = require("modules/policy")
local Modules = require("modules/enums").Modules
local ConstructionContract = require("modules/construction/contract")

---@class TechTierRequest
---@field level integer the team's current tech level
---@field points number keystone points the team holds
---@field opts table<string, string|number|boolean> the modoption snapshot
---@field t2Threshold number keystones per player for tech 2
---@field t3Threshold number keystones per player for tech 3

---@class TechCreationSteps the guard tech adds to construction's creation policy
---@field BelowTier string a lab whose tier the team has not reached

---@type TechCreationSteps
local Creation = {
	BelowTier = "BelowTier",
}

---@class TechCoreSteps: PolicySteps<TechTierRequest, TechCoreLadder>
---@field TechCoreLadder "TechCoreLadder"

---@type TechCoreSteps
local TechCore = {
	TechCoreLadder = "TechCoreLadder",
}

---@class TechContract
---@field TechCore TechCoreSteps
---@field Creation TechCreationSteps

return Policy.Contract(Modules.Tech, {
	TechCore = Policy.Single(TechCore),
	Creation = Policy.Contributes(ConstructionContract.Creation, Creation),
})
