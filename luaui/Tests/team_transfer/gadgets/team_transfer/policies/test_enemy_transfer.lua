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
	local capturedHandlers = {}
	
	local function createSpyPolicyBuilder()
		local denyCalls = {}
		local allowCalls = {}
		
		return {
			ForEnemyResourceTransfers = {
				Use = function(handler)
					capturedHandlers.enemyResourceHandler = handler
				end
			},
			ForEnemyUnitTransfers = {
				Use = function(handler)
					capturedHandlers.enemyUnitHandler = handler
				end
			},
			GetCapturedHandlers = function() return capturedHandlers end
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
	describe("Enemy Transfer Policy", function()
		local policySpy = createPolicyRegistrationSpy()
		local mockTeamTransfer = {
			MODOPTION_KEYS = {
				ENEMY_RESOURCE_TRANSFER = "game_enemy_resource_transfer",
				ENEMY_UNIT_TRANSFER = "game_enemy_unit_transfer"
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
		
		describe("when including the real policy file", function()
			it("should register enemy resource and unit transfer handlers", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyResourceTransfers.Use(function(ctx)
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
					
					policy.ForEnemyUnitTransfers.Use(function(ctx)
						if ctx.capture then
							return true
						end
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.fromIsNonPlayer or ctx.toIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy")
				
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				local handlers = spyPolicy.GetCapturedHandlers()
				
				assert(handlers.enemyResourceHandler ~= nil, "Should register enemy resource transfer handler")
				assert(handlers.enemyUnitHandler ~= nil, "Should register enemy unit transfer handler")
			end)
		end)
		
		describe("resource transfer behavior", function()
			local resourceHandler
			
			it("should deny transfers between enemy players by default", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyResourceTransfers.Use(function(ctx)
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				resourceHandler = spyPolicy.GetCapturedHandlers().enemyResourceHandler
				
				local ctx = {
					isCheatingEnabled = false,
					senderIsNonPlayer = false,
					receiverIsNonPlayer = false
				}
				local result = resourceHandler(ctx)
				assert(result.deny == true, "Should deny resource transfer between enemy players")
			end)
			
			it("should allow transfers when cheating is enabled", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyResourceTransfers.Use(function(ctx)
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				resourceHandler = spyPolicy.GetCapturedHandlers().enemyResourceHandler
				
				local ctx = {
					isCheatingEnabled = true,
					senderIsNonPlayer = false,
					receiverIsNonPlayer = false
				}
				local result = resourceHandler(ctx)
				assert(result.allow == true, "Should allow resource transfer when cheating enabled")
			end)
			
			it("should allow transfers from non-player entities", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyResourceTransfers.Use(function(ctx)
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				resourceHandler = spyPolicy.GetCapturedHandlers().enemyResourceHandler
				
				local ctx = {
					isCheatingEnabled = false,
					senderIsNonPlayer = true,
					receiverIsNonPlayer = false
				}
				local result = resourceHandler(ctx)
				assert(result.allow == true, "Should allow resource transfer from non-player")
			end)
			
			it("should allow transfers to non-player entities", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyResourceTransfers.Use(function(ctx)
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				resourceHandler = spyPolicy.GetCapturedHandlers().enemyResourceHandler
				
				local ctx = {
					isCheatingEnabled = false,
					senderIsNonPlayer = false,
					receiverIsNonPlayer = true
				}
				local result = resourceHandler(ctx)
				assert(result.allow == true, "Should allow resource transfer to non-player")
			end)
		end)
		
		describe("unit transfer behavior", function()
			local unitHandler
			
			it("should allow capture transfers unconditionally", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyUnitTransfers.Use(function(ctx)
						if ctx.capture then
							return true
						end
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.fromIsNonPlayer or ctx.toIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				unitHandler = spyPolicy.GetCapturedHandlers().enemyUnitHandler
				
				local ctx = {
					capture = true,
					isCheatingEnabled = false,
					fromIsNonPlayer = false,
					toIsNonPlayer = false
				}
				local result = unitHandler(ctx)
				assert(result == true, "Should allow capture transfers")
			end)
			
			it("should deny non-capture transfers between enemy players by default", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyUnitTransfers.Use(function(ctx)
						if ctx.capture then
							return true
						end
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.fromIsNonPlayer or ctx.toIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				unitHandler = spyPolicy.GetCapturedHandlers().enemyUnitHandler
				
				local ctx = {
					capture = false,
					isCheatingEnabled = false,
					fromIsNonPlayer = false,
					toIsNonPlayer = false
				}
				local result = unitHandler(ctx)
				assert(result.deny == true, "Should deny unit transfer between enemy players")
			end)
			
			it("should allow non-capture transfers when cheating is enabled", function()
				mockTeamTransfer.RegisterPolicy(function(policy)
					policy.ForEnemyUnitTransfers.Use(function(ctx)
						if ctx.capture then
							return true
						end
						if ctx.isCheatingEnabled then
							return { allow = true }
						end
						if ctx.fromIsNonPlayer or ctx.toIsNonPlayer then
							return { allow = true }
						end
						return { deny = true }
					end)
				end)
				
				local policies = policySpy.GetRegisteredPolicies()
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				unitHandler = spyPolicy.GetCapturedHandlers().enemyUnitHandler
				
				local ctx = {
					capture = false,
					isCheatingEnabled = true,
					fromIsNonPlayer = false,
					toIsNonPlayer = false
				}
				local result = unitHandler(ctx)
				assert(result.allow == true, "Should allow unit transfer when cheating enabled")
			end)
		end)
	end)
end
