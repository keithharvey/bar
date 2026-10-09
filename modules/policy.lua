local Policy = {}

---@class PolicyContext a context that carries the match's modoptions: every Facts context, since the live set is read off them, and a policy's when its steps read them
---@field springRepo Spring the engine, or a spec's stand-in: every provider reads the match through its context
---@field modOptions table<string, string|number|boolean>

---@class PolicySteps<C, T>: { [string]: string } step names for one policy; C is the context its steps receive, T what the pipeline returns

---@class PolicyFacts<C>: { [string]: string } the facts a decision reads, named; C is the context providers receive

---@class AssembledPolicy<C, T>: { [integer]: PolicyStep } one policy as LoadPolicies hands it back, contributions applied; the Return, if any, is last

---@class PolicyIdentity
---@field owner string the module whose policy or context this is
---@field category string its name within the module
---@field steps boolean|nil true for a policy: steps, evaluated
---@field facts boolean|nil true for facts: provided, not evaluated

---@generic T: table
---@param steps T enum of step names
---@return T
function Policy.Single(steps)
	assert(type(steps) == "table" and getmetatable(steps) == nil, "Policy.Single(steps)")
	return setmetatable(steps, { __steps = true })
end

---@generic C, T
---@param target PolicySteps<C, T> the target policy's steps, as its owner declared them
---@param names table<string, string>
---@return table<string, string>
function Policy.Contributes(target, names)
	local identity = Policy.IdentityOf(target)
	assert(identity ~= nil and not identity.facts, "Policy.Contributes(target, names): target must be a policy's steps")
	assert(type(names) == "table" and getmetatable(names) == nil, "Policy.Contributes(target, names)")
	return setmetatable(names, { __contributes = identity })
end

---@generic T: table
---@param facts T enum of fact names
---@return T
function Policy.Facts(facts)
	assert(type(facts) == "table" and getmetatable(facts) == nil, "Policy.Facts(facts)")
	return setmetatable(facts, { __facts = true })
end

---@param member string
---@return string
function Policy.KeyOf(member)
	return (member
		:gsub("(%u)", function(c)
			return "_" .. c:lower()
		end)
		:sub(2))
end

---@param owner string the module's name
---@param members table PascalCase name -> a policy's step enum (Single), Contributes or Facts
---@param source string|nil where they were declared, for messages
function Policy.Declare(owner, members, source)
	local where = source and (source .. ": ") or "Policy.Declare: "
	for member, steps in pairs(members) do
		local meta = type(steps) == "table" and getmetatable(steps) or nil
		assert(
			meta ~= nil and (meta.__steps or meta.__facts or meta.__contributes),
			where .. tostring(member) .. " must declare itself: Single(...), Contributes(...) or Facts(...)"
		)
		assert(
			meta.__policy == nil,
			where .. tostring(member) .. " is already " .. tostring(meta.__policy and meta.__policy.owner) .. "'s"
		)
		local category = Policy.KeyOf(member)
		if meta.__contributes then
			meta.__policy = { owner = owner, category = category, contributes = meta.__contributes }
		elseif meta.__facts then
			meta.__policy = { owner = owner, category = category, facts = true }
		else
			meta.__policy = { owner = owner, category = category, steps = true }
		end
	end
end

---@param target table
---@return boolean
function Policy.IsFacts(target)
	local meta = type(target) == "table" and getmetatable(target) or nil
	return meta ~= nil and meta.__facts == true
end

---@param steps table
---@return PolicyIdentity|nil
function Policy.IdentityOf(steps)
	local meta = type(steps) == "table" and getmetatable(steps) or nil
	return meta and meta.__policy or nil
end

---@class PolicyOp
---@field op "add"|"replace"|"remove"
---@field kind "step"|"return"|nil add only
---@field name string
---@field evaluate function|nil
---@field after string|nil
---@field before string|nil

---@class PolicyChain<C, T>
---@field steps table|nil the identity this chain builds against
---@field Step fun(name: string, evaluate: fun(ctx: C): T|nil): PolicyChain<C, T> a non-nil return ends the pipeline with that value; nil hands the context to the next step
---@field Return fun(name: string, evaluate: fun(ctx: C): T|nil): PolicyChain<C, T> the owner's last step, one per policy, always last: what the pipeline returns when no step before it said anything
---@field After fun(name: string): PolicyChain<C, T> place the step just added after the named step
---@field Before fun(name: string): PolicyChain<C, T> place the step just added before the named step
---@field Replace fun(name: string, evaluate: fun(ctx: C): T|nil): PolicyChain<C, T> the named step, with this evaluate
---@field Remove fun(name: string): PolicyChain<C, T>
---@field Build fun(): PolicyOp[]

---@generic C, T
---@param steps PolicySteps<C, T>|nil the policy's steps, as the owner declared them
---@return PolicyChain<C, T>
function Policy.Chain(steps)
	local ops = {} ---@type PolicyOp[]
	local chain = { steps = steps }
	local returned = false

	---@param verb "Step"|"Return"
	---@param name string
	---@param evaluate function
	local function add(verb, name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyChain: " .. verb .. "(name, evaluate)")
		assert(not returned, "PolicyChain: no step follows Return")
		ops[#ops + 1] = { op = "add", kind = verb == "Return" and "return" or "step", name = name, evaluate = evaluate }
	end

	---@param modifier string
	---@return PolicyOp
	local function lastAdded(modifier)
		local last = ops[#ops]
		assert(last ~= nil and last.op == "add", "PolicyChain: ." .. modifier .. " must follow a Step")
		assert(last.kind == "step", "PolicyChain: Return is always last; ." .. modifier .. " cannot place it")
		assert(last.after == nil and last.before == nil, "PolicyChain: a step is placed once")
		return last
	end

	chain.Step = function(name, evaluate)
		add("Step", name, evaluate)
		return chain
	end
	chain.Return = function(name, evaluate)
		add("Return", name, evaluate)
		returned = true
		return chain
	end
	chain.After = function(name)
		lastAdded("After").after = name
		return chain
	end
	chain.Before = function(name)
		lastAdded("Before").before = name
		return chain
	end
	chain.Replace = function(name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyChain: Replace(name, evaluate)")
		ops[#ops + 1] = { op = "replace", name = name, evaluate = evaluate }
		return chain
	end
	chain.Remove = function(name)
		assert(type(name) == "string", "PolicyChain: Remove(name)")
		ops[#ops + 1] = { op = "remove", name = name }
		return chain
	end
	chain.Build = function()
		return ops
	end
	return chain
end

---@param steps PolicyStep[] the policy under assembly, mutated in place
---@param ops PolicyOp[]
---@param origin string for error messages: the file the ops came from
function Policy.Assemble(steps, ops, origin)
	local function indexOf(name)
		for i, step in ipairs(steps) do
			if step.name == name then
				return i
			end
		end
		return nil
	end
	local function returnAt()
		for i, step in ipairs(steps) do
			if step.kind == "return" then
				return i
			end
		end
		return nil
	end
	for _, op in ipairs(ops) do
		if op.op == "add" then
			assert(indexOf(op.name) == nil, origin .. ": the policy already has a step named " .. op.name)
			local pinned = returnAt()
			local at = #steps + 1
			if op.kind == "return" then
				assert(
					pinned == nil,
					origin .. ": the policy already has a Return, " .. (pinned and steps[pinned].name or "")
				)
			elseif pinned ~= nil then
				at = pinned
			end
			if op.after ~= nil then
				local anchor = assert(indexOf(op.after), origin .. ": no step named " .. op.after .. " to go after")
				assert(anchor ~= pinned, origin .. ": nothing goes after " .. op.after .. ": it is the Return")
				at = anchor + 1
			elseif op.before ~= nil then
				at = assert(indexOf(op.before), origin .. ": no step named " .. op.before .. " to go before")
			end
			table.insert(steps, at, { name = op.name, kind = op.kind, evaluate = op.evaluate })
		elseif op.op == "replace" then
			local at = assert(indexOf(op.name), origin .. ": no step named " .. op.name .. " to replace")
			steps[at] = { name = op.name, kind = steps[at].kind, evaluate = op.evaluate }
		elseif op.op == "remove" then
			table.remove(steps, assert(indexOf(op.name), origin .. ": no step named " .. op.name .. " to remove"))
		end
	end
end

---@class PolicyProvision
---@field names string[]
---@field evaluate function one producer; each returned value assigns its name, in order
---@field default boolean|nil the owner's answer for a slot nobody provides

---@class PolicyEnrichment<C>
---@field facts table|nil the facts this enrichment provides for
---@field Provide (fun(name: string, evaluate: fun(ctx: C): any): PolicyEnrichment<C>)|(fun(name: string, name2: string, evaluate: fun(ctx: C): any, any): PolicyEnrichment<C>)|(fun(name: string, name2: string, name3: string, evaluate: fun(ctx: C): any, any, any): PolicyEnrichment<C>) the facts a producer answers, one name per return value, then the producer
---@field Default fun(name: string, evaluate: fun(ctx: C): any): PolicyEnrichment<C> the owner's value for a fact when no module provides it
---@field Build fun(): PolicyProvision[]

---@param facts table|nil the facts, as the owner declared them
---@return PolicyEnrichment<any>
function Policy.Enrichment(facts)
	local ops = {} ---@type PolicyProvision[]
	local chain = { facts = facts }
	chain.Provide = function(...)
		local n = select("#", ...)
		local evaluate = n >= 2 and select(n, ...) or nil
		assert(type(evaluate) == "function", "PolicyEnrichment: Provide(name, ..., evaluate)")
		local names = {}
		for i = 1, n - 1 do
			local name = select(i, ...)
			assert(type(name) == "string", "PolicyEnrichment: Provide(name, ..., evaluate)")
			names[i] = name
		end
		ops[#ops + 1] = { names = names, evaluate = evaluate }
		return chain
	end
	---@param name string a fact the contract declares
	---@param evaluate function
	chain.Default = function(name, evaluate)
		assert(type(name) == "string" and type(evaluate) == "function", "PolicyEnrichment: Default(name, evaluate)")
		ops[#ops + 1] = { names = { name }, evaluate = evaluate, default = true }
		return chain
	end
	chain.Build = function()
		return ops
	end
	return chain
end

return Policy
