local Contract = require("modules/transport/contract")
local Defs = require("modules/defs/contract")
local TransportEnums = require("modules/transport/enums")

local TransportEnemy = TransportEnums.TransportEnemy

Policies.On(Defs.UnitDef).Apply(Contract.UnitDef.EnemyTransport, function(ctx)
	local which = ctx.modOptions[TransportEnums.ModOptions.TransportEnemy]
	if which == TransportEnemy.None then
		ctx.def.transportbyenemy = false
	elseif which == TransportEnemy.NotCommanders and ctx.def.customparams.iscommander then
		ctx.def.transportbyenemy = false
	end
end)
