local Policy = require("modules/policy")

local NAP_MAX_SPEED = 0.5
local COMMANDER_DRAG_SPEED = 120

---@class TransportApproachContext where a carrier meets the ground: shared by load and unload
---@field goalY number
---@field height number|nil
---@field reach number|nil
---@field distance number|nil

---@param ctx TransportApproachContext
---@return boolean
local function submerged(ctx)
	return ctx.height == nil or ctx.goalY + ctx.height < 0
end

---@param ctx TransportApproachContext
---@return boolean
local function withinReach(ctx)
	return ctx.reach == nil or (ctx.distance or 0) <= ctx.reach
end

-- May this carrier pick that passenger up here
--
---@class TransportLoadContext: TransportApproachContext
---@field carrierDef table|nil
---@field passengerDef table|nil
---@field allied boolean|nil
---@field ownTeam boolean|nil
---@field nano boolean|nil
---@field passengerSpeed number|nil

---@class TransportLoadPolicy: PolicySteps<TransportLoadContext, boolean>
---@field Submerged "Submerged"
---@field WithinReach "WithinReach"
---@field MovingEnemy "MovingEnemy"
---@field AlliedNano "AlliedNano"
---@field Allowed "Allowed"

---@type TransportLoadPolicy
local Load = {
	Submerged = "Submerged",
	WithinReach = "WithinReach",
	MovingEnemy = "MovingEnemy",
	AlliedNano = "AlliedNano",
	Allowed = "Allowed",
}
Policy.Single(Load)

Policies.On(Load)
	.Step(Load.Submerged, function(ctx)
		if submerged(ctx) then
			return false
		end
	end)
	.Step(Load.WithinReach, function(ctx)
		if not withinReach(ctx) then
			return false
		end
	end)
	.Step(Load.MovingEnemy, function(ctx)
		if ctx.allied == false and (ctx.passengerSpeed or 0) >= NAP_MAX_SPEED then
			return false
		end
	end)
	.Step(Load.AlliedNano, function(ctx)
		if ctx.nano == true and ctx.allied == true and ctx.ownTeam ~= true then
			return false
		end
	end)
	.Return(Load.Allowed, function()
		return true
	end)

-- May this carrier set its passenger down here
--
---@class TransportUnloadContext: TransportApproachContext
---@field nano boolean|nil
---@field groundNormalY number|nil

---@class TransportUnloadPolicy: PolicySteps<TransportUnloadContext, boolean>
---@field Submerged "Submerged"
---@field WithinReach "WithinReach"
---@field NanoOnSlope "NanoOnSlope"
---@field Allowed "Allowed"

---@type TransportUnloadPolicy
local Unload = {
	Submerged = "Submerged",
	WithinReach = "WithinReach",
	NanoOnSlope = "NanoOnSlope",
	Allowed = "Allowed",
}
Policy.Single(Unload)

Policies.On(Unload)
	.Step(Unload.Submerged, function(ctx)
		if submerged(ctx) then
			return false
		end
	end)
	.Step(Unload.WithinReach, function(ctx)
		if not withinReach(ctx) then
			return false
		end
	end)
	.Step(Unload.NanoOnSlope, function(ctx)
		if ctx.nano and (ctx.goalY < 0 or (ctx.groundNormalY or 1) < 0.9) then
			return false
		end
	end)
	.Return(Unload.Allowed, function()
		return true
	end)

-- How fast a loaded carrier flies: its own speed, dragged down by a commander aboard when the rule is on
--
---@class TransportLoadedSpeedContext
---@field carriesCommander boolean
---@field transportSpeed number
---@field dragEnabled boolean
---@field framesPerSecond number
---@field product number|nil what the steps have multiplied so far; the Return hands it back

---@class TransportLoadedSpeedPolicy: PolicySteps<TransportLoadedSpeedContext, number>
---@field Base "Base"
---@field CommanderDrag "CommanderDrag"
---@field Result "Result"

---@type TransportLoadedSpeedPolicy
local LoadedSpeed = {
	Base = "Base",
	CommanderDrag = "CommanderDrag",
	Result = "Result",
}
Policy.Single(LoadedSpeed)

Policies.On(LoadedSpeed)
	.Step(LoadedSpeed.Base, function(ctx)
		ctx.product = (ctx.product or 1) * (ctx.transportSpeed / ctx.framesPerSecond)
	end)
	.Step(LoadedSpeed.CommanderDrag, function(ctx)
		if ctx.dragEnabled and ctx.carriesCommander then
			ctx.product = (ctx.product or 1) * (COMMANDER_DRAG_SPEED / ctx.transportSpeed)
		end
	end)
	.Return(LoadedSpeed.Result, function(ctx)
		if ctx.product == nil then
			error("loaded_speed: no step gave a factor; the owner's Base must")
		end
		return ctx.product
	end)

---@class (partial) TransportContract
local Contract = {}
Contract.Load = Load
Contract.Unload = Unload
Contract.LoadedSpeed = LoadedSpeed

return Contract
