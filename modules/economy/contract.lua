local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local RegionsContract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract

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

---@class MexRegion: Region one of the layout's regions, in elmos: an area whose metal is dealt to the teams seated at one start
---@field type "mex_region"
---@field id string name@team, unique in the layout
---@field name string given by the map, or derived from the group at load
---@field team integer the start ordinal the region belongs to: start 1 is team 1
---@field group string what the region is for on this map: "anti", "tech"
---@field vertices { x: number, z: number }[]

---@class MexRegionsTeamStart a team, seated at a start
---@field teamID integer
---@field allyTeam integer the start ordinal the team plays from: ally team 0 is 1
---@field x number where the team starts from: its start area's centre
---@field z number

---@class MexRegionsDealContext what the deal is made from: the layout, the map's metal, and who sits where
---@field regions MexRegion[] the layout's regions
---@field spots { x: number, z: number }[] the map's metal spots; a mex is judged by the spot it mines
---@field teams MexRegionsTeamStart[] the order the deal goes round

---@class MexRegionsDeal who holds what; empty when the deal was refused, and problems say why
---@field regions table<string, integer> the team holding each region, by region id
---@field spots table<string, integer> the team holding each metal spot, by spot key: the claims a mex is judged by
---@field problems string[] why there is no deal; empty when there is one

---@class EconomyMexRegionsStages: PolicyStages<MexRegionsDealContext, MexRegionsDeal>
---@field LayoutChecksOut string the layout passes the regions module's set check for mex regions: each region whole and fielded, no two sharing ground, every spot covered
---@field SpotsKnown string the map has metal spots; a metal map has nothing to deal
---@field NearestRoundRobin string a region goes round the teams seated at its start, nearest first; one whose start is empty this match goes round every team

---@type EconomyMexRegionsStages
local MexRegions = {
	LayoutChecksOut = "LayoutChecksOut",
	SpotsKnown = "SpotsKnown",
	NearestRoundRobin = "NearestRoundRobin",
}

---@class EconomyMexRegionsSetStages what economy adds to the regions module's set check, for its own type
---@field MexesCovered string every metal spot the asker knows lies inside a mex region

---@type EconomyMexRegionsSetStages
local MexRegionsSet = {
	MexesCovered = "MexesCovered",
}

---@class EconomyPipelines what LoadPolicies("economy") hands back
---@field mex_regions AssembledPipeline<MexRegionsDealContext, MexRegionsDeal>

---@class EconomyContract
---@field Distribution EconomyDistributionFacts
---@field Redistribution EconomyRedistributionFacts
---@field MexRegions EconomyMexRegionsStages
---@field MexRegionsSet EconomyMexRegionsSetStages

return PolicyBuilder.Contract(Modules.Economy, {
	Distribution = PolicyBuilder.Facts(Distribution),
	Redistribution = PolicyBuilder.Facts(Redistribution),
	MexRegions = PolicyBuilder.Single(MexRegions),
	MexRegionsSet = PolicyBuilder.Contributes(RegionsContract.CheckSet, MexRegionsSet),
})
