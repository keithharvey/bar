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

	---@return string
	local function mint()
		repeat
			count = count + 1
		until byId[tostring(count)] == nil
		return tostring(count)
	end

	---@class Repository<T>
	local repository = {}

	-- A new entity: under the id it brings, which must be free, or under the next the counter gives.
	---@param entity T
	---@return T
	function repository.Create(entity)
		if entity.id == nil then
			entity.id = mint()
		else
			assert(byId[entity.id] == nil, "Repository: an entity under id " .. tostring(entity.id) .. " is held")
			seen(entity.id)
		end
		list[#list + 1] = entity
		byId[entity.id] = entity
		revision = revision + 1
		return entity
	end

	-- The entity under its id, replaced where it stood.
	---@param entity T
	---@return T
	function repository.Update(entity)
		assert(byId[entity.id] ~= nil, "Repository: no entity under id " .. tostring(entity.id))
		for i, held in ipairs(list) do
			if held.id == entity.id then
				list[i] = entity
			end
		end
		byId[entity.id] = entity
		revision = revision + 1
		return entity
	end

	---@param id string
	---@return T|nil
	function repository.Get(id)
		return byId[id]
	end

	---@param id string
	---@return T|nil
	function repository.Delete(id)
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
