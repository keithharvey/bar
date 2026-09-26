local Enums = require("modules/regions/enums")
local Fields = require("modules/start/fields")

-- A start: the map's Nth seat, drawn as the area its positions lie in, or a point when only one is drawn.
-- The fields below are what the editor and the layout carry; the class is the same record for the checker.
---@class StartRegion: Region
---@field type "start"
---@field team integer
---@field positions { x: number, z: number }[]|nil

return {
	[Enums.Types.Start] = {
		key = Enums.Types.Start,
		label = "Start",
		geometries = { Enums.Geometry.Point, Enums.Geometry.Polygon },
		fields = {
			Fields.Team({ required = true, unique = true }),
			{ key = "name", label = "Label", kind = "string" },
			{ key = "positions", label = "Positions", kind = "points" },
		},
	},
}
