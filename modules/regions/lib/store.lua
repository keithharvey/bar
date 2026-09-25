local Store = {}

---@class RegionStore the regions of this Lua state: one insertion-ordered list, keyed by id. The editor edits it; the game reads it
---@field list Region[] insertion order
---@field byId table<string, Region|nil>
---@field revision integer bumped on every change, so a reader can cache against it

---@param state RegionStore
---@param region Region with an id
---@param beforeId string|nil the id to insert ahead of; nil appends
local function insert(state, region, beforeId)
	local at = #state.list + 1
	if beforeId then
		for i, other in ipairs(state.list) do
			if other.id == beforeId then
				at = i
				break
			end
		end
	end
	table.insert(state.list, at, region)
	state.byId[region.id] = region
	state.revision = state.revision + 1
end

---@param state RegionStore
---@param id string
---@return Region|nil removed
local function remove(state, id)
	local region = state.byId[id]
	if not region then
		return nil
	end
	for i, other in ipairs(state.list) do
		if other == region then
			table.remove(state.list, i)
			break
		end
	end
	state.byId[id] = nil
	state.revision = state.revision + 1
	return region
end

---@param state RegionStore
---@param region Region with an id. Already stored: kept where it is. New: appended, or ahead of beforeId
---@param beforeId string|nil
---@return Region
function Store.Put(state, region, beforeId)
	local id = assert(region.id, "Store.Put: a region needs an id")
	local held = state.byId[id]
	if rawequal(held, region) then
		state.revision = state.revision + 1
		return region
	end
	if held ~= nil then
		remove(state, id)
	end
	insert(state, region, beforeId)
	return region
end

Store.Remove = remove

---@param state RegionStore
---@param typeKey RegionTypeKey|nil
---@return Region[] regions insertion order; a new table
function Store.All(state, typeKey)
	local out = {}
	for _, region in ipairs(state.list) do
		if typeKey == nil or region.type == typeKey then
			out[#out + 1] = region
		end
	end
	return out
end

---@param state RegionStore
---@param typeKey RegionTypeKey|nil every type when nil
---@return Region[] removed
function Store.Clear(state, typeKey)
	local removed = {}
	for i = #state.list, 1, -1 do
		local region = state.list[i]
		if typeKey == nil or region.type == typeKey then
			table.remove(state.list, i)
			state.byId[region.id] = nil
			removed[#removed + 1] = region
		end
	end
	if #removed > 0 then
		state.revision = state.revision + 1
	end
	return removed
end

---@return RegionStore
function Store.New()
	return { list = {}, byId = {}, revision = 0 }
end

return Store
