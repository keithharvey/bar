local Builders = require("spec/builders/index")
local SharedEnums = require("luarules.gadgets.team_transfer.shared_enums")
local ResourceTransfer = require("luarules.gadgets.team_transfer.actions.resource_transfer")

describe("ResourceTransfer action #clear #actions", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()
    local spring = Builders.SpringRepository.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :Build()

    describe("basic resource transfer", function()
        local result

        before_each(function()
            sender.metal.current = 1000
            sender.energy.current = 1000
            receiver.metal.current = 500
            receiver.energy.current = 500
        end)

        it("should transfer metal without tax when untaxed portion covers full amount", function()
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                resourceType = SharedEnums.ResourceType.METAL,
                desiredAmount = 100,
                policyResult = {
                    resourceType = SharedEnums.ResourceType.METAL,
                    amountSendable = 500,
                    amountReceivable = 500,
                    untaxedPortion = 150,  -- More than desired amount
                    taxRate = 0.3
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = ResourceTransfer(ctx)

            assert.is_true(result.success)
            assert.equal(100, result.sent)
            assert.equal(100, result.received)
        end)

        it("should apply tax when desired amount exceeds untaxed portion", function()
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                resourceType = SharedEnums.ResourceType.METAL,
                desiredAmount = 200,
                policyResult = {
                    resourceType = SharedEnums.ResourceType.METAL,
                    amountSendable = 500,
                    amountReceivable = 500,
                    untaxedPortion = 100,  -- Less than desired amount
                    taxRate = 0.3
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = ResourceTransfer(ctx)

            assert.is_true(result.success)
            -- Untaxed: 100, Taxed: 100
            -- Sender pays: 100 + (100 / 0.7) = 100 + 142.86 = 242.86
            -- Receiver gets: 100 + 100 = 200 (taxed portion is sent as 142.86, receiver gets 100)
            assert.is_near(242.86, result.sent, 0.1)
            assert.is_near(200, result.received, 0.1)
        end)

        it("should handle 100% tax rate", function()
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                resourceType = SharedEnums.ResourceType.METAL,
                desiredAmount = 200,
                policyResult = {
                    resourceType = SharedEnums.ResourceType.METAL,
                    amountSendable = 500,
                    amountReceivable = 500,
                    untaxedPortion = 100,
                    taxRate = 1.0  -- 100% tax
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = ResourceTransfer(ctx)

            assert.is_true(result.success)
            -- Untaxed: 100, Taxed: 100
            -- Sender pays: 100 (tax rate of 1 means sender pays full amount)
            -- Receiver gets:  0 = 100 (tax rate of 1 means no taxed portion reaches receiver)
            assert.equal(100, result.sent)
            assert.equal(100, result.received)
        end)

        it("should limit transfer to amountSendable", function()
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                resourceType = SharedEnums.ResourceType.METAL,
                desiredAmount = 1000,  -- More than allowed
                policyResult = {
                    resourceType = SharedEnums.ResourceType.METAL,
                    amountSendable = 300,  -- Limit
                    amountReceivable = 9999,
                    untaxedPortion = 100,
                    taxRate = 0.2
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = ResourceTransfer(ctx)

            assert.is_true(result.success)
            -- Limited to 300, so: Untaxed: 100, Taxed: 200
            -- Sender pays: 100 + (200 / 0.8) = 100 + 250 = 350
            -- Receiver gets: 100 + 200 = 300
            assert.is_near(350, result.sent, 0.1)
            assert.is_near(300, result.received, 0.1)
        end)
    end)

    describe("CalculateSenderTaxedAmount helper", function()
        it("caps by amountSendable and amountReceivable and computes sender cost", function()
            local policyResult = {
                resourceType = SharedEnums.ResourceType.ENERGY,
                amountSendable = 820,  -- A=400, S=1000, r=0.3 => 400 + 600*0.7
                amountReceivable = 1000,
                untaxedPortion = 400,
                taxRate = 0.3
            }

            local desired = 820
            local res = ResourceTransfer.CalculateSenderTaxedAmount(policyResult, desired)
            -- cost = 400 + 420/0.7 = 1000
            assert.is_near(1000, res.sentAmount, 0.01)
            assert.equal(820, res.receivedAmount)
        end)

        it("caps desired by amountReceivable when it is lower", function()
            local policyResult = {
                resourceType = SharedEnums.ResourceType.ENERGY,
                amountSendable = 500,
                amountReceivable = 300,
                untaxedPortion = 0,
                taxRate = 0.7
            }
            local res = ResourceTransfer.CalculateSenderTaxedAmount(policyResult, 999)
            assert.equal(300, res.receivedAmount)
            assert.is_near(1000, res.sentAmount, 0.01) -- 300/(1-0.7)
        end)
    end)
end)
