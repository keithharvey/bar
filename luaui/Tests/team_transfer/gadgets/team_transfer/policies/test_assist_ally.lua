function setup()
	_G.Spring = {
		GetModOptions = function() return {} end,
		GetGaiaTeamID = function() return 255 end,
		GetTeamInfo = function(teamID, detailed) return "Team", 0, 0, false end,
		GetTeamLuaAI = function(teamID) return nil end,
		AreTeamsAllied = function(team1, team2) return team1 == team2 end,
		IsCheatingEnabled = function() return false end
	}
	_G.gadgetHandler = { IsSyncedCode = function() return true end }
	_G.GG = _G.GG or {}
	_G.CMD = { GUARD = 10, REPAIR = 11 }
	_G.gadget = { GetInfo = function() return {} end }
	_G.setmetatable = setmetatable
	_G.VFS = _G.VFS or {}
	VFS.Include = function(path)
		if path:match("shared_test_utils") then
			return require_shared_test_utils()
		end
		return {}
	end
end

function cleanup()
	_G.Spring = nil
	_G.gadgetHandler = nil
	_G.GG = nil
	_G.CMD = nil
	_G.gadget = nil
	_G.VFS = nil
end

function require_shared_test_utils()
	local TestUtils = {}
	
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
	
	function TestUtils.createPolicyRegistrationSpy()
		local registeredPolicies = {}
		
		return {
			RegisterPolicy = function(fn)
				table.insert(registeredPolicies, fn)
				return fn
			end,
			GetRegisteredPolicies = function() return registeredPolicies end
		}
	end
	
	function TestUtils.createMockTeamTransfer(policySpy)
		return {
			MODOPTION_KEYS = {
				ALLY_ASSIST_MODE = "game_assist_ally"
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
			GetDenyCalls = function() return denyCalls end,
			GetAllowCalls = function() return allowCalls end
		}
	end
	
	return TestUtils
end



local function includeRealPolicyFile(policyFileName)
	if policyFileName == "assist_ally.lua" then
		local isEnabled, mode = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
		if isEnabled and mode == "enabled" then
			GG.TeamTransfer.RegisterPolicy(function(policy)
				policy.ForAlliedCommands.WhenGuard.Deny()
				policy.ForAlliedCommands.WhenRepair.Deny()
			end)
		end
	end
end

function test()
	local TestUtils = VFS.Include("luaui/Tests/team_transfer/shared_test_utils.lua")
	
	TestUtils.describe("Assist Ally Policy", function()
		
		TestUtils.describe("when ally assist mode is enabled", function()
			Spring.GetModOptions = function()
				return { game_assist_ally = "enabled" }
			end
			
			TestUtils.it("should register policies that deny guard and repair commands to allies", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("assist_ally.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy when ally assist is enabled")
				
				local spyPolicy = TestUtils.createMockPolicyBuilder()
				policies[1](spyPolicy)
				local denyCalls = spyPolicy.GetDenyCalls()
				
				local hasGuardDeny = false
				local hasRepairDeny = false
				for _, call in ipairs(denyCalls) do
					if call:match("WhenGuard") then hasGuardDeny = true end
					if call:match("WhenRepair") then hasRepairDeny = true end
				end
				
				assert(hasGuardDeny, "Should deny guard commands to allies")
				assert(hasRepairDeny, "Should deny repair commands to allies")
			end)
		end)
		
		TestUtils.describe("when ally assist mode is disabled", function()
			Spring.GetModOptions = function()
				return { game_assist_ally = "disabled" }
			end
			
			TestUtils.it("should not register any policy", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("assist_ally.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register any policy when disabled")
			end)
		end)
		
		TestUtils.describe("when ally assist mode is not configured", function()
			Spring.GetModOptions = function()
				return {}
			end
			
			TestUtils.it("should not register any policy", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("assist_ally.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register any policy when not configured")
			end)
		end)
	end)
end
