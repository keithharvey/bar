local Enums = VFS.Include("modules/regions/enums.lua")

-- The region type economy owns: a named area whose metal is dealt to one team under Map Assigned.
return {
	[Enums.Types.MexRegion] = {
		key = Enums.Types.MexRegion,
		label = "Mex region",
		geometries = { Enums.Geometry.Polygon },
		layoutKey = "regions",
		disjoint = true, -- the deal gives a spot one holder
		order = 20,
		fields = {
			{ key = "name", label = "Name", kind = "string", unique = true },
			{ key = "group", label = "Group", kind = "string" },
		},
	},
}
