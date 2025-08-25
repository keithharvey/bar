function setup()
	_G.VFS = _G.VFS or {}
	_G.Spring = _G.Spring or {}
	_G.CMD = _G.CMD or {}
	
	CMD.REMOVE = 1
	CMD.LOAD_UNITS = 2
	CMD.SELFD = 3
	
	VFS.Include = function(path)
		if path:match("api_gadgets") then
			return {
				PolicyType = {
					ResourceTransfer = "ResourceTransfer",
					UnitTransfer = "UnitTransfer",
					Command = "Command",
					TeamEvent = "TeamEvent"
				},
				GetPolicies = function()
					return {
						ResourceTransfer = {},
						UnitTransfer = {},
						Command = {},
						TeamEvent = {}
					}
				end,
				GetPipeline = function()
					return {
						onAllowResourceTransfer = {},
						onAllowUnitTransfer = {},
						onAllowCommand = {}
					}
				end
			}
		elseif path:match("resources") then
			return {
				NormalizeResourceName = function(resourceType)
					if resourceType == 'm' then return 'metal' end
					if resourceType == 'e' then return 'energy' end
					return resourceType
				end,
				ComputeMaxShare = function(receiverTeamId, resourceName)
					return 1000, 500
				end
			}
		elseif path:match("state") then
			return {
				GetCumulativeMetalSent = function(teamID)
					return 0
				end,
				AddCumulativeMetalSent = function(teamID, amount)
					return amount
				end
			}
		elseif path:match("pipeline") then
			return {
				RunAllowResourceTransfer = function(senderTeamID, receiverTeamID, resource, amount)
					return true
				end,
				RunAllowUnitTransfer = function(unitID, unitDefID, fromTeamID, toTeamID, capture)
					if capture then return true end
					return true
				end,
				RunAllowCommand = function(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, playerID, fromSynced)
					return true
				end,
				RunTeamEvent = function(eventType, teamID, playerID, frame)
					return
				end
			}
		end
		return {}
	end
	
	Spring.GetGaiaTeamID = function() return 255 end
	Spring.GetTeamInfo = function(teamID, detailed)
		return "Team", 0, 0, false
	end
	Spring.GetTeamLuaAI = function(teamID) return nil end
	Spring.AreTeamsAllied = function(team1, team2) return team1 == team2 end
	Spring.IsCheatingEnabled = function() return false end
	Spring.GetTeamResources = function(teamID, resourceName)
		return 500, 1000, 0, 0, 0, 1.0
	end
	Spring.SetTeamResource = function(teamID, resourceName, amount) end
	Spring.SetTeamRulesParam = function(teamID, param, value) end
	Spring.GetPlayerList = function() return {1} end
	Spring.GetPlayerInfo = function(playerID)
		return "Player", true, false, 1
	end
	Spring.GetUnitCommands = function(unitID)
		return {}
	end
	Spring.GiveOrderToUnit = function(unitID, cmdID, params, options) end
	Spring.GetUnitSelfDTime = function(unitID) return 0 end
	Spring.GetUnitHealth = function(unitID)
		return 100, 100, 0, 0, 1.0
	end
	Spring.GetUnitTeam = function(unitID) return 1 end
	Spring.GetUnitDefID = function(unitID) return 1 end
	
	_G.UnitDefs = { [1] = { name = "testunit" } }
end

function cleanup()
	_G.VFS = nil
	_G.Spring = nil
	_G.CMD = nil
	_G.UnitDefs = nil
end

function test()
	local Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
	
	assert(type(Pipeline.RunAllowResourceTransfer) == "function", "Should expose RunAllowResourceTransfer function")
	assert(type(Pipeline.RunAllowUnitTransfer) == "function", "Should expose RunAllowUnitTransfer function")
	assert(type(Pipeline.RunAllowCommand) == "function", "Should expose RunAllowCommand function")
	assert(type(Pipeline.RunTeamEvent) == "function", "Should expose RunTeamEvent function")
	
	local resourceResult = Pipeline.RunAllowResourceTransfer(1, 2, "metal", 100)
	assert(type(resourceResult) == "boolean", "Should return boolean for resource transfer")
	
	local unitResult = Pipeline.RunAllowUnitTransfer(123, 1, 1, 2, false)
	assert(type(unitResult) == "boolean", "Should return boolean for unit transfer")
	
	local commandResult = Pipeline.RunAllowCommand(123, 1, 1, 10, {456}, {}, 1, true)
	assert(type(commandResult) == "boolean", "Should return boolean for command")
	
	Pipeline.RunTeamEvent("PlayerAbandoned", 1, 1, 100)
	
	local captureResult = Pipeline.RunAllowUnitTransfer(123, 1, 1, 2, true)
	assert(captureResult == true, "Should always allow capture transfers")
	
	local zeroResourceResult = Pipeline.RunAllowResourceTransfer(1, 2, "metal", 0)
	assert(type(zeroResourceResult) == "boolean", "Should handle zero resource transfers")
	
	local energyResult = Pipeline.RunAllowResourceTransfer(1, 2, "energy", 100)
	assert(type(energyResult) == "boolean", "Should handle energy transfers")
	
	local shortFormResult = Pipeline.RunAllowResourceTransfer(1, 2, "m", 100)
	assert(type(shortFormResult) == "boolean", "Should handle short form resource names")
end
