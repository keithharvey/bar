local ModuleHandler = require("modules/module_handler")

local Notes = {}

---@param facts table the notes Facts from transfer's contract.lua
---@param record table
---@param modOptions table<string, any>
---@return table<string, any>
function Notes.For(facts, record, modOptions)
	return ModuleHandler.Enrich(facts, modOptions, record, modOptions)
end

return Notes
