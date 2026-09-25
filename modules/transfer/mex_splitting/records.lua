local Enums = require("modules/regions/enums")
local Regions = require("modules/regions/api")

---@class MexRegionsRecords how a parsed region becomes a MexRegion: named. Its id comes from the layout codec
local Records = {}

---@param regions Region[] mex regions as the layout codec read them
---@return MexRegion[] the same tables, each carrying its display name
function Records.From(regions)
	local names = Regions.Names(Enums.Types.MexRegion, regions)
	---@cast regions MexRegion[]
	for i, named in ipairs(names) do
		local region = regions[i]
		if region then
			region.name = named.name
		end
	end
	return regions
end

return Records
