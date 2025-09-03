
-- Integration-style test for sharingoptions preset "building_unlocks"

local describe = describe
local it = it
local assert = assert
local before_each = before_each

local VFS = VFS or _G.VFS

describe("sharingoptions: building_unlocks preset", function()

	local API
	local Pipeline

	before_each(function()
		API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
		Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
		_G.TeamTransferPipeline = Pipeline
		_G.GG = _G.GG or {}
		_G.GG.TeamTransfer = API
		-- Enable sharing mode and preset options
		local orig = Spring.GetModOptions
		Spring.GetModOptions = function()
			return {
				sharing_mode = "building_unlocks",
				building_unlocks_sharing = true,
				unit_sharing_mode = "enabled",
				tax_resource_sharing_amount = 0,
			}
		end
		-- Register policies used by preset
		dofile("luarules/gadgets/team_transfer/policies/building_unlocks_sharing.lua")
		dofile("luarules/gadgets/team_transfer/policies/unit_sharing_mode.lua")
		Spring.GetModOptions = orig
	end)

	it("unlocks features progressively via buildings", function()
		local sender, receiver = 1, 2
		-- No storages -> command flags false
		_G.Spring.GetTeamUnits = function(team) return {} end
		local cmdExpose = Pipeline.QueryExposeByPredicates(API.Scope.Allied, API.TransferCategory.CommandValidation, sender, receiver)
		assert.is_false(cmdExpose.allowGuardCommands)
		assert.is_false(cmdExpose.allowRepairCommands)
		-- Add storages and pinpointer
		local defs = VFS.Include("gadgets/team_transfer/mocks.lua")
		local bc = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua").BUILDING_CATEGORIES
		_G.UnitDefs[2001] = { name = "armmstor" }
		_G.UnitDefs[2002] = { name = "armestor" }
		_G.UnitDefs[2003] = { name = "armpin" }
		_G.Spring.GetTeamUnits = function(team) return { 21, 22, 23 } end
		_G.Spring.GetUnitDefID = function(id) return 2000 + id end
		cmdExpose = Pipeline.QueryExposeByPredicates(API.Scope.Allied, API.TransferCategory.CommandValidation, sender, receiver)
		assert.is_true(cmdExpose.allowGuardCommands)
		assert.is_true(cmdExpose.allowRepairCommands)
		-- Unit unlock
		local unitExpose = Pipeline.QueryExposeByPredicates(API.Scope.Allied, API.TransferCategory.UnitTransfer, sender, receiver)
		assert.is_true(unitExpose.canShareUnits)
	end)

end)


