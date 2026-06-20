--- Unit validation helpers for advplayerslist.lua
---
--- Validation is lazy and memoised per selection. ValidateUnits' partition (which
--- selected units are shareable) depends only on the *sender's* tech-resolved sharing
--- modes plus global stun config -- never on the receiver beyond the cheap canShare
--- short-circuit. So every shareable ally produces the identical partition, and we
--- compute it at most once per selection instead of once per player on every
--- SelectionChanged. Rows pull their result on demand via GetPlayerUnitValidation.
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")

local UnitValidationHelpers = {}

-- The selection these memos describe (nil when nothing is selected).
local currentSelection = nil
-- Memoised ValidateUnits result for a shareable (canShare) receiver under currentSelection.
local sharedPartition = nil
-- Memoised trivial result for a non-shareable receiver (ValidateUnits short-circuits).
local deniedResult = nil
-- Persistent backing tables for the two memo results: ValidateUnits fills these in place
-- (table lifting) so a fresh result isn't allocated on every selection. They never alias --
-- shareable and denied receivers each get their own -- so both can be live in one draw pass.
local sharedScratch = {}
local deniedScratch = {}

---Record the active selection and drop the per-selection memos. Cheap: no per-player
---work happens here -- the partition is computed lazily the first time a row needs it.
---@param selectedUnits number[]?
function UnitValidationHelpers.SetSelection(selectedUnits)
  currentSelection = (selectedUnits and #selectedUnits > 0) and selectedUnits or nil
  sharedPartition = nil
  deniedResult = nil
end

---Drop the memos without touching the selection. Used when our own unit-sharing policy
---changes (SharePolicyChanged): the modes feeding the partition moved, so it's stale.
function UnitValidationHelpers.InvalidateValidations()
  sharedPartition = nil
  deniedResult = nil
end

---Validate the current selection for a single receiver, memoised. Returns nil when
---nothing is selected (callers treat nil as "no validation needed").
---@param myTeamID number
---@param receiverTeamID number
---@return UnitValidationResult | nil
function UnitValidationHelpers.GetPlayerUnitValidation(myTeamID, receiverTeamID)
  if not currentSelection then
    return nil
  end

  local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, receiverTeamID, Spring)
  if not policyResult.canShare then
    -- canShare false makes ValidateUnits short-circuit to an empty partition that is
    -- the same for every denied receiver, so compute it once and reuse.
    if not deniedResult then
      deniedResult = UnitShared.ValidateUnits(policyResult, currentSelection, Spring, nil, deniedScratch)
    end
    return deniedResult
  end

  -- Identical for every shareable receiver (modes are the sender's), so compute once.
  if not sharedPartition then
    sharedPartition = UnitShared.ValidateUnits(policyResult, currentSelection, Spring, nil, sharedScratch)
  end
  return sharedPartition
end

return UnitValidationHelpers
