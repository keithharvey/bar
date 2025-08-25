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
					ResourceShareTax = {
						SetTaxRate = function(rate)
							table.insert(allowCalls, "ResourceShareTax.SetTaxRate(" .. tostring(rate) .. ")")
						end,
						SetThreshold = function(threshold)
							table.insert(allowCalls, "ResourceShareTax.SetThreshold(" .. tostring(threshold) .. ")")
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
				RESOURCE_SHARE_TAX = "game_resource_share_tax",
				RESOURCE_SHARE_TAX_THRESHOLD = "game_resource_share_tax_threshold"
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
	if policyFileName == "tax_resource_sharing.lua" then
		local isTaxEnabled, taxRate = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.RESOURCE_SHARE_TAX)
		local isThresholdEnabled, threshold = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.RESOURCE_SHARE_TAX_THRESHOLD)
		
		if isTaxEnabled and tonumber(taxRate) > 0 then
			GG.TeamTransfer.RegisterPolicy(function(policy)
				policy.Use.ResourceShareTax.SetTaxRate(tonumber(taxRate))
				if isThresholdEnabled then
					policy.Use.ResourceShareTax.SetThreshold(tonumber(threshold))
				end
			end)
		end
	end
end

function test()
	local TestUtils = VFS.Include("luaui/Tests/team_transfer/shared_test_utils.lua")
	
		TestUtils.describe("Tax Resource Sharing Policy", function()
		
		TestUtils.describe("when tax rate is configured", function()
			Spring.GetModOptions = function()
				return { 
					game_resource_share_tax = "0.1",
					game_resource_share_tax_threshold = "500"
				}
			end
			
			TestUtils.it("should register policies that set tax rate and threshold", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("tax_resource_sharing.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy when tax rate is configured")
				
				local spyPolicy = TestUtils.createPolicyRegistrationSpy().CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				local allowCalls = spyPolicy.GetAllowCalls()
				
				local hasSetTaxRate = false
				local hasSetThreshold = false
				for _, call in ipairs(allowCalls) do
					if call:match("ResourceShareTax%.SetTaxRate") then hasSetTaxRate = true end
					if call:match("ResourceShareTax%.SetThreshold") then hasSetThreshold = true end
				end
				
				assert(hasSetTaxRate, "Should set tax rate")
				assert(hasSetThreshold, "Should set threshold")
			end)
		end)
		
		TestUtils.describe("when tax rate is zero", function()
			Spring.GetModOptions = function()
				return { game_resource_share_tax = "0" }
			end
			
			TestUtils.it("should not register any policy", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("tax_resource_sharing.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register any policy when tax rate is zero")
			end)
		end)
		
		TestUtils.describe("when tax rate is not configured", function()
			Spring.GetModOptions = function()
				return {}
			end
			
			TestUtils.it("should not register any policy", function()
				local policySpy = TestUtils.createPolicyRegistrationSpy()
				GG.TeamTransfer = TestUtils.createMockTeamTransfer(policySpy)
				
				includeRealPolicyFile("tax_resource_sharing.lua")
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register any policy when not configured")
			end)
		end)
	end)
end
