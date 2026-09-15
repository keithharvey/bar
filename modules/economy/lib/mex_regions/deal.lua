-- The deal on the wire: one game rules param the synced side writes once the regions are dealt and
-- any Lua state reads back, so the placement fact needs nothing but the engine. Pure: specs round-trip it.

---@class MexRegionsDealLib
local Deal = {}

Deal.PARAM = "mex_regions_deal"

---@class MexRegionsDeal
---@field regions MexRegion[]
---@field claims MexRegionsClaims

---@param regions MexRegion[]
---@param claims MexRegionsClaims
---@return string
function Deal.Encode(regions, claims)
	return Json.encode({ regions = regions, claims = claims })
end

---@param raw string
---@return MexRegionsDeal|nil
function Deal.Decode(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, deal = pcall(Json.decode, raw)
	if not ok or type(deal) ~= "table" or type(deal.regions) ~= "table" or type(deal.claims) ~= "table" then
		return nil
	end
	return deal
end

---Reads the deal the synced side published, decoding only when the param changed.
---@return fun(springRepo: Spring): MexRegionsDeal|nil
function Deal.Reader()
	local cachedRaw, cachedDeal ---@type string|nil, MexRegionsDeal|nil
	return function(springRepo)
		local raw = springRepo.GetGameRulesParam(Deal.PARAM)
		if raw ~= cachedRaw then
			cachedRaw = raw
			cachedDeal = Deal.Decode(raw)
		end
		return cachedDeal
	end
end

return Deal
