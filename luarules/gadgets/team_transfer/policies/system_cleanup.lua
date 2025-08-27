---@load-file luaui/types/team_transfer.lua

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")

-- Post-transfer cleanup to prevent exploits and maintain game integrity
GG.TeamTransfer.RegisterPostTransfer(function(transferData)
	-- Handle unit transfer cleanup
	if transferData.unitIDs then
		for _, unitID in ipairs(transferData.unitIDs) do
			-- Prevent load order exploits
			Spring.GiveOrderToUnit(unitID, CMD.LOAD_ONTO, {}, {})
			-- Prevent self-destruct on transfer  
			Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
		end
	end
end)
