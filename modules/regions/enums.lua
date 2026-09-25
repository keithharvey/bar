---@class RegionEnums
---@field Geometry RegionGeometryFields
---@field Types RegionTypeFields
local M = {}

---@alias RegionGeometryKey "point"|"polygon"
---@class RegionGeometryFields
---@field Point "point"
---@field Polygon "polygon"

---@type RegionGeometryFields
M.Geometry = {
	Point = "point",
	Polygon = "polygon",
}

---@alias RegionTypeKey "start"|"mex_region"
---@class RegionTypeFields
---@field Start "start"
---@field MexRegion "mex_region"

---@type RegionTypeFields
M.Types = {
	Start = "start",
	MexRegion = "mex_region",
}

return M
