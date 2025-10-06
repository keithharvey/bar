local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@param builder DSL
local function systemCleanupPolicy(builder)
	builder:RegisterPostUnitTransfer(function(context)
		local springRepo = context.repositories.springRepo
		local CMD = springRepo.CMD
		for _, unitID in ipairs(context.transferResult.successfulUnitIds) do
			springRepo:GiveOrderToUnit(unitID, CMD.LOAD_ONTO, {}, {})
			springRepo:GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
		end
	end)
end

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.SystemCleanup,
    func = systemCleanupPolicy,
    enabled = function(ctx)
        return true
    end
}
return module
