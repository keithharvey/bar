local Enums = require("modules/regions/enums")
local Fields = require("modules/start/fields")

return {
	[Enums.Types.Start] = {
		key = Enums.Types.Start,
		label = "Start",
		geometries = { Enums.Geometry.Point, Enums.Geometry.Polygon },
		fields = {
			Fields.Team({ required = true, unique = true }),
			{ key = "name", label = "Label", kind = "string" },
		},
	},
}
