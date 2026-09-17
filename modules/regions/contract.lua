local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class Region contained space on the map: the shape, and nothing a type adds. A type's own record extends it, in the module that owns the type
---@field type RegionTypeKey
---@field vertices { x: number, z: number }[]|nil the shape, elmos: one vertex is a point, three or more a polygon, see RegionGeometry.Of; absent while the region is still being drawn
---@field tags string[]|nil what no type has claimed yet
---@field name string|nil what the region is called; when absent the type derives one, see RegionsApi.Names

---@class RegionEnv what the map knows around the regions, when the asker has it
---@field spots { x: number, z: number, worth: number|nil }[]|nil the map's metal spots
---@field starts { allyTeam: integer, x: number, z: number }[]|nil the map's start positions

---@class RegionCheckContext one region on its way through the rules; problems collect, so a form can show them all
---@field type RegionType the descriptor the region claims
---@field region Region
---@field siblings Region[] the other regions of the same type
---@field names table<Region, string> what the region and each sibling are called, derived where they carry no name
---@field fieldsOnly boolean|nil the region has no shape yet: check what it will carry, not what it is
---@field problems string[]

---@class RegionCheckStages: PolicyStages<RegionCheckContext, RegionCheckContext>
---@field Shape string the region is drawn as a shape its type allows, and the shape is whole
---@field Fields string required fields are present; unique fields are unique among siblings
---@field Disjoint string a type that declares disjoint never has two regions sharing ground

---@type RegionCheckStages
local Check = {
	Shape = "Shape",
	Fields = "Fields",
	Disjoint = "Disjoint",
}

---@class RegionSetContext every region of one type together, on its way through the rules that judge the set; problems collect
---@field type RegionType
---@field regions Region[]
---@field names string[] what each region is called, by index, derived where it carries no name
---@field env RegionEnv
---@field problems string[]

---@class RegionSetStages: PolicyStages<RegionSetContext, RegionSetContext> the set's rules; a type's owner contributes its own, such as what the set must cover
---@field Each string every region passes its type's Check against its siblings; a problem names its region

---@type RegionSetStages
local CheckSet = {
	Each = "Each",
}

---@class RegionFactsContext what the facts are computed from: the region, and what the map knows around it
---@field region Region
---@field spots { x: number, z: number, worth: number|nil }[]|nil the map's metal spots, when the asker has them
---@field starts { allyTeam: integer, x: number, z: number }[]|nil the map's start positions, when the asker has them

---@class RegionFacts: PolicyFacts<RegionFactsContext>
---@field Area string elmos squared; 0 for a point
---@field Centre string { x, z }: the vertex centroid, or the point itself
---@field MetalSpots string { count, worth } inside the region; nil when the asker knew no spots
---@field NearestStart string { allyTeam, distance } from the centre; nil when the asker knew no starts

---@type RegionFacts
local Facts = {
	Area = "area",
	Centre = "centre",
	MetalSpots = "metalSpots",
	NearestStart = "nearestStart",
}

---@class RegionsPipelines what LoadPolicies("regions") hands back
---@field check AssembledPipeline<RegionCheckContext, RegionCheckContext>
---@field check_set AssembledPipeline<RegionSetContext, RegionSetContext>

---@class RegionsContract
---@field Check RegionCheckStages
---@field CheckSet RegionSetStages
---@field Facts RegionFacts

return PolicyBuilder.Contract(Modules.Regions, {
	Check = PolicyBuilder.Fold(Check),
	CheckSet = PolicyBuilder.Fold(CheckSet),
	Facts = PolicyBuilder.Facts(Facts),
})
