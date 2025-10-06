local UnitSharing = require("luarules/gadgets/team_transfer/unit_sharing")

describe("UnitSharing", function()
    describe("isEconomicUnitDef", function()
        it("should return false for nil unitDef", function()
            assert.is_false(UnitSharing.isEconomicUnitDef(nil))
        end)

        it("should return true for builders", function()
            local unitDef = { builder = true }
            assert.is_true(UnitSharing.isEconomicUnitDef(unitDef))
        end)

        it("should return true for factories", function()
            local unitDef = { isFactory = true }
            assert.is_true(UnitSharing.isEconomicUnitDef(unitDef))
        end)

        it("should return true for assist units", function()
            local unitDef = { canAssist = true }
            assert.is_true(UnitSharing.isEconomicUnitDef(unitDef))
        end)

        it("should return false for combat units", function()
            local unitDef = { 
                name = "armpw",
                customParams = { unitgroup = "weapon" }
            }
            assert.is_false(UnitSharing.isEconomicUnitDef(unitDef))
        end)
    end)

    describe("isCombatUnitDef", function()
        it("should return false for nil unitDef", function()
            assert.is_false(UnitSharing.isCombatUnitDef(nil))
        end)

        it("should return true for weapon units", function()
            local unitDef = {
                customParams = { unitgroup = "weapon" }
            }
            assert.is_true(UnitSharing.isCombatUnitDef(unitDef))
        end)

        it("should return true for aa units", function()
            local unitDef = {
                customParams = { unitgroup = "aa" }
            }
            assert.is_true(UnitSharing.isCombatUnitDef(unitDef))
        end)

        it("should return true for units with weapons", function()
            local unitDef = {
                weapons = {{ def = "some_weapon" }}
            }
            assert.is_true(UnitSharing.isCombatUnitDef(unitDef))
        end)

        it("should return false for economic units", function()
            local unitDef = {
                builder = true,
                customParams = { unitgroup = "builder" }
            }
            assert.is_false(UnitSharing.isCombatUnitDef(unitDef))
        end)
    end)

    describe("isUtilityUnitDef", function()
        it("should return false for nil unitDef", function()
            assert.is_false(UnitSharing.isUtilityUnitDef(nil))
        end)

        it("should return true for energy units", function()
            local unitDef = {
                customParams = { unitgroup = "energy" }
            }
            assert.is_true(UnitSharing.isUtilityUnitDef(unitDef))
        end)

        it("should return true for metal units", function()
            local unitDef = {
                customParams = { unitgroup = "metal" }
            }
            assert.is_true(UnitSharing.isUtilityUnitDef(unitDef))
        end)

        it("should return true for util units", function()
            local unitDef = {
                customParams = { unitgroup = "util" }
            }
            assert.is_true(UnitSharing.isUtilityUnitDef(unitDef))
        end)

        it("should return false for combat units", function()
            local unitDef = {
                customParams = { unitgroup = "weapon" }
            }
            assert.is_false(UnitSharing.isUtilityUnitDef(unitDef))
        end)
    end)

    describe("isT2ConstructorDef", function()
        it("should return false for nil unitDef", function()
            assert.is_false(UnitSharing.isT2ConstructorDef(nil))
        end)

        it("should return true for T2 constructors", function()
            local unitDef = {
                builder = true,
                buildOptions = {"unit1", "unit2", "unit3"},
                customParams = { techlevel = 2 }
            }
            assert.is_true(UnitSharing.isT2ConstructorDef(unitDef))
        end)

        it("should return false for T1 constructors", function()
            local unitDef = {
                builder = true,
                buildOptions = {"unit1", "unit2"},
                customParams = { techlevel = 1 }
            }
            assert.is_false(UnitSharing.isT2ConstructorDef(unitDef))
        end)

        it("should return false for factories", function()
            local unitDef = {
                isFactory = true,
                buildOptions = {"unit1", "unit2"},
                customParams = { techlevel = 2 }
            }
            assert.is_false(UnitSharing.isT2ConstructorDef(unitDef))
        end)

        it("should return false for units without buildOptions", function()
            local unitDef = {
                builder = true,
                customParams = { techlevel = 2 }
            }
            assert.is_false(UnitSharing.isT2ConstructorDef(unitDef))
        end)

        it("should return false for units without customParams", function()
            local unitDef = {
                builder = true,
                buildOptions = {"unit1", "unit2"}
            }
            assert.is_false(UnitSharing.isT2ConstructorDef(unitDef))
        end)
    end)

end)
