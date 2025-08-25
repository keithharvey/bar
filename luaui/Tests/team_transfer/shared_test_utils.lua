local TestUtils = {}

function TestUtils.createMockSpringAPI()
	return {
		GetModOptions = function()
			return {}
		end,
		GetGaiaTeamID = function() return 255 end,
		GetTeamInfo = function(teamID, detailed)
			return "Team", 0, 0, false
		end,
		GetTeamLuaAI = function(teamID) return nil end,
		AreTeamsAllied = function(team1, team2) return team1 == team2 end,
		IsCheatingEnabled = function() return false end,
		GetTeamResources = function(teamID, resourceName)
			return 500, 1000, 0, 0, 0, 1.0
		end,
		SetTeamResource = function(teamID, resourceName, amount) end,
		SetTeamRulesParam = function(teamID, param, value) end,
		GetPlayerList = function() return {1} end,
		GetPlayerInfo = function(playerID)
			return "Player", true, false, 1
		end,
		GetUnitCommands = function(unitID)
			return {}
		end,
		GiveOrderToUnit = function(unitID, cmdID, params, options) end,
		GetUnitSelfDTime = function(unitID) return 0 end,
		GetUnitHealth = function(unitID)
			return 100, 100, 0, 0, 1.0
		end,
		GetUnitTeam = function(unitID) return 1 end,
		GetUnitDefID = function(unitID) return 1 end
	}
end

function TestUtils.createMockVFS()
	return {
		Include = function(path)
			return {}
		end,
		FileExists = function(path)
			return false
		end,
		LoadFile = function(path)
			return nil
		end
	}
end

function TestUtils.createMockGadgetHandler()
	return {
		IsSyncedCode = function() return true end
	}
end

function TestUtils.createMockTeamTransfer(policySpy)
	return {
		MODOPTION_KEYS = {
			ALLY_ASSIST_MODE = "game_assist_ally",
			ENEMY_RESOURCE_TRANSFER = "game_enemy_resource_transfer",
			ENEMY_UNIT_TRANSFER = "game_enemy_unit_transfer",
			UNIT_SHARING_MODE = "game_unit_sharing_mode",
			RESOURCE_SHARE_TAX = "game_resource_share_tax",
			RESOURCE_SHARE_TAX_THRESHOLD = "game_resource_share_tax_threshold",
			SYSTEM_CLEANUP = "game_system_cleanup"
		},
		IsSharingOption = function(key)
			local modOpts = Spring.GetModOptions()
			local value = modOpts[key]
			if value == nil then
				return false, nil
			end
			return true, value
		end,
		RegisterPolicy = function(fn)
			return policySpy.RegisterPolicy(fn)
		end
	}
end

function TestUtils.createMockTeamTransferAPI()
	local registeredPolicies = {}
	
	return {
		MODOPTION_KEYS = {
			ALLY_ASSIST_MODE = "game_assist_ally",
			ENEMY_RESOURCE_TRANSFER = "game_enemy_resource_transfer",
			ENEMY_UNIT_TRANSFER = "game_enemy_unit_transfer",
			UNIT_SHARING_MODE = "game_unit_sharing_mode",
			RESOURCE_SHARE_TAX = "game_resource_share_tax"
		},
		IsSharingOption = function(key)
			local modOpts = Spring.GetModOptions()
			local value = modOpts[key]
			return value ~= nil, value
		end,
		RegisterPolicy = function(fn)
			table.insert(registeredPolicies, fn)
			local mockPolicy = TestUtils.createMockPolicyBuilder()
			fn(mockPolicy)
		end,
		GetRegisteredPolicies = function()
			return registeredPolicies
		end
	}
end

function TestUtils.createMockPolicyBuilder()
	local denyCalls = {}
	local allowCalls = {}
	
	return {
		ForAlliedCommands = {
			WhenGuard = { 
				Deny = function() 
					table.insert(denyCalls, "AlliedCommands.WhenGuard.Deny")
				end 
			},
			WhenRepair = { 
				Deny = function() 
					table.insert(denyCalls, "AlliedCommands.WhenRepair.Deny")
				end 
			}
		},
		ForEnemyResourceTransfer = {
			Deny = function()
				table.insert(denyCalls, "EnemyResourceTransfer.Deny")
			end,
			Allow = function()
				table.insert(allowCalls, "EnemyResourceTransfer.Allow")
			end
		},
		ForEnemyUnitTransfer = {
			Deny = function()
				table.insert(denyCalls, "EnemyUnitTransfer.Deny")
			end,
			Allow = function()
				table.insert(allowCalls, "EnemyUnitTransfer.Allow")
			end
		},
		Use = {
			UnitSharingMode = {
				SetMode = function(mode)
					table.insert(allowCalls, "UnitSharingMode.SetMode(" .. tostring(mode) .. ")")
				end
			},
			ResourceShareTax = {
				SetTaxRate = function(rate)
					table.insert(allowCalls, "ResourceShareTax.SetTaxRate(" .. tostring(rate) .. ")")
				end,
				SetThreshold = function(threshold)
					table.insert(allowCalls, "ResourceShareTax.SetThreshold(" .. tostring(threshold) .. ")")
				end
			}
		},
		GetDenyCalls = function() return denyCalls end,
		GetAllowCalls = function() return allowCalls end
	}
end

function TestUtils.setupGlobalMocks()
	_G.Spring = TestUtils.createMockSpringAPI()
	_G.VFS = TestUtils.createMockVFS()
	_G.gadgetHandler = TestUtils.createMockGadgetHandler()
	_G.GG = _G.GG or {}
	_G.GG.TeamTransfer = TestUtils.createMockTeamTransferAPI()
	_G.CMD = _G.CMD or {}
	_G.CMD.GUARD = 10
	_G.CMD.REPAIR = 11
	_G.CMD.REMOVE = 1
	_G.CMD.LOAD_UNITS = 2
	_G.CMD.SELFD = 3
	_G.UnitDefs = { [1] = { name = "testunit" } }
	_G.gadget = { GetInfo = function() return {} end }
	_G.setmetatable = setmetatable
end

function TestUtils.cleanupGlobalMocks()
	_G.Spring = nil
	_G.VFS = nil
	_G.gadgetHandler = nil
	_G.GG = nil
	_G.CMD = nil
	_G.UnitDefs = nil
	_G.gadget = nil
	_G.setmetatable = nil
end

function TestUtils.describe(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Context '" .. description .. "' failed: " .. tostring(err))
	end
end

function TestUtils.it(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Spec '" .. description .. "' failed: " .. tostring(err))
	end
end

function TestUtils.includeRealPolicyFile(policyFileName)
	_G.gadget = { GetInfo = function() return {} end }
	_G.gadgetHandler = { IsSyncedCode = function() return true end }
	
	local success, result = pcall(function()
		return dofile("../../../luarules/gadgets/team_transfer/policies/" .. policyFileName)
	end)
	
	if not success then
		error("Failed to include policy file " .. policyFileName .. ": " .. tostring(result))
	end
	
	return result
end

function TestUtils.createPolicyRegistrationSpy()
	local registeredPolicies = {}
	local capturedHandlers = {}
	
	local function createSpyPolicyBuilder()
		local denyCalls = {}
		local allowCalls = {}
		local useCalls = {}
		
		local function captureHandler(category, handler)
			capturedHandlers[category] = handler
			table.insert(useCalls, category .. ".Use")
		end
		
		return {
			ForAlliedCommands = {
				WhenGuard = { 
					Deny = function() 
						table.insert(denyCalls, "AlliedCommands.WhenGuard.Deny")
					end 
				},
				WhenRepair = { 
					Deny = function() 
						table.insert(denyCalls, "AlliedCommands.WhenRepair.Deny")
					end 
				}
			},
			ForEnemyResourceTransfers = {
				Use = function(handler)
					captureHandler("enemyResourceHandler", handler)
				end
			},
			ForEnemyUnitTransfers = {
				Use = function(handler)
					captureHandler("enemyUnitHandler", handler)
				end
			},
		Use = {
			UnitSharingMode = {
				SetMode = function(mode)
					table.insert(allowCalls, "UnitSharingMode.SetMode(" .. tostring(mode) .. ")")
				end
			},
			ResourceShareTax = {
				SetTaxRate = function(rate)
					table.insert(allowCalls, "ResourceShareTax.SetTaxRate(" .. tostring(rate) .. ")")
				end,
				SetThreshold = function(threshold)
					table.insert(allowCalls, "ResourceShareTax.SetThreshold(" .. tostring(threshold) .. ")")
				end
			}
		},
			GetDenyCalls = function() return denyCalls end,
			GetAllowCalls = function() return allowCalls end,
			GetUseCalls = function() return useCalls end,
			GetCapturedHandlers = function() return capturedHandlers end
		}
	end
	
	return {
		RegisterPolicy = function(fn)
			table.insert(registeredPolicies, fn)
			local spyPolicy = createSpyPolicyBuilder()
			fn(spyPolicy)
			return fn
		end,
		GetRegisteredPolicies = function() return registeredPolicies end,
		CreateSpyPolicyBuilder = createSpyPolicyBuilder
	}
end

function TestUtils.describeContext(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Context '" .. description .. "' failed: " .. tostring(err))
	end
end

function TestUtils.itShould(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Spec '" .. description .. "' failed: " .. tostring(err))
	end
end

return TestUtils
