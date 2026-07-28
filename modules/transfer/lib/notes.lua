local ModuleHandler = require("modules/module_handler")

local Notes = {}

---@param facts table the notes Facts from transfer's contract.lua
---@param record table
---@return table<string, any>
function Notes.For(facts, record)
	return ModuleHandler.Enrich(facts, Spring.GetModOptions(), record)
end

return Notes
