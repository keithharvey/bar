local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Framework (Loader)',
		desc    = 'Loads team_transfer/main.lua which centralizes Allow* callins',
		author  = 'Devin',
		layer   = -1000,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

VFS.Include("luarules/gadgets/team_transfer/main.lua")

return false
