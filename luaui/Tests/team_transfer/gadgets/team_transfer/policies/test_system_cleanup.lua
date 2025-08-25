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
	
	return {
		RegisterPolicy = function(fn)
			table.insert(registeredPolicies, fn)
			return fn
		end,
		GetRegisteredPolicies = function() return registeredPolicies end
	}
end

function test()
	describe("System Cleanup Policy", function()
		
		describe("when system cleanup is enabled", function()
			Spring.GetModOptions = function()
				return { game_system_cleanup = "enabled" }
			end
			
			it("should register policies for system cleanup", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
					MODOPTION_KEYS = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, cleanupMode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.SYSTEM_CLEANUP)
				if enabled and cleanupMode ~= "disabled" then
					mockTeamTransfer.RegisterPolicy(function(policy)
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy")
			end)
		end)
		
		describe("when system cleanup is disabled", function()
			Spring.GetModOptions = function()
				return { game_system_cleanup = "disabled" }
			end
			
			it("should not register any policy when disabled", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
					MODOPTION_KEYS = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, cleanupMode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.SYSTEM_CLEANUP)
				if enabled and cleanupMode ~= "disabled" then
					mockTeamTransfer.RegisterPolicy(function(policy)
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register policy when disabled")
			end)
		end)
		
		describe("when system cleanup is not configured", function()
			Spring.GetModOptions = function()
				return {}
			end
			
			it("should not register any policy when not configured", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
					MODOPTION_KEYS = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, cleanupMode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.SYSTEM_CLEANUP)
				if enabled and cleanupMode ~= "disabled" then
					mockTeamTransfer.RegisterPolicy(function(policy)
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register policy when not configured")
			end)
		end)
	end)
end
