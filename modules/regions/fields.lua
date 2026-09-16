---@class RegionFields the fields more than one type may carry, declared once so the types agree on them
local Fields = {}

---@type RegionField
Fields.Team = { key = "team", label = "Team", kind = "integer", picks = "start" }

---@param base RegionField
---@param overrides table<string, any>|nil
---@return RegionField
function Fields.With(base, overrides)
	local field = {}
	for k, v in pairs(base) do
		field[k] = v
	end
	for k, v in pairs(overrides or {}) do
		field[k] = v
	end
	return field
end

return Fields
