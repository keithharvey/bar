-- Scratch file for CI validation. Not for merge.
local function classify(a, b)
	local unusedLocal = 1
	if a == b then
		return "equal"
	end
	local unit = Spring.GetUnitDefID(a)
	return unit.name
end

return { classify = classify }
