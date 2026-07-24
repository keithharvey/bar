-- The busted suite never loads widgets/gadgets, so substrate-era namespaces
-- (detach-bar-modules BAR.*, spring-split Engine*) can leak into carried
-- files and only fail at engine load time. This gate makes the leak loud.
describe("substrate globals", function()
	local FORBIDDEN = {
		{ pattern = [[\bBAR\.(I18N|Utilities|Debug|Lava|GetModOptionsCopy)\b]], name = "BAR.* (detach-bar-modules)" },
		{ pattern = [[\bEngineSynced\b]], name = "EngineSynced (spring-split)" },
		{ pattern = [[Builders\.Engine]], name = "Builders.Engine* (spring-split)" },
	}

	for _, forbidden in ipairs(FORBIDDEN) do
		it("does not reference " .. forbidden.name, function()
			local handle = io.popen("git grep -lE '" .. forbidden.pattern .. "' -- '*.lua' ':!spec/no_substrate_globals_spec.lua' 2>/dev/null")
			local hits = handle:read("*a")
			handle:close()
			assert.are.equal("", hits, "substrate namespace leaked into:\n" .. hits)
		end)
	end
end)
