local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.AssistAlly,
    func = function(builder)
		builder:Allied():Guard():Allow()
		builder:Allied():Repair():Allow()
		
        local assistValue = builder.mod_options[ModOptions.Options.AssistAlly]

		if assistValue == SharedEnums.AssistAllyMode.Disabled then
			-- Register validators to prevent assisting inappropriate targets
			builder:RegisterGuardValidator(function(ctx)
				local targetUnitDef = ctx.targetUnitDef
				-- Reject if target has build options (labs) or can assist
				if targetUnitDef and (#targetUnitDef.buildOptions > 0 or targetUnitDef.canAssist) then
					return { ok = false, reason = "Cannot guard construction/assist units" }
				end
				return { ok = true }
			end)

			builder:RegisterRepairValidator(function(ctx)
				-- Reject if target is under construction
				local _, _, _, _, buildProgress = ctx.repositories.springRepo:GetUnitHealth(ctx.targetUnitID)
				if buildProgress and buildProgress < 1 then
					return { ok = false, reason = "Cannot repair units under construction" }
				end
				return { ok = true }
			end)
		end
    end,
    enabled = function(ctx)
        return true
    end
}
return module
