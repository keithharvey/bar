local Enums = VFS.Include("modules/regions/enums.lua")
local Fields = VFS.Include("modules/regions/fields.lua") ---@type RegionFields

return {
	[Enums.Types.MexRegion] = {
		key = Enums.Types.MexRegion,
		label = "Mex region",
		geometries = { Enums.Geometry.Polygon },
		layoutKey = "regions",
		disjoint = true,
		order = 20,
		fields = {
			Fields.Team,
			{ key = "name", label = "Name", kind = "string", unique = "team" },
			{ key = "group", label = "Group", kind = "string" },
		},
	},
}
