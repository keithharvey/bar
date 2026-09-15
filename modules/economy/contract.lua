local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class EconomyTeamContext one team, asked what redistribution costs it
---@field teamId integer
---@field springRepo Spring

---@class EconomyDistributionFacts: PolicyFacts<EconomyTeamContext>
---@field TaxRate string

---@type EconomyDistributionFacts
local Distribution = {
	TaxRate = "taxRate",
}

---@class EconomyRedistributionContext one cadence tick's results, before they are published
---@field results EconomyTeamResult[]

---@class EconomyRedistributionFacts: PolicyFacts<EconomyRedistributionContext>
---@field Results string

---@type EconomyRedistributionFacts
local Redistribution = {
	Results = "results",
}

---@class MexRegion: LayoutRegion one region of the map as the regions module parsed it, in elmos

---@class MexRegionsRanked one region as a team sees it
---@field name string
---@field group string|nil
---@field distance number elmos from the team's start position to the region's centre
---@field ordinal integer 1 for the team's nearest region, 2 for the next, and so on

---@class MexRegionsTeamView a team and the regions ranked from where it starts
---@field teamID integer
---@field startX number
---@field startZ number
---@field regions MexRegionsRanked[] nearest first

---@class MexRegionsClaimsContext the deal: every team's view of every region
---@field teams MexRegionsTeamView[] the order the deal goes round
---@field regions MexRegion[]

---@alias MexRegionsClaims table<string, integer> region name -> the team that holds it

---@class EconomyMexRegionsStages: PolicyStages<MexRegionsClaimsContext, MexRegionsClaims>
---@field NearestRoundRobin string each team in turn takes its nearest unclaimed region until none are left

---@type EconomyMexRegionsStages
local MexRegions = {
	NearestRoundRobin = "NearestRoundRobin",
}

---@class EconomyPipelines what LoadPolicies("economy") hands back
---@field mex_regions AssembledPipeline<MexRegionsClaimsContext, MexRegionsClaims>

---@class EconomyContract
---@field Distribution EconomyDistributionFacts
---@field Redistribution EconomyRedistributionFacts
---@field MexRegions EconomyMexRegionsStages

return PolicyBuilder.Contract(Modules.Economy, {
	Distribution = PolicyBuilder.Facts(Distribution),
	Redistribution = PolicyBuilder.Facts(Redistribution),
	MexRegions = PolicyBuilder.Single(MexRegions),
})
