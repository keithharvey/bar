local Policy = require("modules/policy")
local Modules = require("modules/enums").Modules
local Defs = require("modules/defs/contract")

---@class TransportApproachContext where a carrier meets the ground: shared by load and unload
---@field goalY number
---@field height number|nil the passenger's model height
---@field reach number|nil nil for a ground transport
---@field distance number|nil

---@class TransportLoadContext: TransportApproachContext
---@field carrierDef table|nil
---@field passengerDef table|nil
---@field allied boolean|nil
---@field ownTeam boolean|nil the passenger is the carrier's own team's
---@field nano boolean|nil the passenger is a nano turret
---@field passengerSpeed number|nil

---@class TransportUnloadContext: TransportApproachContext
---@field nano boolean|nil
---@field groundNormalY number|nil

---@class TransportLoadedSpeedContext
---@field carriesCommander boolean
---@field transportSpeed number elmos per second
---@field dragEnabled boolean the comm_trans_slow rule
---@field framesPerSecond number

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

---@class TransportLoadedSpeedPolicy: PolicySteps<TransportLoadedSpeedContext, number>
---@field Base string the carrier's own speed, in elmos per frame
---@field CommanderDrag string the cap a carried commander puts on it, as a ratio

---@type TransportLoadedSpeedPolicy
local LoadedSpeed = {
	Base = "Base",
	CommanderDrag = "CommanderDrag",
}

---@class TransportUnitDefSteps the steps transport adds to the defs module's unit_def fold
---@field EnemyTransport string transportByEnemy written onto every def from the transportenemy option

---@type TransportUnitDefSteps
local UnitDef = {
	EnemyTransport = "EnemyTransport",
}

---@class TransportContract
---@field Load TransportLoadPolicy
---@field Unload TransportUnloadPolicy
---@field LoadedSpeed TransportLoadedSpeedPolicy
---@field UnitDef TransportUnitDefSteps

return Policy.Contract(Modules.Transport, {
	Load = Policy.Single(Load),
	Unload = Policy.Single(Unload),
	LoadedSpeed = Policy.Product(LoadedSpeed),
	UnitDef = Policy.Contributes(Defs.UnitDef, UnitDef),
})
