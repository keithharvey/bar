local ConstructionEnums = require("modules/construction/enums")
local Contract = require("modules/transfer/contract")
local TransferEnums = require("modules/transfer/enums")
local take = Contract.Take

Policies.On(take).Answer(take.TakeTerms, function(ctx)
	local modOptions = ctx.modOptions
	return {
		mode = modOptions[TransferEnums.ModOptions.TakeMode] or TransferEnums.TakeMode.Enabled,
		delaySeconds = tonumber(modOptions[TransferEnums.ModOptions.TakeDelaySeconds]) or 30,
		delayCategory = modOptions[TransferEnums.ModOptions.TakeDelayCategory]
			or ConstructionEnums.UnitCategory.Resource,
	}
end)
