local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
local UnitSharing = VFS.Include("common/luaUtilities/team_transfer/unit_sharing.lua")

local Shared = {}

local FieldTypes = PolicyShared.FieldTypes
Shared.UnitPolicyFields = {
  canShare = FieldTypes.boolean,
  unitSharingMode = FieldTypes.string,
  allowTakeBypass = FieldTypes.boolean,
}

---Validate a list of unitIds under current mode
---Returns a structured result object designed for UI consumption.
---We don't make decisions here on how to display unit names etc, we just collate the data and let the UI decide.
---Note the `out` mechanism is so we can avoid memory allocations in gui_advplayerslist when checking the current unit selection. This function's simplicity/factoring is severely limited by the fact we can't afford to allocate tables in the UI thread.
---@param out UnitValidationResult?
---@param policyResult UnitTransferPolicyResult -- note that policyResult is useless right now but is passed in for future use
---@param unitIds number[]
---@return UnitValidationResult
function Shared.ValidateUnits(out, policyResult, unitIds)
  if not out then
    out = {
      status = SharedEnums.UnitValidationOutcome.Failure,
      validUnitCount = 0,
      validUnitCategoryCount = 0,
      validUnitNames = {},
      invalidUnitCount = 0,
      invalidUnitCategoryCount = 0,
      invalidUnitNames = {},
    }
  end

  out.invalidUnitCount = 0
  out.validUnitCount = 0
  out.validUnitNames = {}
  out.invalidUnitCategoryCount = 0
  out.validUnitCategoryCount = 0
  out.invalidUnitNames = {}

  if (not policyResult.canShare) or (not unitIds or #unitIds == 0) then
    return out
  end

  local mode = Shared.GetGlobals()
  local seenValidNames = {}
  local seenInvalidNames = {}

  for _, unitId in ipairs(unitIds) do
    local unitDefID = Spring.GetUnitDefID(unitId)
    if unitDefID then
      local ok = Shared.IsUnitDefIdAllowed(unitDefID, mode)
      local unitName = UnitDefs[unitDefID].translatedHumanName or UnitDefs[unitDefID].name

      if ok then
        out.validUnitCount = out.validUnitCount + 1
        if not seenValidNames[unitName] then
          seenValidNames[unitName] = true
          out.validUnitCategoryCount = out.validUnitCategoryCount + 1
          table.insert(out.validUnitNames, unitName)
        end
      else
        out.invalidUnitCount = out.invalidUnitCount + 1
        if not seenInvalidNames[unitName] then
          seenInvalidNames[unitName] = true
          out.invalidUnitCategoryCount = out.invalidUnitCategoryCount + 1
          table.insert(out.invalidUnitNames, unitName)
        end
      end
    end
  end

  if out.validUnitCount > 0 and out.invalidUnitCount == 0 then
    out.status = SharedEnums.UnitValidationOutcome.Success
  elseif out.validUnitCount > 0 and out.invalidUnitCount > 0 then
    out.status = SharedEnums.UnitValidationOutcome.PartialSuccess
  else
    out.status = SharedEnums.UnitValidationOutcome.Failure
  end

  return out
end

---UI getter for per-pair policy expose from cache
---@param senderTeamId number
---@param receiverTeamId number
---@return UnitTransferPolicyResult
function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId)
  local baseKey = Shared.MakeBaseKey(receiverTeamId)
  local serialized = Spring.GetTeamRulesParam(senderTeamId, baseKey)
  if not serialized then
    -- default to deny
    ---@type UnitTransferPolicyResult
    return {
      senderTeamId = senderTeamId,
      receiverTeamId = receiverTeamId,
      canShare = false,
      sharingMode = SharedEnums.UnitSharingMode.Disabled,
      allowTakeBypass = false
    }
  end
  return Shared.DeserializePolicy(serialized, senderTeamId, receiverTeamId)
end

---Serialize unit policy expose to compact string
---@param policy table
---@return string
function Shared.SerializePolicy(policy)
  return PolicyShared.Serialize(Shared.UnitPolicyFields, policy)
end

---Deserialize unit policy expose from string
---@param serialized string
---@param senderId number
---@param receiverId number
---@return UnitTransferPolicyResult
function Shared.DeserializePolicy(serialized, senderId, receiverId)
  return PolicyShared.Deserialize(Shared.UnitPolicyFields, serialized, {
    senderTeamId = senderId,
    receiverTeamId = receiverId,
  })
end

---Get globals published by the module
---@param unitDef table
---@param mode string
---@return boolean
local function EvaluateUnitForSharing(unitDef, mode)
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

  if mode == SharedEnums.UnitSharingMode.Constructors then
    return unitType == SharedEnums.UnitType.Constructor or unitType == SharedEnums.UnitType.T2Constructor
  end

  if mode == SharedEnums.UnitSharingMode.Assistable then
    return unitType == SharedEnums.UnitType.Constructor or unitType == SharedEnums.UnitType.T2Constructor or
    unitType == SharedEnums.UnitType.Economic
  end

  if mode == SharedEnums.UnitSharingMode.MetalExtractors then
    return unitType == SharedEnums.UnitType.MetalExtractor
  end

  if mode == SharedEnums.UnitSharingMode.Energy then
    return unitType == SharedEnums.UnitType.Energy
  end

  if mode == SharedEnums.UnitSharingMode.Defense then
    return unitType == SharedEnums.UnitType.Defense
  end

  if mode == SharedEnums.UnitSharingMode.Intel then
    return unitType == SharedEnums.UnitType.Intel
  end

  -- Default to false for unknown modes
  return false
end

---@return any unitSharingMode
---@return table<number, boolean> allowedList
function Shared.GetGlobals()
  local mode = Spring.GetModOptions().unit_sharing_mode

  -- hydrate fast global allow list once per mode
  if not Shared._allowedList or Shared._allowedListMode ~= mode then
    local set = {}
    for unitDefID, unitDef in pairs(UnitDefs) do
      if EvaluateUnitForSharing(unitDef, mode) then
        set[unitDefID] = true
      end
    end
    Shared._allowedList = set
    Shared._allowedListMode = mode
  end

  return mode, Shared._allowedList
end

---Fast check for a unitDefID under allowed list (shared classifier)
---@param unitDefID number
---@return boolean
function Shared.IsShareableDef(unitDefID)
  if not unitDefID then return false end
  local _mode, allowedList = Shared.GetGlobals() -- ensures allowed list is hydrated
  return allowedList[unitDefID] == true
end

---Check if a unitDefID is allowed under a specific sharing mode
---@param unitDefID number
---@param mode string
---@return boolean
function Shared.IsUnitDefIdAllowed(unitDefID, mode)
  if not unitDefID or not mode then return false end

  -- First check if it's in the allowed list
  if not Shared.IsShareableDef(unitDefID) then
    return false
  end

  -- Then check mode-specific rules
  local unitDef = UnitDefs[unitDefID]
  if not unitDef then return false end

  if mode == SharedEnums.UnitSharingMode.Disabled then
    return false
  end

  if mode == SharedEnums.UnitSharingMode.Enabled then
    return true
  end

  local unitType = UnitSharing.classifyUnitDef(unitDef)

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

return Shared
