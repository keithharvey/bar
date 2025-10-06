local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

describe(SharedEnums.Policies.AlliedAssist .. " policy", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()

    local spring = Builders.SpringRepository.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :WithAlliance(sender.id, receiver.id, true) -- Allied teams

    describe("WHEN policy is loaded", function()
        ---@type CombinedPolicyResult
        local result

        before_each(function()
            -- Policy is always loaded and allows commands
            local serviceBuilder = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithPolicy(SharedEnums.Policies.AlliedAssist)
            local service = serviceBuilder:Build()
            result = service:GetResult(sender.id, receiver.id)
        end)

        it("should ALLOW guard commands", function()
            assert.is_true(result.guard_transfer.allowGuardCommands)
        end)

        it("should ALLOW repair commands", function()
            assert.is_true(result.repair_transfer.allowRepairCommands)
        end)

    end)

    describe("WHEN assist ally restrictions are enabled", function()
        local service

        before_each(function()
            -- Set up global UnitDefs for testing
            _G.UnitDefs = {}

            local springWithRestrictions = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :WithAlliance(sender.id, receiver.id, true)
                :WithModOption(SharedEnums.Policies.AlliedAssist, "disabled")
                :Build()

            service = Builders.TeamTransferService.new()
                :WithSpringRepository(springWithRestrictions)
                :WithPolicy(SharedEnums.Policies.AlliedAssist)
                :Build()
        end)

        it("should reject guarding units with build options", function()
            -- Mock UnitDefs first so WithUnit can copy properties
            _G.UnitDefs = {
                ["armpw"] = { buildOptions = {}, canAssist = false },
                ["armlab"] = { buildOptions = { "some_unit" }, canAssist = false }
            }

            -- Create a unit that will do the guarding (some basic unit)
            local guarderUnitId
            sender:WithUnit("armpw", function(unitId) guarderUnitId = unitId end)

            -- Create a mock unit with build options (like a lab)
            local labUnitId
            receiver:WithUnit("armlab", function(unitId) labUnitId = unitId end)

            -- Update the service's spring repo with the units
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            local allowed, reason = service:ValidateCommand(guarderUnitId, 1, sender.id, service.springRepo.CMD.GUARD, {labUnitId}, {}, 0, sender.id)
            assert.is_false(allowed)
            assert.equal("Cannot guard construction/assist units", reason)
        end)

        it("should reject guarding units that can assist", function()
            -- Mock UnitDefs first so WithUnit can copy properties
            _G.UnitDefs = {
                ["armpw"] = { buildOptions = {}, canAssist = false },
                ["armconsul"] = { buildOptions = {}, canAssist = true }
            }

            -- Create a unit that will do the guarding
            local guarderUnitId
            sender:WithUnit("armpw", function(unitId) guarderUnitId = unitId end)

            -- Create a mock unit that can assist
            local assistUnitId
            receiver:WithUnit("armconsul", function(unitId) assistUnitId = unitId end)

            -- Update the service's spring repo with the units
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            local allowed, reason = service:ValidateCommand(guarderUnitId, 1, sender.id, service.springRepo.CMD.GUARD, {assistUnitId}, {}, 0, sender.id)
            assert.is_false(allowed)
            assert.equal("Cannot guard construction/assist units", reason)
        end)

        it("should allow guarding regular units", function()
            -- Mock UnitDefs first so WithUnit can copy properties
            _G.UnitDefs = {
                ["armpw"] = { buildOptions = {}, canAssist = false }
            }

            -- Create a unit that will do the guarding
            local guarderUnitId
            sender:WithUnit("armpw", function(unitId) guarderUnitId = unitId end)

            -- Create a regular unit
            local regularUnitId
            receiver:WithUnit("armpw", function(unitId) regularUnitId = unitId end)

            -- Update the service's spring repo with the units
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            local allowed = service:ValidateCommand(guarderUnitId, 1, sender.id, service.springRepo.CMD.GUARD, {regularUnitId}, {}, 0, sender.id)
            assert.is_true(allowed)
        end)

        it("should reject repairing units under construction", function()
            -- Mock UnitDefs first so WithUnit can copy properties
            _G.UnitDefs = {
                ["armck"] = { buildOptions = {}, canAssist = false }
            }

            -- Create a unit that will do the repairing
            local repairerUnitId
            sender:WithUnit("armck", function(unitId) repairerUnitId = unitId end)

            -- Create a unit under construction
            local underConstructionUnitId
            receiver:WithUnit("armck", function(unitId) underConstructionUnitId = unitId end)

            -- Update the service's spring repo with the units
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            -- Mock Spring.GetUnitHealth to return buildProgress < 1
            service.springRepo.GetUnitHealth = function(unitID)
                return 100, 100, 100, 100, 0.5 -- buildProgress = 0.5 (under construction)
            end

            local allowed, reason = service:ValidateCommand(repairerUnitId, 1, sender.id, service.springRepo.CMD.REPAIR, {underConstructionUnitId}, {}, 0, sender.id)
            assert.is_false(allowed)
            assert.equal("Cannot repair units under construction", reason)
        end)

        it("should allow repairing completed units", function()
            -- Mock UnitDefs first so WithUnit can copy properties
            _G.UnitDefs = {
                ["armck"] = { buildOptions = {}, canAssist = false }
            }

            -- Create a unit that will do the repairing
            local repairerUnitId
            sender:WithUnit("armck", function(unitId) repairerUnitId = unitId end)

            -- Create a completed unit
            local completedUnitId
            receiver:WithUnit("armck", function(unitId) completedUnitId = unitId end)

            -- Update the service's spring repo with the units
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            -- Mock Spring.GetUnitHealth to return buildProgress = 1
            service.springRepo.GetUnitHealth = function(unitID)
                return 100, 100, 100, 100, 1.0 -- buildProgress = 1.0 (completed)
            end

            local allowed = service:ValidateCommand(repairerUnitId, 1, sender.id, service.springRepo.CMD.REPAIR, {completedUnitId}, {}, 0, sender.id)
            assert.is_true(allowed)
        end)
    end)
end)
