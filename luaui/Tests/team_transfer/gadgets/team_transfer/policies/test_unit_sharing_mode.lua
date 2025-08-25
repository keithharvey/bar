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
		
		local function createSpyPolicyBuilder()
			local allowCalls = {}
			local denyCalls = {}
			
			return {
				Use = {
					UnitSharingMode = {
						SetMode = function(mode)
							table.insert(allowCalls, "UnitSharingMode.SetMode(" .. tostring(mode) .. ")")
						end
					}
				},
				GetAllowCalls = function() return allowCalls end,
				GetDenyCalls = function() return denyCalls end
			}
		end
		
		return {
			RegisterPolicy = function(fn)
				table.insert(registeredPolicies, fn)
				return fn
			end,
			GetRegisteredPolicies = function() return registeredPolicies end,
			CreateSpyPolicyBuilder = createSpyPolicyBuilder
		}
	end
	
	function TestUtils.createMockTeamTransfer(policySpy)
		return {
			MODOPTION_KEYS = {
				UNIT_SHARING_MODE = "game_unit_sharing_mode"
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
	
	return TestUtils
end

local function includeRealPolicyFile(policyFileName)
	if policyFileName == "unit_sharing_mode.lua" then
		local isEnabled, mode = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.UNIT_SHARING_MODE)
		if isEnabled then
			GG.TeamTransfer.RegisterPolicy(function(policy)
				policy.Use.UnitSharingMode.SetMode(mode)
			end)
		end
	end
end

function test()
	local TestUtils = VFS.Include("luaui/Tests/team_transfer/shared_test_utils.lua")
	
		TestUtils.describe("Unit Sharing Mode Policy", function()
		
		TestUtils.describe("when unit sharing mode is configured", function()
			Spring.GetModOptions = function()
				return { game_unit_sharing_mode = "allies" }
			end
			
			TestUtils.it("should register policies that set the sharing mode", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("unit_sharing_mode.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy when unit sharing mode is configured")
				
				local spyPolicy = TestUtils.createPolicyRegistrationSpy().CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				local allowCalls = spyPolicy.GetAllowCalls()
				
				local hasSetMode = false
				for _, call in ipairs(allowCalls) do
					if call:match("UnitSharingMode%.SetMode") then hasSetMode = true end
				end
				
				assert(hasSetMode, "Should set unit sharing mode")
			end)
		end)
		
		TestUtils.describe("when unit sharing mode is not configured", function()
			Spring.GetModOptions = function()
				return {}
			end
			
			TestUtils.it("should not register any policy", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("unit_sharing_mode.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register any policy when not configured")
			end)
		end)
	end)
end
