local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "API Team Transfer",
		desc = "Bridges team transfer functionality from GG to WG for widget access",
		author = "Devin",
		date = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

function widget:Initialize()
	if not GG.TeamTransfer then
		Spring.Log("TeamTransferAPI", LOG.WARNING, "GG.TeamTransfer not available during widget initialization")
		return
	end
	
	WG['TeamTransfer'] = {}
	
	WG['TeamTransfer'].getUnitSharingMode = GG.TeamTransfer.getUnitSharingMode
	WG['TeamTransfer'].countUnshareable = GG.TeamTransfer.countUnshareable
	WG['TeamTransfer'].blockMessage = GG.TeamTransfer.blockMessage
	WG['TeamTransfer'].shouldShowShareButton = GG.TeamTransfer.shouldShowShareButton
	
	WG['TeamTransfer'].ResourceShareTax = GG.TeamTransfer.ResourceShareTax
	
	WG['TeamTransfer'].isUnitShareAllowedByMode = GG.TeamTransfer.isUnitShareAllowedByMode
	WG['TeamTransfer'].clearCache = GG.TeamTransfer.clearCache
	WG['TeamTransfer'].getCacheStats = GG.TeamTransfer.getCacheStats
	
	Spring.Log("TeamTransferAPI", LOG.INFO, "Successfully bridged GG.TeamTransfer to WG['TeamTransfer']")
end

function widget:Shutdown()
	WG['TeamTransfer'] = nil
end
