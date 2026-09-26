local Enums = require("modules/regions/enums")
local Fields = require("modules/start/fields")

-- A start: the map's Nth seat, drawn as the area its positions lie in, or a point.
---@class StartRegion: Region
---@field type "start"
---@field team integer
---@field positions { x: number, z: number }[]|nil
---@field allyTeamID integer|nil the ally team seated here, once the match has resolved it
---@field source string|nil where the match's shape came from: the modoption that set it, or "engine"

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
