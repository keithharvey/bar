local Builders = require("spec/builders/index")
local SharedEnums = require("luarules.gadgets.team_transfer.shared_enums")
local MetalTransferDefaults = require("luarules.gadgets.team_transfer.default_results.metal_transfer")

describe("MetalTransferDefaults #clear #default_results", function()
    local sender
    local receiver

    before_each(function()
        sender = Builders.Team:new():Human()
            :WithMetal(1000)
            :WithMetalStorage(2000)
        receiver = Builders.Team:new():Human()
            :WithMetal(500)
            :WithMetalStorage(1500)
    end)

    describe("Allow", function()
        it("should set amountSendable to sender's current metal", function()
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Allow(ctx)
            
            assert.equal(1000, result.amountSendable)
        end)

        it("should limit receivable by receiver's available storage space", function()
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Allow(ctx)
            
            local availableSpace = receiver.metal.storage - receiver.metal.current
            assert.equal(1000, availableSpace)
            assert.equal(1000, result.receivable)
        end)

        it("should handle receiver with full storage", function()
            receiver.metal.current = receiver.metal.storage
            
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Allow(ctx)
            
            assert.equal(0, result.receivable)
            assert.equal(0, result.amountSendable)
        end)

        it("should cap amountSendable by receiver's available space", function()
            sender.metal.current = 5000
            receiver.metal.current = 1400
            receiver.metal.storage = 1500
            
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Allow(ctx)
            
            local availableSpace = receiver.metal.storage - receiver.metal.current
            assert.equal(100, availableSpace)
            assert.equal(100, result.amountSendable)
            assert.equal(100, result.receivable)
        end)

        it("should set canShare to true", function()
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Allow(ctx)
            
            assert.is_true(result.canShare)
        end)

        it("should set correct resourceType", function()
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Allow(ctx)
            
            assert.equal(SharedEnums.ResourceType.METAL, result.resourceType)
        end)
    end)

    describe("Deny", function()
        it("should return zero amounts", function()
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Deny(ctx)
            
            assert.equal(0, result.amountSendable)
            assert.equal(0, result.receivable)
            assert.equal(0, result.taxedPortion)
            assert.equal(0, result.untaxedPortion)
        end)

        it("should set canShare to false", function()
            local ctx = {
                sender = sender,
                receiver = receiver
            }
            
            local result = MetalTransferDefaults.Deny(ctx)
            
            assert.is_false(result.canShare)
        end)
    end)
end)
