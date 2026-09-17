local Deal = require("modules/transfer/mex_splitting/deal")
local Geometry = require("modules/regions/lib/geometry")

---@class MexRegionsHolders who holds a place on the map, read from the deal the gadget publishes for everyone: the same answer in a gadget, a policy and a widget
local Holders = {}

local read = Deal.Reader(Game.mapSizeX, Game.mapSizeZ)

---@param springRepo Spring
---@param x number
---@param z number
---@return integer[] the teams holding a region that covers x, z, in layout order; none when there is no deal
function Holders.At(springRepo, x, z)
	local deal = read(springRepo)
	local out = {} ---@type integer[]
	for _, region in ipairs(deal and deal.regions or {}) do
		local holder = deal.holders[region.id]
		if holder ~= nil and not table.contains(out, holder) and Geometry.Contains(x, z, region.vertices) then
			out[#out + 1] = holder
		end
	end
	return out
end

return Holders
