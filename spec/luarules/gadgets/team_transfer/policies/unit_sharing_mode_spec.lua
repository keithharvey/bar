---@type Builders
local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")
local PolicyEngineLogger = require("modules/policy_engine_logger")

local Units = {
	AdvancedConstructor = "coracv",
	Pawn = "armpw",
	Fusion = "armfus",
    Constructor = "corcv",
}

---@class UnitSharingTestConfig
---@field mode string The sharing mode to test
---@field canShareUnits boolean Expected canShareUnits result
---@field blockReason string? Expected block reason (nil if no block)
---@field testUnits table<string, boolean> Map of unit names to expected outcomes

local testConfigs = {
	[SharedEnums.UnitSharingMode.Disabled] = {
		mode = SharedEnums.UnitSharingMode.Disabled,
		canShareUnits = false,
		blockReason = SharedEnums.BlockReason.Disabled,
		testUnits = {
			[Units.AdvancedConstructor] = false,
			[Units.Fusion] = false,
        }
	},
	[SharedEnums.UnitSharingMode.Enabled] = {
		mode = SharedEnums.UnitSharingMode.Enabled, 
		canShareUnits = true,
		blockReason = nil,
		testUnits = {
			[Units.AdvancedConstructor] = true,
			[Units.Fusion] = true,
        }
	},
	[SharedEnums.UnitSharingMode.CombatUnits] = {
		mode = SharedEnums.UnitSharingMode.CombatUnits,
		canShareUnits = true,
		blockReason = nil,
		testUnits = {
            [Units.Pawn] = true,
			[Units.Constructor] = false,
			[Units.AdvancedConstructor] = false,
			[Units.Fusion] = false,
        }
	},
	[SharedEnums.UnitSharingMode.Economic] = {
		mode = SharedEnums.UnitSharingMode.Economic,
		canShareUnits = true,
		blockReason = nil,
		testUnits = {
			[Units.Constructor] = true,
			[Units.AdvancedConstructor] = true,
			[Units.Fusion] = false,
			[Units.Pawn] = false,
		}
	},
	[SharedEnums.UnitSharingMode.EconomicPlusBuildings] = {
		mode = SharedEnums.UnitSharingMode.EconomicPlusBuildings,
		canShareUnits = true,
		blockReason = nil,
		testUnits = {
			[Units.AdvancedConstructor] = true,
			[Units.Constructor] = true,
			[Units.Fusion] = true,
			[Units.Pawn] = false,
		}
	},
	[SharedEnums.UnitSharingMode.T2Cons] = {
		mode = SharedEnums.UnitSharingMode.T2Cons,
		canShareUnits = true,
		blockReason = nil,
		testUnits = {
			[Units.AdvancedConstructor] = true,
			[Units.Constructor] = false,
            [Units.Fusion] = false,
			[Units.Pawn] = false,
		}
	}
}

describe(SharedEnums.Policies.UnitSharingMode .. " policy", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()

    ---@type SpringRepositoryBuilder
    local spring = Builders.SpringRepository.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :WithRealUnitDefs()
        :WithAlliance(sender.id, receiver.id, true)

    local serviceBuilder = Builders.TeamTransferService.new()
        :WithSpringRepository(spring)
        :WithPolicy(SharedEnums.Policies.UnitSharingMode)

    -- Data-driven test execution
    for modeKey, config in pairs(testConfigs) do
        describe("WHEN unit sharing mode is set to " .. config.mode, function()
            spring:WithModOption(ModOptions.Options.UnitSharingMode, config.mode)

            local unitIds = {}
            local service
            local result

            before_each(function()
				-- Create all units using enum values as names and keys
				sender:WithUnit(Units.AdvancedConstructor, function(unitId) unitIds[Units.AdvancedConstructor] = unitId end)
				sender:WithUnit(Units.Constructor, function(unitId) unitIds[Units.Constructor] = unitId end)
				sender:WithUnit(Units.Pawn, function(unitId) unitIds[Units.Pawn] = unitId end)
				sender:WithUnit(Units.Fusion, function(unitId) unitIds[Units.Fusion] = unitId end)

				service = serviceBuilder:Build()
				result = service:GetResult(sender.id, receiver.id)
			end)

            it("should have correct sharing permissions", function()
                assert.equal(config.canShareUnits, result.unit_transfer.canShareUnits)
                if config.blockReason then
                    assert.is_not_nil(result.unit_transfer.blockReason)
                else
                    assert.is_nil(result.unit_transfer.blockReason)
                end
            end)

            -- Generate tests for each unit - validation
            for unitName, shouldAllow in pairs(config.testUnits) do
                it("should " .. (shouldAllow and "allow" or "not allow") .. " validating transfer of " .. unitName, function()
                    local unitId = unitIds[unitName]
                    assert.is_not_nil(unitId)
                    
                    local validationResults = service:ValidateUnitTransfer(sender.id, receiver.id, unitId, Spring.GetUnitDefID(unitId))
                    assert.is_table(validationResults)
                    assert.is_true(#validationResults > 0)
                    
                    -- Check if all validation results pass
                    local allValid = true
                    for _, result in ipairs(validationResults) do
                        if result.ok == false then
                            allValid = false
                            break
                        end
                    end
                    
                    assert.equal(shouldAllow, allValid)
                end)
            end

            -- TODO: Add transfer action tests once SpringRepository mocking is fully implemented
            -- The validation tests above verify the policy logic works correctly
        end)
    end
end)
