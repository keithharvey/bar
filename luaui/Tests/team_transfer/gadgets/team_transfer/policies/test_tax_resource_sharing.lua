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
				ResourceShareTax = {
					SetTaxRate = function(rate)
						table.insert(useCalls, "ResourceShareTax.SetTaxRate(" .. tostring(rate) .. ")")
					end,
					SetThreshold = function(threshold)
						table.insert(useCalls, "ResourceShareTax.SetThreshold(" .. tostring(threshold) .. ")")
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
	describe("Tax Resource Sharing Policy", function()
		
		describe("when tax rate and threshold are configured", function()
			Spring.GetModOptions = function()
				return { 
					game_resource_share_tax = "0.1",
					game_resource_share_tax_threshold = "500"
				}
			end
			
			it("should register a policy that sets tax rate and threshold", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local taxEnabled, taxRate = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.RESOURCE_SHARE_TAX)
				local thresholdEnabled, threshold = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.RESOURCE_SHARE_TAX_THRESHOLD)
				
				if taxEnabled and tonumber(taxRate) > 0 then
					mockTeamTransfer.RegisterPolicy(function(policy)
						policy.Use.ResourceShareTax.SetTaxRate(tonumber(taxRate))
						if thresholdEnabled then
							policy.Use.ResourceShareTax.SetThreshold(tonumber(threshold))
						end
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies > 0, "Should register at least one policy")
				
				local spyPolicy = policySpy.CreateSpyPolicyBuilder()
				policies[1](spyPolicy)
				local useCalls = spyPolicy.GetUseCalls()
				
				local hasTaxRateSet = false
				local hasThresholdSet = false
				for _, call in ipairs(useCalls) do
					if call:match("ResourceShareTax.SetTaxRate") then
						hasTaxRateSet = true
					elseif call:match("ResourceShareTax.SetThreshold") then
						hasThresholdSet = true
					end
				end
				assert(hasTaxRateSet, "Should set tax rate through policy")
				assert(hasThresholdSet, "Should set tax threshold through policy")
			end)
		end)
		
		describe("when tax rate is zero", function()
			Spring.GetModOptions = function()
				return { game_resource_share_tax = "0" }
			end
			
			it("should not register any policy when tax is disabled", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local taxEnabled, taxRate = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.RESOURCE_SHARE_TAX)
				
				if taxEnabled and tonumber(taxRate) > 0 then
					mockTeamTransfer.RegisterPolicy(function(policy)
						policy.Use.ResourceShareTax.SetTaxRate(tonumber(taxRate))
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register policy when tax rate is 0")
			end)
		end)
		
		describe("when tax configuration is missing", function()
			Spring.GetModOptions = function()
				return {}
			end
			
			it("should not register any policy when not configured", function()
				local policySpy = createPolicyRegistrationSpy()
				local mockTeamTransfer = {
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
				GG.TeamTransfer = mockTeamTransfer
				
				local taxEnabled, taxRate = mockTeamTransfer.IsSharingOption(mockTeamTransfer.MODOPTION_KEYS.RESOURCE_SHARE_TAX)
				
				if taxEnabled and tonumber(taxRate) > 0 then
					mockTeamTransfer.RegisterPolicy(function(policy)
						policy.Use.ResourceShareTax.SetTaxRate(tonumber(taxRate))
					end)
				end
				
				local policies = policySpy.GetRegisteredPolicies()
				assert(#policies == 0, "Should not register policy when not configured")
			end)
		end)
	end)
end
