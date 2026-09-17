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

---@class MexRegion: Region one of the layout's regions, in elmos: a named area whose metal is dealt to the teams seated at one start
---@field type "mex_region"
---@field id string name@team, unique in the layout
---@field name string
---@field team integer the start ordinal the region belongs to: start 1 is team 1
---@field group string|nil
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
---@field regions table<string, integer> region id -> the team that holds it
---@field spots table<string, integer> spot key -> the team that holds it: the claims a mex is judged by
---@field open string[] the spot keys no region covers; whoever builds there holds them
---@field problems string[] why there is no deal; empty when there is one

---@class EconomyMexRegionsStages: PolicyStages<MexRegionsDealContext, MexRegionsDeal>
---@field LayoutChecksOut string every region passes the regions module's Check for its type: whole, its fields present and unique, no two sharing ground
---@field SpotsKnown string the map has metal spots; a metal map has nothing to deal
---@field NearestRoundRobin string a region goes round the teams seated at its start, nearest first; one whose start is empty this match goes round every team

---@type EconomyMexRegionsStages
local MexRegions = {
	LayoutChecksOut = "LayoutChecksOut",
	SpotsKnown = "SpotsKnown",
	NearestRoundRobin = "NearestRoundRobin",
}

---@class EconomyPipelines what LoadPolicies("economy") hands back
---@field mex_regions AssembledPipeline<MexRegionsDealContext, MexRegionsDeal>

---@class EconomyContract
---@field Distribution EconomyDistributionFacts
---@field Redistribution EconomyRedistributionFacts
---@field MexRegions EconomyMexRegionsStages

return PolicyBuilder.Contract(Modules.Economy, {
	Distribution = PolicyBuilder.Facts(Distribution),
	Redistribution = PolicyBuilder.Facts(Redistribution),
	MexRegions = PolicyBuilder.Single(MexRegions),
})
