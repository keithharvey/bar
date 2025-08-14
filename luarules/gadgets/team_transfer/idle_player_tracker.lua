if Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Idle Player Tracker",
		desc      = "Tracks active players for team transfer system",
		author    = "Floris, TeamTransfer System",
		date      = "2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GetPlayerInfo = Spring.GetPlayerInfo
local GetPlayerList = Spring.GetPlayerList
local GetTeamList = Spring.GetTeamList
local GetTeamRulesParam = Spring.GetTeamRulesParam
local SetTeamRulesParam = Spring.SetTeamRulesParam
local GetGameFrame = Spring.GetGameFrame

local numActivePlayers = {}

local function UpdateActivePlayerCount()
	local teams = GetTeamList()
	for _, teamID in ipairs(teams) do
		numActivePlayers[teamID] = 0
	end
	
	local players = GetPlayerList()
	for _, playerID in ipairs(players) do
		local _, active, spec, teamID = GetPlayerInfo(playerID, false)
		if active and not spec and teamID then
			numActivePlayers[teamID] = (numActivePlayers[teamID] or 0) + 1
		end
	end
	
	for teamID, count in pairs(numActivePlayers) do
		SetTeamRulesParam(teamID, "numActivePlayers", count)
	end
end

function gadget:PlayerChanged(playerID)
	UpdateActivePlayerCount()
end

function gadget:PlayerAdded(playerID)
	UpdateActivePlayerCount()
end

function gadget:PlayerRemoved(playerID, reason)
	UpdateActivePlayerCount()
end

function gadget:Initialize()
	UpdateActivePlayerCount()
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 900 == 0 then
		UpdateActivePlayerCount()
	end
end
