local Repository = {}

-- A list of entities in memory, each under a string id: the one it brings, or the next a counter gives.
---@generic T
---@return Repository<T>
function Repository.New()
	local list = {} ---@type table[]
	local byId = {} ---@type table<string, table|nil>
	local revision = 0
	local count = 0

	-- An id once seen is never minted: the counter stays past the largest number that has come through.
	---@param id string
	local function seen(id)
		local n = tonumber(id)
		if n and n > count and n == math.floor(n) then
			count = n
		end
	end

	---@param taken table<string, any>
	---@return string
	local function mint(taken)
		repeat
			count = count + 1
		until taken[tostring(count)] == nil
		return tostring(count)
	end

	---@class Repository<T>
	local repository = {}

	-- Under the id the entity brings, where one already under that id stood; under a new id when it brings none.
	---@param entity T
	---@return T
	function repository.Put(entity)
		if entity.id == nil then
			entity.id = mint(byId)
		else
			seen(entity.id)
		end
		local at = #list + 1
		for i, held in ipairs(list) do
			if held.id == entity.id then
				at = i
			end
		end
		list[at] = entity
		byId[entity.id] = entity
		revision = revision + 1
		return entity
	end

	-- The repository holds exactly these, in this order.
	---@param entities T[]
	---@return T[]
	function repository.Assign(entities)
		local index = {} ---@type table<string, table|nil>
		for _, entity in ipairs(entities) do
			if entity.id ~= nil then
				assert(index[entity.id] == nil, "Repository: two entities under id " .. tostring(entity.id))
				index[entity.id] = entity
				seen(entity.id)
			end
		end
		local held = {}
		for i, entity in ipairs(entities) do
			if entity.id == nil then
				entity.id = mint(index)
				index[entity.id] = entity
			end
			held[i] = entity
		end
		list, byId = held, index
		revision = revision + 1
		return held
	end

	---@param id string
	---@return T|nil
	function repository.Get(id)
		return byId[id]
	end

	---@param id string
	---@return T|nil
	function repository.Remove(id)
		for i, entity in ipairs(list) do
			if entity.id == id then
				table.remove(list, i)
				byId[id] = nil
				revision = revision + 1
				return entity
			end
		end
		return nil
	end

	---@param where (fun(entity: T): boolean)|nil
	---@return T[]
	function repository.All(where)
		local out = {}
		for _, entity in ipairs(list) do
			if where == nil or where(entity) then
				out[#out + 1] = entity
			end
		end
		return out
	end

	---@param where (fun(entity: T): boolean)|nil
	---@return T[] removed
	function repository.Clear(where)
		local kept, removed = {}, {}
		for _, entity in ipairs(list) do
			if where == nil or where(entity) then
				removed[#removed + 1] = entity
				byId[entity.id] = nil
			else
				kept[#kept + 1] = entity
			end
		end
		if #removed > 0 then
			list = kept
			revision = revision + 1
		end
		return removed
	end

	---@return integer
	function repository.Revision()
		return revision
	end

	return repository
end

return Repository
