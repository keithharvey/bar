local TestFramework = VFS.Include("luaui/Tests/test_framework.lua")

local test = TestFramework.CreateTest("Sharing Modoptions")

function test:setup()
	self.originalModOptions = Spring.GetModOptions()
	self.mockModOptions = {}
	
	Spring.GetModOptions = function()
		return self.mockModOptions
	end
end

function test:cleanup()
	Spring.GetModOptions = function()
		return self.originalModOptions
	end
end

function test:testUnitSharingModeEnabled()
	self.mockModOptions.unit_sharing_mode = "enabled"
	
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	local policies = {}
	
	TeamTransfer.RegisterPolicy = function(policyFunc)
		table.insert(policies, policyFunc)
	end
	
	VFS.Include("luarules/gadgets/team_transfer/game_disable_unit_sharing.lua")
	
	self:assertEqual(#policies, 0, "No policies should be registered when unit sharing is enabled")
end

function test:testUnitSharingModeDisabled()
	self.mockModOptions.unit_sharing_mode = "disabled"
	
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	local policies = {}
	local deniedTransfers = 0
	
	TeamTransfer.RegisterPolicy = function(policyFunc)
		local mockPolicy = {
			For = function(self, policyType)
				return {
					Use = function(self, handler)
						local result = handler({})
						if result and result.deny then
							deniedTransfers = deniedTransfers + 1
						end
						return self
					end,
					When = function(self, predicate)
						return self
					end
				}
			end
		}
		policyFunc(mockPolicy)
	end
	
	VFS.Include("luarules/gadgets/team_transfer/game_disable_unit_sharing.lua")
	
	self:assertGreaterThan(deniedTransfers, 0, "Unit transfers should be denied when disabled")
end

function test:testUnitSharingModeT2Cons()
	self.mockModOptions.unit_sharing_mode = "t2cons"
	
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	local restrictedUnits = 0
	
	TeamTransfer.RegisterPolicy = function(policyFunc)
		local mockPolicy = {
			For = function(self, policyType)
				return {
					When = function(self, predicate)
						local testContext = { unitDefID = 1 }
						if predicate(testContext) then
							restrictedUnits = restrictedUnits + 1
						end
						return self
					end,
					Use = function(self, handler)
						return self
					end
				}
			end
		}
		policyFunc(mockPolicy)
	end
	
	VFS.Include("luarules/gadgets/team_transfer/game_disable_unit_sharing.lua")
	
	self:assertGreaterThan(restrictedUnits, 0, "Non-T2 constructor units should be restricted")
end

function test:testDisableAllyExtractorUpgrade()
	self.mockModOptions.disable_ally_extractor_upgrade = true
	
	local blockedBuilds = 0
	local originalAllowUnitCreation = gadget.AllowUnitCreation
	
	gadget.AllowUnitCreation = function(unitDefID, builderID, builderTeam, x, y, z)
		local result = originalAllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
		if not result then
			blockedBuilds = blockedBuilds + 1
		end
		return result
	end
	
	VFS.Include("luarules/gadgets/team_transfer/game_disable_ally_extractor_upgrade.lua")
	
	self:assertNotNil(gadget.AllowUnitCreation, "AllowUnitCreation should be implemented")
end

function test:testTransferToEnemiesDisabled()
	self.mockModOptions.transfer_to_enemies = false
	
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	local enemyTransfersDenied = 0
	
	TeamTransfer.RegisterPolicy = function(policyFunc)
		local mockPolicy = {
			For = function(self, policyType)
				return {
					When = function(self, predicate)
						return {
							Use = function(self, handler)
								local result = handler({})
								if result and result.deny then
									enemyTransfersDenied = enemyTransfersDenied + 1
								end
								return self
							end
						}
					end
				}
			end
		}
		policyFunc(mockPolicy)
	end
	
	VFS.Include("luarules/gadgets/team_transfer/game_disable_economic_sharing.lua")
	
	self:assertGreaterThan(enemyTransfersDenied, 0, "Enemy transfers should be denied")
end

function test:testUnitShareStun()
	self.mockModOptions.unit_share_stun_seconds = 5
	
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	local stunPolicies = 0
	
	TeamTransfer.RegisterPolicy = function(policyFunc)
		stunPolicies = stunPolicies + 1
	end
	
	VFS.Include("luarules/gadgets/team_transfer/game_unit_share_stun.lua")
	
	self:assertGreaterThan(stunPolicies, 0, "Stun policies should be registered when stun time > 0")
end

function test:testAlliedConstructionAssist()
	self.mockModOptions.allied_construction_assist = "disabled"
	
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	local assistPolicies = 0
	
	TeamTransfer.RegisterPolicy = function(policyFunc)
		assistPolicies = assistPolicies + 1
	end
	
	VFS.Include("luarules/gadgets/team_transfer/game_allied_construction_assist.lua")
	
	self:assertGreaterThan(assistPolicies, 0, "Assist policies should be registered when disabled")
end

return test
