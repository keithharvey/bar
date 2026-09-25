local AssistTax = require("modules/transfer/lib/assist_tax")
local Construction = require("modules/construction/api")
local ConstructionContract = require("modules/construction/contract")
local ConstructionEnums = require("modules/construction/enums")
local Contract = require("modules/transfer/contract")
local TransferEnums = require("modules/transfer/enums")

Policies.On(ConstructionContract.Build).Unless(Contract.Build.UnaffordableAssistTax, function(ctx)
	local quote = AssistTax.Quote(ctx, Spring)
	return quote ~= nil and not quote.affordable
end)

Policies.On(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.UtilitySharing, function(ctx)
		local mode = ctx.modOptions[TransferEnums.ModOptions.UnitSharingMode]
		return table.contains(Construction.UnitTypesFor(mode), ConstructionEnums.UnitType.Utility)
	end)
