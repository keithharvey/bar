local AssistTax = require("modules/transfer/lib/assist_tax")
local Construction = require("modules/construction/api")
local ConstructionEnums = require("modules/construction/enums")
local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local TransferEnums = require("modules/transfer/enums")

---@type ConstructionContract
local ConstructionContract = Policies.Contract(Modules.Construction)

-- A build step an ally helps with is taxed, and one the helper cannot pay for does not happen
--
---@class TransferConstructionBuildSteps: PolicySteps<ConstructionBuildContext, boolean>
---@field UnaffordableAssistTax "UnaffordableAssistTax"

---@type TransferConstructionBuildSteps
local Build = {
	UnaffordableAssistTax = "UnaffordableAssistTax",
}
Policy.Contributes(ConstructionContract.Build, Build)

-- construction's Build refuses with false; this guard has to know that, and say it itself
Policies.On(Build).Step(Build.UnaffordableAssistTax, function(ctx)
	local quote = AssistTax.Quote(ctx, ctx.springRepo)
	if quote ~= nil and not quote.affordable then
		return false
	end
end)

-- Utility buildings may change hands between allies when the sharing mode says so
--
Policies.For(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.UtilitySharing, function(ctx)
		local mode = tostring(ctx.modOptions[TransferEnums.ModOptions.UnitSharingMode])
		return table.contains(Construction.UnitTypesFor(mode), ConstructionEnums.UnitType.Utility)
	end)

---@class (partial) TransferContract
local Contract = {}
Contract.Build = Build

return Contract
