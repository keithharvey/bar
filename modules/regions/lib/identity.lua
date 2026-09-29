---@class RegionIdentity
local Identity = {}

---@return string
function Identity.Mint()
	return string.format("%06x%06x", math.random(0, 0xffffff), math.random(0, 0xffffff))
end

return Identity
