local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local RegionsApi = require("modules/regions/api")

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

---@class (partial) TransferContract
---@field MexRegionsSet TransferMexRegionsSetSteps
---@field MexRegionsNames TransferMexRegionsNamesSteps
---@field MexRegionsDescribe TransferMexRegionsDescribeSteps

---@class (partial) RegionMap
---@field spots { x: number, z: number, worth: number|nil }[]|nil

---@class TransferMexRegionsSetSteps
---@field MexesCovered string

---@type TransferMexRegionsSetSteps
local MexRegionsSet = Policy.Contributes(Regions.CheckSet, {
	MexesCovered = "MexesCovered",
})

---@class TransferMexRegionsNamesSteps
---@field FromGroup string

---@type TransferMexRegionsNamesSteps
local MexRegionsNames = Policy.Contributes(Regions.Names, {
	FromGroup = "FromGroup",
})

---@class MexRegionDescription: RegionDescription
---@field team integer
---@field group string
---@field spots integer|nil
---@field worth number|nil

---@class TransferMexRegionsDescribeSteps
---@field MexRegion string

---@type TransferMexRegionsDescribeSteps
local MexRegionsDescribe = Policy.Contributes(Regions.Describe, {
	MexRegion = "MexRegion",
})

Policies.On(Regions.Names).Apply(MexRegionsNames.FromGroup, function(ctx)
	if ctx.type.key ~= RegionsApi.Enums.Types.MexRegion then
		return
	end
	for i, region in ipairs(ctx.regions) do
		---@cast region MexRegion
		local group = region.group
		if group ~= nil and group ~= "" then
			ctx.bases[i] = tostring(group)
		end
	end
end)

Policies.On(Regions.CheckSet).Apply(MexRegionsSet.MexesCovered, function(ctx)
	local spots = ctx.map.spots
	if ctx.type.key ~= RegionsApi.Enums.Types.MexRegion or spots == nil then
		return
	end
	local uncovered, first = 0, nil
	for _, spot in ipairs(spots) do
		local covered = false
		for _, region in ipairs(ctx.regions) do
			covered = covered or (region.vertices ~= nil and RegionsApi.Contains(spot.x, spot.z, region.vertices))
		end
		if not covered then
			uncovered = uncovered + 1
			first = first or { x = spot.x, z = spot.z }
		end
	end
	if uncovered > 0 then
		RegionsApi.ProblemAt(
			ctx,
			uncovered .. " metal spot" .. (uncovered == 1 and "" or "s") .. " in no mex region",
			first
		)
	end
end)

Policies.On(Regions.Describe)
	.Answer(MexRegionsDescribe.MexRegion, function(ctx)
		if ctx.type.key ~= RegionsApi.Enums.Types.MexRegion then
			return nil
		end
		local region = ctx.region --[[@as MexRegion]]
		---@type MexRegionDescription
		local description =
			{ area = ctx.shape.area, centre = ctx.shape.centre, team = region.team, group = region.group }
		local spots = ctx.map.spots
		if spots and region.vertices then
			local count, worth = 0, 0.0
			for _, spot in ipairs(spots) do
				if RegionsApi.Contains(spot.x, spot.z, region.vertices) then
					count = count + 1
					worth = worth + (spot.worth or 0)
				end
			end
			-- a thousandth of the metal map's sum is what the game floats over a spot: a T1 mex's income
			description.spots, description.worth = count, worth / 1000
		end
		return description
	end)
	.Before(Regions.Describe.Shape)

return { MexRegionsSet = MexRegionsSet, MexRegionsNames = MexRegionsNames, MexRegionsDescribe = MexRegionsDescribe }
