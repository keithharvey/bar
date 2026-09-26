local Policy = require("modules/policy")

-- May this team build this def at all: the build option, not one step of it
--
---@class ConstructionCreationContext
---@field unitDefID integer
---@field unitDef table
---@field teamID integer
---@field tier integer|nil

---@class ConstructionCreationPolicy: PolicySteps<ConstructionCreationContext, boolean>
---@field Allowed "Allowed"

---@class (partial) ConstructionContract
---@field Creation ConstructionCreationPolicy

---@type ConstructionCreationPolicy
local Creation = {
	Allowed = "Allowed",
}
Policy.Single(Creation)

Policies.On(Creation).Answer(Creation.Allowed, function()
	return true
end)

-- What creation asks of a module that runs a tier system
--
---@class ConstructionCreationFacts: PolicyFacts<ConstructionCreationContext>
---@field Tier "tier"

---@class (partial) ConstructionContract
---@field CreationFacts ConstructionCreationFacts

---@type ConstructionCreationFacts
local CreationFacts = {
	Tier = "tier",
}
Policy.Facts(CreationFacts)

return { Creation = Creation, CreationFacts = CreationFacts }
