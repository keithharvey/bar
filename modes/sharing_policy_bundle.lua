local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local Opt = ModeEnums.ModOptions

-- A mode is a named bundle of policies; modOptions is the serialization the
-- lobby/SPADS transport understands. Each policy serializes only the options it
-- owns: structural choices take the structure lock, numeric dials the dial lock.
local Serializers = {
	["unit.deny"] = function(_p, lock)
		return { [Opt.UnitSharingMode] = { value = ModeEnums.UnitFilterCategory.None, locked = lock.structure } }
	end,
	["resource.deny"] = function(_p, lock)
		return { [Opt.ResourceSharingEnabled] = { value = false, locked = lock.structure } }
	end,
	["resource.tax"] = function(p, lock)
		return { [Opt.TaxResourceSharingAmount] = { value = p.rate, locked = lock.dial, ui = p.ui } }
	end,
	["assist.deny"] = function(_p, lock)
		return { [Opt.AlliedAssistMode] = { value = ModeEnums.AlliedAssistMode.Disabled, locked = lock.structure } }
	end,
	["reclaim.deny"] = function(_p, lock)
		return { [Opt.AlliedUnitReclaimMode] = { value = ModeEnums.AlliedUnitReclaimMode.Disabled, locked = lock.structure } }
	end,
	["take.deny"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = ModeEnums.TakeMode.Disabled, locked = lock.structure } }
	end,
}

local M = {}

M.Serializers = Serializers

---Serialize a policy bundle to the modOptions table a ModeConfig declares.
---@param bundle ModePolicyRef[]
---@return table<string, ModOptionConfig>
function M.toModOptions(bundle)
	return ModeBuilder.ToModOptions(Serializers, bundle)
end

return M
