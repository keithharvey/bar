local Repository = {}

---@class RepositoryOptions<T>
---@field admit (fun(candidate: table, id: string|integer, held: T[]): T|nil, string[]|nil)|nil what a candidate becomes on entry, or what is wrong with it; held is what it would stand beside
---@field identify (fun(n: integer): string|integer)|nil the id of the nth entity that arrives without one; the integer itself when absent

---@class RepositoryRefusal
---@field candidate table
---@field problems string[]

---@class Repository<T>
---@field Put fun(candidate: table, beforeId: string|integer|nil): T|nil, string[]|nil
---@field Assign fun(candidates: table[]): T[], RepositoryRefusal[]
---@field Get fun(id: string|integer): T|nil
---@field Remove fun(id: string|integer): T|nil
---@field All fun(where: (fun(entity: T): boolean)|nil): T[]
---@field Clear fun(where: (fun(entity: T): boolean)|nil): T[]
---@field Revision fun(): integer

---@generic T
---@param options RepositoryOptions<T>|nil
---@return Repository<T>
function Repository.New(options)
	local admit = options and options.admit or nil
	local identify = options and options.identify or function(n)
		return n
	end

	local list = {} ---@type table[]
	local byId = {} ---@type table<string|integer, table|nil>
	local revision = 0
	local count = 0

	---@param id string|integer
	local function seen(id)
		local n = tonumber(id)
		if n and n > count and n == math.floor(n) then
			count = n
		end
	end

	---@param taken table<string|integer, any>
	---@return string|integer id
	---@return integer n
	local function nextFree(taken)
		local n = count
		local id
		repeat
			n = n + 1
			id = identify(n)
		until taken[id] == nil
		return id, n
	end

	---@param id string|integer
	---@return integer|nil
	local function indexOf(id)
		for i, entity in ipairs(list) do
			if entity.id == id then
				return i
			end
		end
		return nil
	end

	---@param candidate table
	---@param id string|integer
	---@param held table[]
	---@return table|nil entity
	---@return string[]|nil problems
	local function entering(candidate, id, held)
		if admit == nil then
			candidate.id = id
			return candidate, nil
		end
		local entity, problems = admit(candidate, id, held)
		if entity == nil then
			return nil, problems or {}
		end
		entity.id = id
		return entity, nil
	end

	local repository = {}

	repository.Put = function(candidate, beforeId)
		local id, n = candidate.id, nil
		if id == nil then
			id, n = nextFree(byId)
		end
		local replaced = byId[id]
		local held = list
		if replaced ~= nil then
			held = {}
			for _, entity in ipairs(list) do
				if entity ~= replaced then
					held[#held + 1] = entity
				end
			end
		end
		local entity, problems = entering(candidate, id, held)
		if entity == nil then
			return nil, problems
		end
		if n then
			count = n
		else
			seen(id)
		end
		local at = replaced ~= nil and indexOf(id) or nil
		if at and beforeId == nil then
			list[at] = entity
		else
			if at then
				table.remove(list, at)
			end
			local before = beforeId ~= nil and indexOf(beforeId) or nil
			table.insert(list, before or (#list + 1), entity)
		end
		byId[id] = entity
		revision = revision + 1
		return entity, nil
	end

	repository.Assign = function(candidates)
		local taken = {} ---@type table<string|integer, boolean>
		for _, candidate in ipairs(candidates) do
			if candidate.id ~= nil then
				taken[candidate.id] = true
				seen(candidate.id)
			end
		end
		local accepted, index, refused = {}, {}, {}
		for _, candidate in ipairs(candidates) do
			local id, n = candidate.id, nil
			if id == nil then
				id, n = nextFree(taken)
			end
			local entity, problems
			if index[id] ~= nil then
				problems = { "another with id " .. tostring(id) .. " was offered first" }
			else
				entity, problems = entering(candidate, id, accepted)
			end
			if entity == nil then
				refused[#refused + 1] = { candidate = candidate, problems = problems or {} }
			else
				if n then
					count = n
					taken[id] = true
				end
				accepted[#accepted + 1] = entity
				index[id] = entity
			end
		end
		list, byId = accepted, index
		revision = revision + 1
		return accepted, refused
	end

	repository.Get = function(id)
		return byId[id]
	end

	repository.Remove = function(id)
		local at = indexOf(id)
		if at == nil then
			return nil
		end
		local entity = table.remove(list, at)
		byId[id] = nil
		revision = revision + 1
		return entity
	end

	repository.All = function(where)
		local out = {}
		for _, entity in ipairs(list) do
			if where == nil or where(entity) then
				out[#out + 1] = entity
			end
		end
		return out
	end

	repository.Clear = function(where)
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

	repository.Revision = function()
		return revision
	end

	return repository
end

return Repository
