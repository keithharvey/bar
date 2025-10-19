local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local UnitSharing = VFS.Include("common/luaUtilities/team_transfer/unit_sharing.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")

local Synced = {
  ValidateUnits = Shared.ValidateUnits,
}

---Execute unit transfer with pre-validated units
---@param ctx UnitTransferContext
---@return UnitTransferResult
function Synced.UnitTransfer(ctx)
  local policyResult = ctx.policyResult

  -- Policy blocks sharing entirely
  if not policyResult.canShare then
    return {
      success = false,
      outcome = "failed",
      reason = "Policy disabled",
      senderTeamId = ctx.senderTeamId,
      receiverTeamId = ctx.receiverTeamId,
      validationResult = ctx.validationResult,
      policyResult = ctx.policyResult
    }
  end

  -- Use validationResult to determine which units to transfer
  local transferredUnits = {}
  local failedUnits = {}

  for _, result in ipairs(ctx.validationResult) do
    if result.ok then
      local success = Spring.TransferUnit(result.unitId, ctx.receiverTeamId, ctx.given or false)
      if success then
        table.insert(transferredUnits, result.unitId)
      else
        table.insert(failedUnits, result.unitId)
      end
    else
      table.insert(failedUnits, result.unitId)
    end
  end

  local success = #transferredUnits > 0

  return {
    outcome = ctx.validationResult.status,
    senderTeamId = ctx.senderTeamId,
    receiverTeamId = ctx.receiverTeamId,
    validationResult = ctx.validationResult,
    policyResult = ctx.policyResult
  }
end

local function CheckTakeCondition(senderTeamID, receiverTeamID)
  -- Check if sender is allied
  if Spring.AreTeamsAllied(senderTeamID, receiverTeamID) then
    -- Loop to see if sender has any active human players
    local playerList = Spring.GetPlayerList() or {}
    for _, playerID in ipairs(playerList) do
      local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID)
      if active and not spectator and teamID == senderTeamID then
        -- Found an active player, so this is NOT the /take condition.
        -- AllowUnitTransfer should proceed to check sharing rules.
        return false
      end
    end
    -- If loop finished without finding an active player, it matches the /take condition.
    -- Allow the transfer, bypassing sharing rules.
    return true
  end
  -- Teams are not allied, not a /take condition.
  return false
end

---Evaluate if a unit should be allowed based on sharing mode
---@param unitDef table Unit definition from UnitDefs
---@param mode string The sharing mode
---@return boolean allowed True if unit should be allowed
function Synced.EvaluateUnitForSharing(unitDef, mode)
  if not unitDef then return false end

  -- Simple cases
  if mode == SharedEnums.UnitSharingMode.Disabled then
    return false
  end

  if mode == SharedEnums.UnitSharingMode.Enabled then
    return true
  end

  local unitType = UnitSharing.classifyUnitDef(unitDef)

  -- Mode-specific logic using enum
  if mode == SharedEnums.UnitSharingMode.CombatUnits then
    return unitType == SharedEnums.UnitType.Combat
  end

  if mode == SharedEnums.UnitSharingMode.Economic then
    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor
  end

  if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor or
    unitType == SharedEnums.UnitType.Utility
  end

  if mode == SharedEnums.UnitSharingMode.T2Cons then
    return unitType == SharedEnums.UnitType.T2Constructor
  end

  if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
    return unitType == SharedEnums.UnitType.Combat or unitType == SharedEnums.UnitType.T2Constructor
  end

  return false
end

---Get per-pair policy (expose) and cache it for UI consumption
---@param ctx PolicyContext
---@return UnitTransferPolicyResult
function Synced.GetPolicy(ctx)
  local mode = Spring.GetModOptions().unit_sharing_mode
  local allowTakeBypass = CheckTakeCondition(ctx.senderTeamId, ctx.receiverTeamId)
  local canShare = ctx.areAlliedTeams and mode ~= SharedEnums.UnitSharingMode.Disabled
  local result = {
    canShare = canShare,
    senderTeamId = ctx.senderTeamId,
    receiverTeamId = ctx.receiverTeamId,
    sharingMode = mode,
    allowTakeBypass = allowTakeBypass,
  }
  return result
end

-- Allowed UnitDefID cache per mode for fast validation
local allowedByMode = {}

local function BuildAllowedCacheForMode(mode)
  if allowedByMode[mode] then return end
  local cache = {}
  for unitDefID, unitDef in pairs(UnitDefs) do
    if Synced.EvaluateUnitForSharing(unitDef, mode) then
      cache[unitDefID] = true
    end
  end
  allowedByMode[mode] = cache
end

function Synced.IsUnitDefIdAllowed(unitDefId, mode)
  if not unitDefId or not mode then return false end
  BuildAllowedCacheForMode(mode)
  return allowedByMode[mode][unitDefId] == true
end

return Synced
