local Deal = require("modules/transfer/mex_splitting/deal")
local Regions = require("modules/regions/api")

---@class MexRegionsHolders who holds a place on the map, read from the deal the gadget publishes for everyone: the same answer in a gadget, a policy and a widget
local Holders = {}

local read = Deal.Reader(Game.mapSizeX, Game.mapSizeZ)

---@param springRepo Spring
---@param x number
---@param z number
---@return integer[] the teams holding a region that covers x, z, in layout order; none when there is no deal
function Holders.At(springRepo, x, z)
	local out = {} ---@type integer[]
	local deal = read(springRepo)
	if not deal then
		return out
	end
	for _, region in ipairs(deal.regions) do
		local holder = deal.holders[region.id]
		if holder ~= nil and not table.contains(out, holder) and Regions.Contains(x, z, region.vertices) then
			out[#out + 1] = holder
		end
	end
	return out
end

return Holders
