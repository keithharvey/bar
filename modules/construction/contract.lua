local Policy = require("modules/policy")
local Modules = require("modules/enums").Modules

---@class ConstructionAssistContext a builder's command that would help an ally's unit along
---@field allied boolean the target belongs to another team we are allied with
---@field targetComplete boolean
---@field targetIsBuilder boolean a factory, or a builder that can build or assist
---@field assistEnabled boolean the allied assist modoption

---@class ConstructionAssistPolicy: PolicySteps<ConstructionAssistContext, boolean>
---@field AlliedAssistDisabled "AlliedAssistDisabled"
---@field Allowed "Allowed"

---@type ConstructionAssistPolicy
local Assist = {
	AlliedAssistDisabled = "AlliedAssistDisabled",
	Allowed = "Allowed",
}

---@class ConstructionReclaimContext a reclaim, or a guard of something that reclaims
---@field allied boolean
---@field command "reclaim"|"guard"
---@field targetCanReclaim boolean
---@field reclaimEnabled boolean the allied unit reclaim modoption

---@class ConstructionReclaimPolicy: PolicySteps<ConstructionReclaimContext, boolean>
---@field AlliedReclaimDisabled "AlliedReclaimDisabled"
---@field Allowed "Allowed"

---@type ConstructionReclaimPolicy
local Reclaim = {
	AlliedReclaimDisabled = "AlliedReclaimDisabled",
	Allowed = "Allowed",
}

---@class ConstructionResurrectContext may a partly reclaimed wreck still be resurrected
---@field partialAllowed boolean the partial resurrection modoption

---@class ConstructionResurrectPolicy: PolicySteps<ConstructionResurrectContext, boolean>
---@field PartialResurrectionDisabled "PartialResurrectionDisabled"
---@field Allowed "Allowed"

---@type ConstructionResurrectPolicy
local Resurrect = {
	PartialResurrectionDisabled = "PartialResurrectionDisabled",
	Allowed = "Allowed",
}

---@class ConstructionBuildContext one build step by a builder: on a unit, or on a feature (reclaim, resurrect)
---@field builderID integer
---@field builderTeam integer
---@field delayed boolean the builder is under a build delay
---@field unitID integer|nil the unit being built, for a unit step
---@field unitDefID integer|nil
---@field featureID integer|nil the feature being worked, for a feature step
---@field part number the step's share of the whole; negative for reclaim

---@class ConstructionBuildPolicy: PolicySteps<ConstructionBuildContext, boolean>
---@field BuilderDelayed "BuilderDelayed"
---@field Allowed "Allowed"

---@type ConstructionBuildPolicy
local Build = {
	BuilderDelayed = "BuilderDelayed",
	Allowed = "Allowed",
}

---@class ConstructionPlacementContext where a builder wants to put a new unit
---@field modOptions table<string, any>
---@field unitDefID integer
---@field builderTeam integer
---@field x number
---@field y number
---@field z number
---@field extractor "mex"|"geo"|nil what the def extracts, if anything
---@field alliedExtractorNearby boolean another team's extractor already sits in the radius
---@field utilitySharing boolean utility buildings may change hands between allies, a fact the module that owns sharing provides; false when nobody does
---@field spotX number|nil for an extractor, the resource spot it targets: the nearest spot to the build position, which is what the footprint yields from wherever it lands. Known for a mex today
---@field spotZ number|nil
---@field spotHolder integer the team that holds this spot, a fact any module that deals out spots may provide, for whatever kind of extractor it deals; the builder itself when nobody else does, or when the builder is one of several who hold it
---@field spotHolderAllied boolean the holder is another team on the builder's side; an enemy's hold restricts nobody

---@class ConstructionPlacementPolicy: PolicySteps<ConstructionPlacementContext, boolean>
---@field AlliedExtractorOccupied "AlliedExtractorOccupied"
---@field SpotHeldByAnAlly string an extractor on a spot an ally holds, unless it goes onto that ally's extractor and utility buildings may change hands
---@field Allowed "Allowed"

---@type ConstructionPlacementPolicy
local Placement = {
	AlliedExtractorOccupied = "AlliedExtractorOccupied",
	SpotHeldByAnAlly = "SpotHeldByAnAlly",
	Allowed = "Allowed",
}

---@class ConstructionPlacementFacts: PolicyFacts<ConstructionPlacementContext>
---@field SpotHolder string the team that holds this spot; the builder itself when nobody else does
---@field UtilitySharing string whether utility buildings may change hands between allies; false when nobody says

---@type ConstructionPlacementFacts
local PlacementFacts = {
	SpotHolder = "spotHolder",
	UtilitySharing = "utilitySharing",
}

---@class ConstructionCreationContext may this team create this def at all: the build option, not one step of it
---@field unitDefID integer
---@field unitDef table
---@field teamID integer
---@field tier integer|nil the team's tech tier, a fact tech provides; nil when no tier system is live

---@class ConstructionCreationPolicy: PolicySteps<ConstructionCreationContext, boolean>
---@field Allowed "Allowed"

---@type ConstructionCreationPolicy
local Creation = {
	Allowed = "Allowed",
}

---@class ConstructionCreationFacts: PolicyFacts<ConstructionCreationContext>
---@field Tier string the team's tech tier; nil when no tier system is live

---@type ConstructionCreationFacts
local CreationFacts = {
	Tier = "tier",
}

---@class ConstructionContract
---@field Assist ConstructionAssistPolicy
---@field Reclaim ConstructionReclaimPolicy
---@field Resurrect ConstructionResurrectPolicy
---@field Build ConstructionBuildPolicy
---@field Placement ConstructionPlacementPolicy
---@field PlacementFacts ConstructionPlacementFacts
---@field Creation ConstructionCreationPolicy
---@field CreationFacts ConstructionCreationFacts

return Policy.Contract(Modules.Construction, {
	Assist = Policy.Single(Assist),
	Reclaim = Policy.Single(Reclaim),
	Resurrect = Policy.Single(Resurrect),
	Build = Policy.Single(Build),
	Placement = Policy.Single(Placement),
	PlacementFacts = Policy.Facts(PlacementFacts),
	Creation = Policy.Single(Creation),
	CreationFacts = Policy.Facts(CreationFacts),
})
