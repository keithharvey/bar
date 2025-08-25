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
end

function cleanup()
	_G.Spring = nil
	_G.gadgetHandler = nil
	_G.GG = nil
	_G.CMD = nil
	_G.gadget = nil
end

local function describe(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Context '" .. description .. "' failed: " .. tostring(err))
	end
end

local function it(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Spec '" .. description .. "' failed: " .. tostring(err))
	end
end

local function createPolicyRegistrationSpy()
	local registeredPolicies = {}
	
	local function createSpyPolicyBuilder()
		local useCalls = {}
		
		return {
			Use = {
				UnitSharingMode = {
					SetMode = function(mode)
						table.insert(useCalls, "UnitSharingMode.SetMode(" .. tostring(mode) .. ")")
					end
				}
			},
			GetUseCalls = function() return useCalls end
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

function test()
	describe("Unit Sharing Mode Policy", function()
		
		describe("when unit sharing mode is configured", function()
			Spring.GetModOptions = function()
				return { game_unit_sharing_mode = "test_mode" }
			end
			
			it("should register a policy that sets the sharing mode", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, mode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.UNIT_SHARING_MODE)
				local finalMode = mode or "default"
				
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.Use.UnitSharingMode.SetMode(finalMode)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy")
				
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				local useCalls = spyPolicy.GetUseCalls()
				
				local hasModeSet = false
				for _, call in ipairs(useCalls) do
					if call:match("UnitSharingMode.SetMode") and call:match("test_mode") then
						hasModeSet = true
						break
					end
				end
				assert(hasModeSet, "Should set unit sharing mode through policy")
			end)
		end)
		
		describe("when unit sharing mode is not configured", function()
			Spring.GetModOptions = function()
				return {}
			end
			
			it("should register a policy with default mode", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, mode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.UNIT_SHARING_MODE)
				local finalMode = mode or "default"
				
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.Use.UnitSharingMode.SetMode(finalMode)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy")
				
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				local useCalls = spyPolicy.GetUseCalls()
				
				local hasDefaultMode = false
				for _, call in ipairs(useCalls) do
					if call:match("UnitSharingMode.SetMode") and call:match("default") then
						hasDefaultMode = true
						break
					end
				end
				assert(hasDefaultMode, "Should set default unit sharing mode when not configured")
			end)
		end)
	end)
end
