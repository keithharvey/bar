-- Runtime Validator: Prevent Excessive Share
-- UI validation concern - checks if requested amounts exceeds any limits set by policies

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Runtime validator with strongly-typed access to transfer results
GG.TeamTransfer.RegisterValidator({
	dependsOn = { SharedEnums.TransferCategory.METAL_TRANSFER, SharedEnums.TransferCategory.ENERGY_TRANSFER }
}, function(ctx, exposeResults)
	-- Only validate actual transfers (not state queries)
	if not ctx.amount or ctx.amount <= 0 then
		return true
	end
	
	-- Use strongly-typed access to transfer results
	local limits
	if ctx.resource == SharedEnums.ResourceType.METAL then
		limits = ctx.MetalTransfer
	elseif ctx.resource == SharedEnums.ResourceType.ENERGY then
		limits = ctx.EnergyTransfer
	else
		return false, "Unknown resource type: " .. tostring(ctx.resource)
	end
	
	-- Check if amount exceeds policy limits using strongly-typed fields
	local maxAllowed = limits.maxShareAmount or limits.amountSendable or 0
	if ctx.amount > maxAllowed then
		return false, "Amount " .. ctx.amount .. " exceeds maximum allowed " .. maxAllowed, maxAllowed
	end
	
	return true
end)
