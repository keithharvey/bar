local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

describe(SharedEnums.Policies.AssistAlly .. " policy", function()
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
                :WithPolicy(SharedEnums.Policies.AssistAlly)
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
            local springWithRestrictions = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :WithAlliance(sender.id, receiver.id, true)
                :WithModOption(SharedEnums.Policies.AssistAlly, "disabled")
                :Build()

            service = Builders.TeamTransferService.new()
                :WithSpringRepository(springWithRestrictions)
                :WithPolicy(SharedEnums.Policies.AssistAlly)
                :Build()
        end)

        it("should reject guarding units with build options", function()
            -- Create a mock unit with build options (like a lab)
            local labUnitId
            receiver:WithUnit("armlab", function(unitId) labUnitId = unitId end)

            -- Update the service's spring repo with the unit
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            -- Mock UnitDefs to return a unit with build options
            _G.UnitDefs = {
                ["armlab"] = { buildOptions = { "some_unit" }, canAssist = false }
            }

            local allowed, reason = service:ValidateCommand(sender.id, service.springRepo.CMD.GUARD, {labUnitId})
            assert.is_false(allowed)
            assert.equal("Cannot guard construction/assist units", reason)
        end)

        it("should reject guarding units that can assist", function()
            -- Create a mock unit that can assist
            local assistUnitId
            receiver:WithUnit("armconsul", function(unitId) assistUnitId = unitId end)

            -- Update the service's spring repo with the unit
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            -- Mock UnitDefs to return a unit that can assist
            _G.UnitDefs = {
                ["armconsul"] = { buildOptions = {}, canAssist = true }
            }

            local allowed, reason = service:ValidateCommand(sender.id, service.springRepo.CMD.GUARD, {assistUnitId})
            assert.is_false(allowed)
            assert.equal("Cannot guard construction/assist units", reason)
        end)

        it("should allow guarding regular units", function()
            -- Create a regular unit
            local regularUnitId
            receiver:WithUnit("armpw", function(unitId) regularUnitId = unitId end)

            -- Update the service's spring repo with the unit
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            -- Mock UnitDefs to return a regular unit
            _G.UnitDefs = {
                ["armpw"] = { buildOptions = {}, canAssist = false }
            }

            local allowed = service:ValidateCommand(sender.id, service.springRepo.CMD.GUARD, {regularUnitId})
            assert.is_true(allowed)
        end)

        it("should reject repairing units under construction", function()
            -- Create a unit under construction
            local underConstructionUnitId
            receiver:WithUnit("armck", function(unitId) underConstructionUnitId = unitId end)

            -- Update the service's spring repo with the unit
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            -- Mock UnitDefs and Spring.GetUnitHealth to simulate under construction
            _G.UnitDefs = {
                ["armck"] = { buildOptions = {}, canAssist = false }
            }

            -- Mock Spring.GetUnitHealth to return buildProgress < 1
            service.springRepo.GetUnitHealth = function(unitID)
                return 100, 100, 100, 100, 0.5 -- buildProgress = 0.5 (under construction)
            end

            local allowed, reason = service:ValidateCommand(sender.id, service.springRepo.CMD.REPAIR, {underConstructionUnitId})
            assert.is_false(allowed)
            assert.equal("Cannot repair units under construction", reason)
        end)

        it("should allow repairing completed units", function()
            -- Create a completed unit
            local completedUnitId
            receiver:WithUnit("armck", function(unitId) completedUnitId = unitId end)

            -- Update the service's spring repo with the unit
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            -- Mock UnitDefs and Spring.GetUnitHealth to simulate completed unit
            _G.UnitDefs = {
                ["armck"] = { buildOptions = {}, canAssist = false }
            }

            -- Mock Spring.GetUnitHealth to return buildProgress = 1
            service.springRepo.GetUnitHealth = function(unitID)
                return 100, 100, 100, 100, 1.0 -- buildProgress = 1.0 (completed)
            end

            local allowed = service:ValidateCommand(sender.id, service.springRepo.CMD.REPAIR, {completedUnitId})
            assert.is_true(allowed)
        end)
    end)
end)
