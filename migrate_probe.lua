-- Scratch file for exercising the Bulk Migration action end to end.
-- Deliberately unformatted, and using bracket indexing, so two of the three
-- codemod transforms plus stylua all have something visible to do here.
-- Delete along with the throwaway PR that carries it.

local function probe(frame, name)
	local gf = Spring.GetGameFrame()
	local t = Spring.GetGameSeconds()
	if gf > frame then
		Spring.Echo("probe: " .. tostring(name) .. " " .. tostring(t))
	end
	return gf, t
end

return { probe = probe }
