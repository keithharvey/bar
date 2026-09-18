local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mex Splitting",
		desc = "Under Map Assigned mex income: the map's regions in their holders' colours, pregame and whenever a mex is being placed",
		author = "BAR modules",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

local TransferEnums = VFS.Include("modules/transfer/enums.lua")
if Spring.GetModOptions()[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.MapAssigned then
	return false
end

local Deal = VFS.Include("modules/transfer/mex_splitting/deal.lua") ---@type MexRegionsDealLib
local Shared = VFS.Include("modules/transfer/mex_splitting/shared.lua") ---@type MexRegionsShared
local Claims = VFS.Include("modules/transfer/mex_splitting/claims.lua") ---@type MexRegionsClaimsLib
local readDeal = Deal.Reader()

-- No deal by the time the UI loads means the match found no layout. If this player has drawn one for the map in the
-- terraformer, hand it to the gadget, which takes it only from a lone player before the start.
function widget:Initialize()
	if Spring.GetGameFrame() > 0 or Spring.GetGameRulesParam(Deal.PARAM) ~= nil then
		return
	end
	local Sources = VFS.Include("modules/transfer/mex_splitting/sources.lua") ---@type MexRegionSources
	local blob = Sources.EditorBlob(Game.mapName, Game.mapSizeX, Game.mapSizeZ)
	if blob then
		Spring.Echo("[Mex Splitting] offering this map's terraformer layout to the match")
		Spring.SendLuaRulesMsg(Shared.LAYOUT_MSG .. blob)
	end
end

local glColor = gl.Color
local glLineWidth = gl.LineWidth

local isMex = {} ---@type table<integer, boolean>
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
end

local function placingAMex()
	local _, cmdID = Spring.GetActiveCommand()
	return cmdID ~= nil and (cmdID == GameCMD.AREA_MEX or (cmdID < 0 and isMex[-cmdID] == true))
end

local function showing()
	return Spring.GetGameFrame() <= 0 or placingAMex()
end

local BUILDABLE = { 0.3, 1.0, 0.3 } -- the same green the game gives a spot you may take
local DULL = 0.6 -- an ally's spot is context: their colour, turned down
local SPOT_RING = Game.extractorRadius or 80

---@param teamID integer
---@return string
local function holderName(teamID)
	local players = Spring.GetPlayerList(teamID)
	local name = players and players[1] and Spring.GetPlayerInfo(players[1], false) or nil
	return name or ("team " .. teamID)
end

---@param teamID integer
---@return number[]
local function allyColour(teamID)
	local r, g, b = Spring.GetTeamColor(teamID)
	if not r or (r + g + b) < 0.15 then
		return { 0.6, 0.6, 0.6 } -- no colour yet, or one too dark to read against the ground
	end
	return { r * DULL, g * DULL, b * DULL }
end

---@return { x: number, z: number }[]
local function metalSpots()
	local finder = WG.resource_spot_finder
	return finder and not finder.isMetalMap and finder.metalSpotsList or {}
end

-- Who holds each metal spot, by spot key, worked out from the deal the gadget publishes for everyone: the same
-- regions, the same holders, the same containment the deal itself used. Rebuilt when the deal changes.
local spotHolders = {} ---@type table<string, integer[]>
local builtFor = nil ---@type MexRegionsDealRecord|nil
local function refreshHolders()
	local deal = readDeal(Spring)
	if deal == builtFor then
		return
	end
	builtFor = deal
	spotHolders = {}
	if deal == nil then
		return
	end
	for id, keys in pairs(Claims.SpotsIn(deal.regions, metalSpots())) do
		local holder = deal.holders[id]
		if holder ~= nil then
			for _, key in ipairs(keys) do
				spotHolders[key] = spotHolders[key] or {}
				table.insert(spotHolders[key], holder)
			end
		end
	end
end

local sinceRead = math.huge
function widget:Update(dt)
	sinceRead = sinceRead + dt
	if sinceRead >= 0.5 then
		sinceRead = 0
		refreshHolders()
	end
end

-- While a mex is being placed, and before the start: every metal spot wears a ring. Green is a spot I may build on,
-- which is my own, the enemy's, and any nobody holds. A spot an ally holds wears that ally's colour.
function widget:DrawWorldPreUnit()
	if not showing() or next(spotHolders) == nil then
		return -- no deal this match: nothing is restricted, so there is nothing to say
	end
	local myTeamID = Spring.GetMyTeamID()
	-- Whatever drew before may have left a texture bound, and a bound texture turns every line black.
	gl.Texture(false)
	gl.DepthTest(false)
	gl.Blending(true)
	glLineWidth(2.0)
	for _, spot in ipairs(metalSpots()) do
		local holders = spotHolders[Shared.SpotKey(spot.x, spot.z)]
		local c = BUILDABLE
		if holders ~= nil and not table.contains(holders, myTeamID) then
			for _, holder in ipairs(holders) do
				if Spring.AreTeamsAllied(myTeamID, holder) then
					c = allyColour(holder)
					break
				end
			end
		end
		glColor(c[1], c[2], c[3], 0.9)
		gl.DrawGroundCircle(spot.x, 0, spot.z, SPOT_RING, 32)
	end
	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
end

-- Over a spot another team holds, while a mex is being placed: say whose it is, in the game's own tooltip.
local function explainSpotUnderCursor()
	if not (placingAMex() and WG.tooltip and WG.tooltip.ShowTooltip) then
		return
	end
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if not pos then
		return
	end
	local reach = (Game.extractorRadius or 80) ^ 2
	for _, spot in ipairs(metalSpots()) do
		if (spot.x - pos[1]) ^ 2 + (spot.z - pos[3]) ^ 2 <= reach then
			local holders = spotHolders[Shared.SpotKey(spot.x, spot.z)]
			if holders ~= nil and not table.contains(holders, Spring.GetMyTeamID()) then
				local names = {}
				for _, holder in ipairs(holders) do
					if Spring.AreTeamsAllied(Spring.GetMyTeamID(), holder) then
						names[#names + 1] = holderName(holder)
					end
				end
				if #names == 0 then
					return
				end
				WG.tooltip.ShowTooltip(
					"mex_regions",
					"This metal spot belongs to " .. table.concat(names, " and ") .. ": Mex Splitting is Map Assigned."
				)
			end
			return
		end
	end
end

function widget:DrawScreenEffects()
	if showing() then
		explainSpotUnderCursor()
	end
end
