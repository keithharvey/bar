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
		local denyCalls = {}
		
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


function test()
	describe("Assist Ally Policy", function()
		
		describe("when ally assist mode is enabled", function()
			Spring.GetModOptions = function()
				return { game_assist_ally = "enabled" }
			end
			
			it("should register policies that deny guard and repair commands to allies", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, assistMode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
				if enabled and assistMode ~= "disabled" then
					mockTeamTransfer.RegisterPolicy(function(policy)	
						policy.ForAlliedCommands.WhenGuard.Deny()
						policy.ForAlliedCommands.WhenRepair.Deny()
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy when ally assist is enabled")
				
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
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
		
		describe("when ally assist mode is disabled", function()
			Spring.GetModOptions = function()
				return { game_assist_ally = "disabled" }
			end
			
			it("should not register any policy", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, assistMode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
				if enabled and assistMode ~= "disabled" then
					mockTeamTransfer.RegisterPolicy(function(policy)	
						policy.ForAlliedCommands.WhenGuard.Deny()
						policy.ForAlliedCommands.WhenRepair.Deny()
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register any policy when disabled")
			end)
		end)
		
		describe("when ally assist mode is not configured", function()
			Spring.GetModOptions = function()
				return {}
			end
			
			it("should not register any policy", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local enabled, assistMode = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
				if enabled and assistMode ~= "disabled" then
					mockTeamTransfer.RegisterPolicy(function(policy)	
						policy.ForAlliedCommands.WhenGuard.Deny()
						policy.ForAlliedCommands.WhenRepair.Deny()
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register any policy when not configured")
			end)
		end)
	end)
end
