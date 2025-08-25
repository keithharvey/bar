local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Framework',
		desc    = 'Loads TeamTransfer API and policies, handles Allow* callins, exposes via GG.TeamTransfer',
		author  = 'Devin',
		layer   = -1001,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")

-- Spring function shortcuts
local spGetPlayerInfo = Spring.GetPlayerInfo

function gadget:Initialize()
	---@type TeamTransferAPI
	GG.TeamTransfer = {
		RegisterPolicy = TeamTransfer.RegisterPolicy,
		PolicyType = TeamTransfer.PolicyType,
		UnitSharing = TeamTransfer.UnitSharing,
		ResourceShareTax = TeamTransfer.ResourceShareTax,
		Predicates = TeamTransfer.Predicates,
		MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS,
		IsSharingOption = TeamTransfer.IsSharingOption,
		Units = TeamTransfer.Units,
		getUnitSharingMode = TeamTransfer.UnitSharing.getUnitSharingMode,
		isT2ConstructorDef = TeamTransfer.UnitSharing.isT2ConstructorDef,
		countUnshareable = TeamTransfer.UnitSharing.countUnshareable,
		shouldShowShareButton = TeamTransfer.UnitSharing.shouldShowShareButton,
		blockMessage = TeamTransfer.UnitSharing.blockMessage,
		computeTransfer = TeamTransfer.ResourceShareTax.computeTransfer,
	}
	
	local policyFiles = VFS.DirList("luarules/gadgets/team_transfer/policies/", "*.lua")
	for _, policyFile in ipairs(policyFiles) do
		VFS.Include(policyFile)
	end
	
	-- Initialize player monitoring
	local players = Spring.GetPlayerList()
	for _, playerID in pairs(players) do
		local _, active, spec, teamID = spGetPlayerInfo(playerID, false)
		local leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID)
		if isDead == 0 and not isAiTeam then
			if active and not spec then
				monitorPlayers[playerID] = true
			end
		end
	end
end

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	return Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	return Pipeline.RunAllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	return Pipeline.RunAllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
end

-- Player monitoring for team abandonment events
local monitorPlayers = {}

function gadget:GameFrame(gameFrame)
	-- Check player activity every 30 frames to reduce overhead
	if gameFrame % 30 == 0 then
		local active, spec, teamID
		for playerID, prevActive in pairs(monitorPlayers) do
			_, active, spec, teamID = spGetPlayerInfo(playerID, false)
			if spec then
				-- Player went spectator - trigger abandonment event
				Pipeline.RunTeamEvent("PlayerAbandoned", teamID, playerID, gameFrame)
				monitorPlayers[playerID] = nil
			elseif active ~= prevActive then
				if not active then
					-- Player disconnected - trigger abandonment event
					Pipeline.RunTeamEvent("PlayerAbandoned", teamID, playerID, gameFrame)
				elseif active and not prevActive then
					-- Player reconnected
					Pipeline.RunTeamEvent("PlayerReconnected", teamID, playerID, gameFrame)
				end
				monitorPlayers[playerID] = active
			end
		end
	end
end

function gadget:PlayerAdded(playerID)
	local _, active, spec, teamID = spGetPlayerInfo(playerID, false)
	local leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID)
	if isDead == 0 and not isAiTeam then
		if active and not spec then
			monitorPlayers[playerID] = true
		end
	end
end

function gadget:PlayerRemoved(playerID, reason)
	local _, _, spec, teamID = spGetPlayerInfo(playerID, false)
	if monitorPlayers[playerID] and not spec then
		Pipeline.RunTeamEvent("PlayerAbandoned", teamID, playerID, Spring.GetGameFrame())
	end
	monitorPlayers[playerID] = nil
end