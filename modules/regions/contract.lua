local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class Region contained space on the map, with facts attached
---@field type RegionTypeKey
---@field geometry RegionGeometryKey|nil inferred from the shape when absent: vertices make a polygon, x and z a point
---@field x number|nil a point's position, elmos
---@field z number|nil
---@field vertices { x: number, z: number }[]|nil a polygon's ring, elmos
---@field tags string[]|nil what no type has claimed yet
---@field name string|nil a field some types carry
---@field group string|nil
---@field team integer|nil the start ordinal: start 1 is team 1

---@class RegionCheckContext one region on its way through the rules; problems collect, so a form can show them all
---@field type RegionType the descriptor the region claims
---@field region Region
---@field siblings Region[] the other regions of the same type
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

---@class RegionsContract
---@field Check RegionCheckStages
---@field Facts RegionFacts

return PolicyBuilder.Contract(Modules.Regions, {
	Check = PolicyBuilder.Fold(Check),
	Facts = PolicyBuilder.Facts(Facts),
})
