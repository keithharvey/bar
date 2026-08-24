-- Scratch file for CI validation. Not for merge.
local function classify(a, b)
	local unusedLocal = 1
	if not (a ~= b) then
		return "equal"
	end
	local unit = Spring.GetUnitDefID(a)
	return unit.name
end

local function boom()
	return someUndefinedGlobalForCiXyz(1,2)
end

return { classify = classify, boom   =   boom }
