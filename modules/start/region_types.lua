local Enums = VFS.Include("modules/regions/enums.lua")

return {
	[Enums.Types.Start] = {
		key = Enums.Types.Start,
		label = "Start",
		geometries = { Enums.Geometry.Point, Enums.Geometry.Polygon },
		order = 10,
		fields = {
			{ key = "allyTeam", label = "Ally team", kind = "integer", required = true },
			{ key = "name", label = "Label", kind = "string" },
		},
	},
}
