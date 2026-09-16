local Enums = VFS.Include("modules/regions/enums.lua")
local Fields = VFS.Include("modules/regions/fields.lua") ---@type RegionFields

return {
	[Enums.Types.Start] = {
		key = Enums.Types.Start,
		label = "Start",
		geometries = { Enums.Geometry.Point, Enums.Geometry.Polygon },
		order = 10,
		fields = {
			Fields.With(Fields.Team, { required = true }),
			{ key = "name", label = "Label", kind = "string" },
		},
	},
}
