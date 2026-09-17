local Enums = require("modules/regions/enums")
local Fields = require("modules/start/fields")

return {
	[Enums.Types.MexRegion] = {
		key = Enums.Types.MexRegion,
		label = "Mex region",
		geometries = { Enums.Geometry.Polygon },
		fields = {
			Fields.Team({ required = true }),
			{ key = "group", label = "Group", kind = "string", required = true, suggest = true },
			{ key = "name", label = "Name", kind = "string" },
		},
	},
}
