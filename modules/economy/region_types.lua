local Enums = VFS.Include("modules/regions/enums.lua")
local Fields = VFS.Include("modules/start/fields.lua") ---@type StartRegionFields

return {
	[Enums.Types.MexRegion] = {
		key = Enums.Types.MexRegion,
		label = "Mex region",
		geometries = { Enums.Geometry.Polygon },
		disjoint = true,
		order = 20,
		fields = {
			{ key = "name", label = "Name", kind = "string", required = true, unique = "team" },
			Fields.Team({ required = true }),
			{ key = "group", label = "Group", kind = "string", suggest = true },
		},
	},
}
