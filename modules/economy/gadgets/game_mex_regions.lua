local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mex Regions",
		desc = "Map Assigned mex income: deals the map's metal regions to teams at game start and publishes the deal",
		author = "BAR modules",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local EconomyEnums = VFS.Include("modules/economy/enums.lua")

if Spring.GetModOptions()[EconomyEnums.ModOptions.MexSplitting] ~= EconomyEnums.MexSplitting.MapAssigned then
	return false
end

local MexRegions = VFS.Include("modules/economy/api.lua").MexRegions ---@type EconomyMexRegionsApi
local Start = VFS.Include("modules/start/api.lua") ---@type StartApi
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

local TAG = "Mex Regions"

local ignoredTeams = { [Spring.GetGaiaTeamID()] = true } ---@type table<integer, boolean>
local scavTeamID = BAR.Utilities.GetScavTeamID()
if scavTeamID then
	ignoredTeams[scavTeamID] = true
end
local raptorTeamID = BAR.Utilities.GetRaptorTeamID()
if raptorTeamID then
	ignoredTeams[raptorTeamID] = true
end

local reasonNone ---@type string|nil

---@param message string
local function tellEveryone(message)
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		Spring.SendMessageToPlayer(playerID, message)
	end
end

---@return MexRegionsTeamStart[]
local function teamStarts()
	local centres = {} ---@type { [integer]: { x: number, z: number } }
	for _, area in ipairs(Start.Current(Spring).areas) do
		local ring = {}
		for i, a in ipairs(area.anchors) do
			ring[i] = { x = a.x, z = a.z }
		end
		local cx, cz = Geometry.Centroid(ring)
		local allyTeamID = area.allyTeam - 1 --[[@as integer]]
		centres[allyTeamID] = { x = cx, z = cz }
	end
	local teams = {} ---@type MexRegionsTeamStart[]
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if not ignoredTeams[teamID] then
			local allyTeamID = Spring.GetTeamAllyTeamID(teamID) or 0
			local centre = centres[allyTeamID] or { x = Game.mapSizeX * 0.5, z = Game.mapSizeZ * 0.5 }
			teams[#teams + 1] = { teamID = teamID, allyTeam = allyTeamID + 1, x = centre.x, z = centre.z }
		end
	end
	return teams
end

function gadget:Initialize()
	local regions, source, reason = MexRegions.Load(Spring)
	if regions == nil then
		reasonNone = reason and (source .. ": " .. reason) or source
		Spring.Log(TAG, LOG.WARNING, reasonNone)
		return
	end
	Spring.Log(TAG, LOG.INFO, #regions .. " regions from " .. source)
	local finder = GG.resource_spot_finder
	MexRegions.Deal(teamStarts(), Spring, finder and not finder.isMetalMap and finder.metalSpotsList or {})
end

function gadget:GameStart()
	if reasonNone then
		tellEveryone(
			"Mex income is Map Assigned, but " .. Game.mapName .. " has no region layout, so mexes are unrestricted."
		)
		tellEveryone(TAG .. ": " .. reasonNone)
		return
	end
	tellEveryone("Mex placement is restricted to map-assigned regions, dealt by the lobby's Mex Splitting setting.")
	local holdings = MexRegions.Holdings()
	local unheld = 0
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if not ignoredTeams[teamID] and holdings[teamID] == nil then
			unheld = unheld + 1
		end
	end
	if unheld > 0 then
		tellEveryone(
			TAG .. ": " .. Game.mapName .. " has fewer regions than teams, so " .. unheld .. " team(s) hold none."
		)
	end
end
