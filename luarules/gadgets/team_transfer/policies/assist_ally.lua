-- Team Transfer Policy: Assist Ally
-- Controls whether units can assist allied construction and repair
-- Blocks guard and repair commands to allied units when disabled

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Check modoption to see if ally assist is disabled
local modOptions = Spring.GetModOptions()
local assistDisabled = modOptions and modOptions.assist_ally == "disabled"

Spring.Log("[ASSIST ALLY POLICY]", LOG.ERROR, "Assist ally policy loading - disabled: " .. tostring(assistDisabled))

-- Only register policy if disabled (when enabled, normal behavior applies)
if not assistDisabled then
	Spring.Log("[ASSIST ALLY POLICY]", LOG.ERROR, "Policy not registering - assist ally enabled")
	return
end

GG.TeamTransfer.RegisterPolicy(SharedEnums.Policies.AssistAlly, function(policy)
	-- Block guard and repair commands to allied units
	policy.ForAlliedCommands.WhenGuard.Deny()
	policy.ForAlliedCommands.WhenRepair.Deny()
end)
