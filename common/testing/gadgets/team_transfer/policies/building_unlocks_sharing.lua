
-- Busted unit test for building_unlocks_sharing policy

local describe = describe
local it = it
local assert = assert
local before_each = before_each

local VFS = VFS or _G.VFS

describe("building_unlocks_sharing policy", function()

	local API
	local Pipeline
	local mocks

	before_each(function()
		API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
		Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
		_G.TeamTransferPipeline = Pipeline
		_G.GG = _G.GG or {}
		_G.GG.TeamTransfer = API
		mocks = VFS.Include("gadgets/team_transfer/mocks.lua")
		-- Pretend modoption is enabled
		local origGetModOptions = Spring.GetModOptions
		Spring.GetModOptions = function() return { building_unlocks_sharing = true } end
		-- Register the policy
		dofile("luarules/gadgets/team_transfer/policies/building_unlocks_sharing.lua")
		-- restore
		Spring.GetModOptions = origGetModOptions
	end)

	it("denies guard/repair when storages not built", function()
		-- No storage built: no categories seen
		_G.Spring.GetTeamUnits = function(team) return {} end
		local sender, receiver = 1, 2
		local res = Pipeline.Initialize(API.TransferCategory.CommandValidation, sender, receiver, {})
		-- Expect default allows from pipeline, but our policy contributes allow=false when predicate fails
		-- Query expose via predicate engine
		local expose = Pipeline.QueryExposeByPredicates(API.Scope.Allied, API.TransferCategory.CommandValidation, sender, receiver)
		assert.is_truthy(expose)
		-- With no storages, implied denials should have set allowGuard/Repair to false
		assert.is_false(expose.allowGuardCommands)
		assert.is_false(expose.allowRepairCommands)
	end)

	it("allows guard/repair when both storages built and allows unit sharing with pinpointer", function()
		-- Make team have units categorized as METAL_STORAGE and ENERGY_STORAGE and PINPOINTER
		local cats = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua").BUILDING_CATEGORIES
		local unitForCat = {
			[cats.METAL_STORAGE] = { name = "armmstor" },
			[cats.ENERGY_STORAGE] = { name = "armestor" },
			[cats.PINPOINTER] = { name = "armpin" },
		}
		_G.UnitDefs[1001] = unitForCat[cats.METAL_STORAGE]
		_G.UnitDefs[1002] = unitForCat[cats.ENERGY_STORAGE]
		_G.UnitDefs[1003] = unitForCat[cats.PINPOINTER]
		_G.Spring.GetTeamUnits = function(team) return { 11, 12, 13 } end
		_G.Spring.GetUnitDefID = function(id) return 1000 + id end
		local sender, receiver = 1, 2
		-- Command validation
		local cmdExpose = Pipeline.QueryExposeByPredicates(API.Scope.Allied, API.TransferCategory.CommandValidation, sender, receiver)
		assert.is_truthy(cmdExpose)
		assert.is_true(cmdExpose.allowGuardCommands)
		assert.is_true(cmdExpose.allowRepairCommands)
		-- Unit transfer
		local unitExpose = Pipeline.QueryExposeByPredicates(API.Scope.Allied, API.TransferCategory.UnitTransfer, sender, receiver)
		assert.is_truthy(unitExpose)
		assert.is_true(unitExpose.canShareUnits)
	end)

end)


