-- Unit sharing logic tests
-- Tests for the comprehensive unit sharing functionality

local describe = describe
local it = it
local assert = assert
local before_each = before_each

-- Mock the required globals
_G.UnitDefs = _G.UnitDefs or {}
_G.Spring = _G.Spring or {
	GetModOptions = function()
		return { unit_sharing_mode = "enabled" }
	end,
	GetUnitDefID = function(unitID)
		return unitID -- Simple mock: unitID == unitDefID
	end,
	Log = function() end
}
_G.LOG = _G.LOG or { ERROR = "ERROR" }

local sharing = require("common/unitTesting/gadgets/team_transfer/units")

describe("Unit Sharing Logic", function()
	before_each(function()
		-- Reset cache between tests
		sharing.clearCache()

		-- Set up mock UnitDefs for testing
		_G.UnitDefs = {
			[1] = { -- T1 constructor
				name = "armck",
				customParams = { techlevel = "1" },
				isFactory = false,
				buildOptions = { "armpw", "armck" },
				canAssist = true
			},
			[2] = { -- T2 constructor
				name = "armack",
				customParams = { techlevel = "2" },
				isFactory = false,
				buildOptions = { "armcom", "armpw" },
				canAssist = true
			},
			[3] = { -- Factory
				name = "armlab",
				isFactory = true,
				buildOptions = { "armpw", "armck" }
			},
			[4] = { -- Combat unit
				name = "armpw",
				customParams = { techlevel = "1" },
				canAttack = true,
				canMove = true
			},
			[5] = { -- Economic unit (metal)
				name = "armmex",
				customParams = { unitgroup = "metal" },
				canMove = false,
				canAttack = false
			},
			[6] = { -- Economic unit (energy)
				name = "armsolar",
				customParams = { unitgroup = "energy" },
				canMove = false,
				canAttack = false
			},
			[7] = { -- Commander
				name = "armcom",
				customParams = { iscommander = "1" },
				canMove = true,
				canAttack = true
			}
		}
	end)

	describe("T2 Constructor Detection", function()
		it("should identify T2 constructors correctly", function()
			local t1Con = _G.UnitDefs[1] -- armck - T1 constructor
			local t2Con = _G.UnitDefs[2] -- armack - T2 constructor
			local factory = _G.UnitDefs[3] -- armlab - factory
			local combat = _G.UnitDefs[4] -- armpw - combat unit

			assert.is_false(sharing.isT2ConstructorDef(t1Con))
			assert.is_true(sharing.isT2ConstructorDef(t2Con))
			assert.is_false(sharing.isT2ConstructorDef(factory))
			assert.is_false(sharing.isT2ConstructorDef(combat))
			assert.is_false(sharing.isT2ConstructorDef(nil))
		end)
	end)

	describe("Economic Unit Detection", function()
		it("should identify economic units correctly", function()
			local constructor = _G.UnitDefs[2] -- armack - constructor (economic)
			local factory = _G.UnitDefs[3] -- armlab - factory (economic)
			local combat = _G.UnitDefs[4] -- armpw - combat unit
			local metalExtractor = _G.UnitDefs[5] -- armmex - metal economic
			local solar = _G.UnitDefs[6] -- armsolar - energy economic

			assert.is_true(sharing.isEconomicUnitDef(constructor))
			assert.is_true(sharing.isEconomicUnitDef(factory))
			assert.is_false(sharing.isEconomicUnitDef(combat))
			assert.is_true(sharing.isEconomicUnitDef(metalExtractor))
			assert.is_true(sharing.isEconomicUnitDef(solar))
			assert.is_false(sharing.isEconomicUnitDef(nil))
		end)
	end)

	describe("Unit Sharing Mode Logic", function()
		it("should get current sharing mode from modoptions", function()
			_G.Spring.GetModOptions = function()
				return { unit_sharing_mode = "t2cons" }
			end
			assert.equal("t2cons", sharing.getUnitSharingMode())

			_G.Spring.GetModOptions = function()
				return nil
			end
			assert.equal("enabled", sharing.getUnitSharingMode())
		end)

		it("should check if units can be shared in different modes", function()
			-- T2 constructor should be shareable in t2cons mode
			assert.is_true(sharing.isUnitShareAllowedByMode(2, "t2cons"))

			-- Combat unit should not be shareable in t2cons mode
			assert.is_false(sharing.isUnitShareAllowedByMode(4, "t2cons"))

			-- Combat unit should be shareable in combat mode
			assert.is_true(sharing.isUnitShareAllowedByMode(4, "combat"))

			-- Economic unit should not be shareable in combat mode
			assert.is_false(sharing.isUnitShareAllowedByMode(5, "combat"))

			-- All units should be shareable in enabled mode
			assert.is_true(sharing.isUnitShareAllowedByMode(1, "enabled"))
			assert.is_true(sharing.isUnitShareAllowedByMode(4, "enabled"))

			-- No units should be shareable in disabled mode
			assert.is_false(sharing.isUnitShareAllowedByMode(1, "disabled"))
		end)
	end)

	describe("Unit Counting and Validation", function()
		it("should count shareable vs unshareable units", function()
			local unitIDs = {1, 2, 4, 5} -- T1 con, T2 con, combat, economic

			local shareable, unshareable, total = sharing.countUnshareable(unitIDs, "enabled")
			assert.equal(4, shareable)
			assert.equal(0, unshareable)
			assert.equal(4, total)

			shareable, unshareable, total = sharing.countUnshareable(unitIDs, "t2cons")
			assert.equal(1, shareable) -- Only T2 constructor
			assert.equal(3, unshareable)
			assert.equal(4, total)

			shareable, unshareable, total = sharing.countUnshareable(unitIDs, "combat")
			assert.equal(1, shareable) -- Only combat unit (T1 con and economic units are not shareable)
			assert.equal(3, unshareable)
			assert.equal(4, total)
		end)

		it("should determine when share button should be shown", function()
			local mixedUnits = {1, 4, 5} -- T1 con, combat, economic
			local onlyEconomic = {5, 6} -- Only economic units
			local emptySelection = {}

			assert.is_true(sharing.shouldShowShareButton(mixedUnits, "combat"))
			assert.is_false(sharing.shouldShowShareButton(onlyEconomic, "combat"))
			assert.is_false(sharing.shouldShowShareButton(emptySelection, "enabled"))
			assert.is_false(sharing.shouldShowShareButton(mixedUnits, "disabled"))
		end)
	end)

	describe("Error Messages", function()
		it("should provide appropriate error messages", function()
			assert.equal("Unit sharing is disabled", sharing.blockMessage(0, "disabled"))
			assert.equal("Cannot share selected units", sharing.blockMessage(0, "enabled"))

			local message = sharing.blockMessage(2, "t2cons")
			assert.is_not_nil(message:find("unshareable units"))
			assert.is_not_nil(message:find("T2 constructors only"))

			message = sharing.blockMessage(1, "combat")
			assert.is_not_nil(message:find("economic units"))
			assert.is_not_nil(message:find("combat units only"))
		end)
	end)

	describe("Unit Transfer Allowance", function()
		it("should allow transfers based on sharing mode", function()
			-- Capture should always be allowed
			assert.is_true(sharing.AllowUnitTransferByMode(1, 2, 0, 1, true, "disabled"))

			-- Enabled mode should allow all transfers
			assert.is_true(sharing.AllowUnitTransferByMode(1, 2, 0, 1, false, "enabled"))

			-- Disabled mode should deny all transfers
			assert.is_false(sharing.AllowUnitTransferByMode(1, 2, 0, 1, false, "disabled"))

			-- T2 constructor should be allowed in t2cons mode
			assert.is_true(sharing.AllowUnitTransferByMode(1, 2, 0, 1, false, "t2cons"))

			-- Combat unit should not be allowed in t2cons mode
			assert.is_false(sharing.AllowUnitTransferByMode(1, 4, 0, 1, false, "t2cons"))

			-- Combat unit should be allowed in combat mode
			assert.is_true(sharing.AllowUnitTransferByMode(1, 4, 0, 1, false, "combat"))

			-- Economic unit should not be allowed in combat mode
			assert.is_false(sharing.AllowUnitTransferByMode(1, 5, 0, 1, false, "combat"))
		end)
	end)

	describe("Cache Management", function()
		it("should manage cache properly", function()
			-- Initially cache should be empty
			assert.is_false(sharing.isCacheInitialized("t2cons"))

			-- Accessing cache should initialize it
			sharing.isUnitShareAllowedByMode(2, "t2cons")
			assert.is_true(sharing.isCacheInitialized("t2cons"))

			-- Cache should contain expected units
			local stats = sharing.getCacheStats()
			assert.is_true(stats.t2cons and stats.t2cons >= 1)

			-- Clear cache should reset
			sharing.clearCache()
			assert.is_false(sharing.isCacheInitialized("t2cons"))
		end)
	end)
end)
