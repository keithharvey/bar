local ResourceShared = require("modules/transfer/resource/shared")
local UnitShared = require("modules/transfer/unit/shared")
local UnitUnsynced = require("modules/transfer/unit/unsynced")

local TransferUnsynced = {}

TransferUnsynced.Resources = ResourceShared
TransferUnsynced.Units = UnitShared
TransferUnsynced.Units.ShareUnits = UnitUnsynced.ShareUnits

return TransferUnsynced
