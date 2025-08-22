local TestFramework = VFS.Include("luaui/Tests/test_framework.lua")

local test = TestFramework.CreateTest("Sharing UI Restrictions")

function test:setup()
	self.originalModOptions = Spring.GetModOptions()
	self.mockModOptions = {}
	self.mockGlobalScope = {}
	
	Spring.GetModOptions = function()
		return self.mockModOptions
	end
	
	WG = self.mockGlobalScope
end

function test:cleanup()
	Spring.GetModOptions = function()
		return self.originalModOptions
	end
	WG = nil
end

function test:testExtractorUpgradeDisabled()
	self.mockModOptions.disable_ally_extractor_upgrade = true
	self.mockModOptions.unit_sharing_mode = "enabled"
	
	local extractorUpgradeDisabled = false
	self.mockGlobalScope.resource_spot_builder = {
		SetAllyExtractorCanBeUpgraded = function(enabled)
			extractorUpgradeDisabled = not enabled
		end
	}
	
	local upget = VFS.Include("common/upgets/modoption_disable_economic_sharing.lua")
	upget:Initialize()
	
	self:assertTrue(extractorUpgradeDisabled, "Ally extractor upgrade should be disabled")
end

function test:testUnitSharingDisabledUI()
	self.mockModOptions.unit_sharing_mode = "disabled"
	
	local shareSliderDisabled = false
	local resourceSharingDisabled = false
	local restrictedUnitsSet = false
	
	self.mockGlobalScope.topbar = {
		setShareSliderEnabled = function(enabled)
			shareSliderDisabled = not enabled
		end
	}
	
	self.mockGlobalScope.advplayerlist_api = {
		SetModuleActive = function(module)
			if module[1] == 'share_resource' and not module[2] then
				resourceSharingDisabled = true
			end
		end
	}
	
	self.mockGlobalScope.sharecmd = {
		setRestrictedUnits = function(units)
			restrictedUnitsSet = next(units) ~= nil
		end
	}
	
	local upget = VFS.Include("common/upgets/modoption_disable_economic_sharing.lua")
	upget:Initialize()
	
	self:assertTrue(shareSliderDisabled, "Share slider should be disabled")
	self:assertTrue(resourceSharingDisabled, "Resource sharing should be disabled")
	self:assertTrue(restrictedUnitsSet, "Restricted units should be set")
end

function test:testCombatOnlySharing()
	self.mockModOptions.unit_sharing_mode = "combat"
	
	local restrictedUnits = {}
	self.mockGlobalScope.sharecmd = {
		setRestrictedUnits = function(units)
			restrictedUnits = units
		end
	}
	
	local upget = VFS.Include("common/upgets/modoption_disable_economic_sharing.lua")
	upget:Initialize()
	
	self:assertNotNil(next(restrictedUnits), "Some units should be restricted in combat-only mode")
end

function test:testEconomyOnlySharing()
	self.mockModOptions.unit_sharing_mode = "economy"
	
	local restrictedUnits = {}
	self.mockGlobalScope.sharecmd = {
		setRestrictedUnits = function(units)
			restrictedUnits = units
		end
	}
	
	local upget = VFS.Include("common/upgets/modoption_disable_economic_sharing.lua")
	upget:Initialize()
	
	self:assertNotNil(next(restrictedUnits), "Some units should be restricted in economy-only mode")
end

function test:testT2ConsOnlySharing()
	self.mockModOptions.unit_sharing_mode = "t2cons"
	
	local restrictedUnits = {}
	self.mockGlobalScope.sharecmd = {
		setRestrictedUnits = function(units)
			restrictedUnits = units
		end
	}
	
	local upget = VFS.Include("common/upgets/modoption_disable_economic_sharing.lua")
	upget:Initialize()
	
	self:assertNotNil(next(restrictedUnits), "Most units should be restricted in T2-cons-only mode")
end

return test
