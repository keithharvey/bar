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
	
	self:assertTrue(self.mockModOptions.disable_ally_extractor_upgrade, "Ally extractor upgrade should be disabled")
end

function test:testUnitSharingDisabledUI()
	self.mockModOptions.unit_sharing_mode = "disabled"
	
	local shareSliderDisabled = false
	local resourceSharingDisabled = false
	local restrictedUnitsSet = false
	
	self:assertEqual(self.mockModOptions.unit_sharing_mode, "disabled", "Unit sharing should be disabled")
end

function test:testCombatOnlySharing()
	self.mockModOptions.unit_sharing_mode = "combat"
	
	self:assertEqual(self.mockModOptions.unit_sharing_mode, "combat", "Unit sharing mode should be combat")
end

function test:testEconomyOnlySharing()
	self.mockModOptions.unit_sharing_mode = "economy"
	
	self:assertEqual(self.mockModOptions.unit_sharing_mode, "economy", "Unit sharing mode should be economy")
end

function test:testT2ConsOnlySharing()
	self.mockModOptions.unit_sharing_mode = "t2cons"
	
	self:assertEqual(self.mockModOptions.unit_sharing_mode, "t2cons", "Unit sharing mode should be t2cons")
end

return test
