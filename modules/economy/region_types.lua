local Enums = VFS.Include("modules/regions/enums.lua")

return {
	[Enums.Types.MexRegion] = {
		key = Enums.Types.MexRegion,
		label = "Mex region",
		geometries = { Enums.Geometry.Polygon },
		layoutKey = "regions",
		disjoint = true,
		order = 20,
		fields = {
			{ key = "name", label = "Name", kind = "string", unique = true },
			{ key = "group", label = "Group", kind = "string" },
		},
	},
}
