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

function gadget:Initialize()
	local regions, source, reason = MexRegions.Load(Spring)
	if regions == nil then
		reasonNone = reason and (source .. ": " .. reason) or source
		Spring.Log(TAG, LOG.WARNING, reasonNone)
		return
	end
	Spring.Log(TAG, LOG.INFO, #regions .. " regions from " .. source)
end

-- Start positions are final once every GameStart has run, so the deal waits for the first frame.
function gadget:GameFrame(frame)
	if frame ~= 1 then
		return
	end
	if reasonNone then
		tellEveryone(
			"Mex income is Map Assigned, but " .. Game.mapName .. " has no region layout, so mexes are unrestricted."
		)
		tellEveryone(TAG .. ": " .. reasonNone)
		return
	end

	local teams = {} ---@type MexRegionsTeamStart[]
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if not ignoredTeams[teamID] then
			local x, _, z = Spring.GetTeamStartPosition(teamID)
			teams[#teams + 1] = { teamID = teamID, x = x or 0, z = z or 0 }
		end
	end
	MexRegions.Deal(teams, Spring)

	-- Which regions are whose is on the map, colour-coded where a mex would go; chat says only
	-- that the rule is on, and warns when the deal left a team without a region.
	tellEveryone("Mex placement is restricted to map-assigned regions, dealt by the lobby's Mex Splitting setting.")
	local holdings = MexRegions.Holdings()
	local unheld = 0
	for _, team in ipairs(teams) do
		if holdings[team.teamID] == nil then
			unheld = unheld + 1
		end
	end
	if unheld > 0 then
		tellEveryone(
			TAG .. ": " .. Game.mapName .. " has fewer regions than teams, so " .. unheld .. " team(s) hold none."
		)
	end
end
