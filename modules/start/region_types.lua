local Enums = VFS.Include("modules/regions/enums.lua")

-- A team's start: drawn as the points where its teams spawn, and as the area those sit in.
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
