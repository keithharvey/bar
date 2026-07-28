---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local ConstructionEnums = require("modules/construction/enums")
local Helpers = require("modules/transfer/spec/support/action_helpers")
local ResourceShared = require("modules/transfer/resource/shared")
local TransferEnums = require("modules/transfer/enums")
local UnitShared = require("modules/transfer/unit/shared")
local withSpring, unitDefsById = Helpers.withSpring, Helpers.unitDefsById

describe("transfer.resources", function()
	local registry ---@type { byName: table<string, ActionDescriptor>, list: ActionDescriptor[] }

	setup(function()
		ModuleHandler.ResetCaches()
		registry = ModuleHandler.LoadActions(Modules.Transfer)
	end)

	---@param name string
	---@param request table
	---@return boolean allowed, string? reason
	local function validate(name, request)
		local fn = assert(registry.byName[name].validate, name .. " registers validate")
		return fn(request)
	end

	it("validate refuses a request the api did not resolve a grant for", function()
		assert.is_false(validate("resources", { from = 0, to = 1, resource = "metal", amount = 5 }))
	end)

	describe("resources", function()
		it("validate refuses a resource that is not metal or energy", function()
			local allowed = validate("resources", { from = 0, to = 1, resource = "ore", amount = 5 })
			assert.is_false(allowed)
		end)

		it("validate refuses a non-positive amount", function()
			assert.is_false(validate("resources", { from = 0, to = 1, resource = "metal", amount = 0 }))
		end)

		it("execute deducts the taxed amount from the sender and credits the receiver", function()
			local sender = Builders.Team:new():Human():WithMetal(500):WithMetalStorage(1000)
			local receiver = Builders.Team:new():Human():WithMetal(0):WithMetalStorage(1000)
			local mock = Builders.Spring
				.new()
				:WithTeam(sender)
				:WithTeam(receiver)
				:WithAlliance(sender.id, receiver.id, true)
				:WithTeamRulesParam(sender.id, "numActivePlayers", 1)
				:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
				:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, 0.5)
				:Build()
			withSpring(mock, function()
				local ResourceTransfer = require("modules/transfer/resource/synced")
				local ContextFactoryModule = require("modules/transfer/context_factory")
				local factory = ContextFactoryModule.create(mock)
				for _, id in ipairs({ sender.id, receiver.id }) do
					ResourceTransfer.CacheTeamFactor(mock, id, "metal", factory.policy(id, id))
				end

				local request = {
					from = sender.id,
					to = receiver.id,
					resource = "metal",
					amount = 100,
					grant = ResourceShared.GetCachedPolicyResult(sender.id, receiver.id, "metal", mock),
				}
				assert.is_true(validate("resources", request))
				local result = registry.byName.resources.execute(request)
				assert.is_true(result.success)
				assert.are.equal(100, result.received)
				assert.are.equal(200, result.sent)
				assert.are.equal(300, mock.GetTeamResources(sender.id, "metal"))
				assert.are.equal(100, mock.GetTeamResources(receiver.id, "metal"))
			end)
		end)
	end)
end)
