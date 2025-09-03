-- Runtime Validator: Prevent Excessive Share
-- UI validation concern - checks if requested amounts exceeds any limits set by policies

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Register metal transfer validator with strongly-typed access to metal transfer results
GG.TeamTransfer.RegisterMetalTransferValidator(function(ctx, metalResults)
	-- Only validate actual transfers (not state queries)
	if not ctx.amount or ctx.amount <= 0 or ctx.resource ~= SharedEnums.ResourceType.METAL then
		return true
	end
	
	-- Check if amount exceeds metal policy limits using strongly-typed fields
	local maxAllowed = metalResults.maxShareAmount or metalResults.amountSendable or 0
	if ctx.amount > maxAllowed then
		return false, "Metal amount " .. ctx.amount .. " exceeds maximum allowed " .. maxAllowed, tonumber(maxAllowed)
	end
	
	return true
end)

-- Register energy transfer validator with strongly-typed access to energy transfer results
GG.TeamTransfer.RegisterEnergyTransferValidator(function(ctx, energyResults)
	-- Only validate actual transfers (not state queries)
	if not ctx.amount or ctx.amount <= 0 or ctx.resource ~= SharedEnums.ResourceType.ENERGY then
		return true
	end
	
	-- Check if amount exceeds energy policy limits using strongly-typed fields
	local maxAllowed = energyResults.maxShareAmount or energyResults.amountSendable or 0
	if ctx.amount > maxAllowed then
		return false, "Energy amount " .. ctx.amount .. " exceeds maximum allowed " .. maxAllowed, tonumber(maxAllowed)
	end
	
	return true
end)
