commit f3fbabc98bb2803ed3aafd653b3d516d851526fc
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Sat Oct 25 11:15:55 2025 -0600

    fix: resource transfer messages, i18n.interpolate can handle too many variables
    
    I believe a rebasing master broke my resource send chat messages because it was attempting to highlight resource text. I fixed this but got irritated at how interpolation works along the way. We can now send many named variables to interpolation and as long as we're using the named paramter pattern instead of the string interpolation pattern we're fine to send too many. This simplifies my comms variable creation (which was all idempotent anyway) and allows me to pass "resourceType" as part of the payload to gui_chat.
    
    My main concern here is that I was too precious with the previous implicit key based resourceType determination. Like am I the only caller and all of this code exists for no reason? Whatever it's fine.

diff --git a/common/luaUtilities/team_transfer/resource_transfer_comms.lua b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
index a927bedc34..dbd92829e1 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_comms.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
@@ -1,4 +1,6 @@
 local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+local Cache = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
+local FieldTypes = Cache.FieldTypes
 
 local Comms = {
   ResourceCommunicationCase = SharedEnums.ResourceCommunicationCase,
@@ -67,6 +69,22 @@ function Comms.TooltipText(policyResult)
   end
 end
 
+Comms.SendTransferChatMessageProtocol = {
+  receivedAmount = FieldTypes.string,
+  sentAmount = FieldTypes.string,
+  taxRatePercentage = FieldTypes.string,
+  sentAmountUntaxed = FieldTypes.string,
+  resourceShareThreshold = FieldTypes.string,
+}
+
+Comms.SendTransferChatMessageProtocolHighlights = {
+  receivedAmount = true,
+  sentAmount = true,
+  taxRatePercentage = false,
+  sentAmountUntaxed = true,
+  resourceShareThreshold = true,
+}
+
 --- Send chat messages for completed resource transfers
 ---@param transferResult ResourceTransferResult
 ---@param policyResult ResourcePolicyResult
@@ -75,30 +93,27 @@ function Comms.SendTransferChatMessages(transferResult, policyResult)
     local resourceType = policyResult.resourceType
     local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
     local case = Comms.DecideCommunicationCase(policyResult)
+    local cumulativeUntaxed = math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)
+    local chatParams = {
+      receivedAmount = math.floor(transferResult.received),
+      sentAmount = FormatNumberForUI(transferResult.sent),
+      taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100 + 0.5),
+      sentAmountUntaxed = FormatNumberForUI(cumulativeUntaxed),
+      resourceShareThreshold = FormatNumberForUI(policyResult.resourceShareThreshold),
+      resourceType = resourceType,
+    }
 
+    local key
     if case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
-      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
-        pascalResourceType .. ':receivedAmount=' .. math.floor(transferResult.received))
+      key = 'ui.playersList.chat.sent' .. pascalResourceType
     elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
-      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
-        pascalResourceType ..
-        'Taxed:receivedAmount=' ..
-        math.floor(transferResult.received) ..
-        ':sentAmount=' ..
-        math.floor(transferResult.sent) .. ':taxRatePercentage=' .. math.floor(policyResult.taxRate * 100 + 0.5))
+      key = 'ui.playersList.chat.sent' .. pascalResourceType .. 'Taxed'
     elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
-      local cumulativeUntaxed = math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)
-      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
-        pascalResourceType ..
-        'TaxedThreshold:receivedAmount=' ..
-        math.floor(transferResult.received) ..
-        ':sentAmount=' ..
-        math.floor(transferResult.sent) ..
-        ':taxRatePercentage=' ..
-        math.floor(policyResult.taxRate * 100 + 0.5) ..
-        ':sentAmountUntaxed=' ..
-        math.floor(cumulativeUntaxed) .. ':resourceShareThreshold=' .. math.floor(policyResult.resourceShareThreshold))
+      key = 'ui.playersList.chat.sent' .. pascalResourceType .. 'TaxedThreshold'
     end
+
+    local serialized = Cache.Serialize(Comms.SendTransferChatMessageProtocol, chatParams)
+    Spring.SendLuaRulesMsg('msg:' .. key .. ':' .. serialized)
   end
 end
 
diff --git a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
index d6bfca8ee1..5eac733d85 100644
--- a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
+++ b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
@@ -1,10 +1,10 @@
 local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
-local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
 local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
+local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
 
 local TeamTransfer = {}
 
-TeamTransfer.Units = UnitShared
 TeamTransfer.Resources = ResourceShared
+TeamTransfer.Units = UnitShared
 
 return TeamTransfer
diff --git a/language/en/interface.json b/language/en/interface.json
index 7a8cf65196..f11ffa8d41 100644
--- a/language/en/interface.json
+++ b/language/en/interface.json
@@ -123,11 +123,11 @@
 				"giveMetal": "I sent %{amount} metal to %{name}",
 				"giveEnergy": "I sent %{amount} energy to %{name}",
 				"sentMetal": "Sent %{receivedAmount}m",
-				"sentMetalTaxed": "Sent %{receivedAmount}m, spent %{sentAmount}m at %{taxRatePercentage}% overhead",
-				"sentMetalTaxedThreshold": "Sent %{receivedAmount}m, spent %{sentAmount}m at %{taxRatePercentage}% overhead (free used %{sentAmountUntaxed}/%{resourceShareThreshold}m)",
+				"sentMetalTaxed": "Sent %{receivedAmount}m, spent %{sentAmount}m at %{taxRatePercentage}%% overhead",
+				"sentMetalTaxedThreshold": "Sent %{receivedAmount}m, spent %{sentAmount}m at %{taxRatePercentage}%% overhead (free used %{sentAmountUntaxed}/%{resourceShareThreshold}m)",
 				"sentEnergy": "Sent %{receivedAmount}e",
-				"sentEnergyTaxed": "Sent %{receivedAmount}e, spent %{sentAmount}e at %{taxRatePercentage}% overhead",
-				"sentEnergyTaxedThreshold": "Sent %{receivedAmount}e, spent %{sentAmount}e at %{taxRatePercentage}% overhead (free used %{sentAmountUntaxed}/%{resourceShareThreshold}e)",
+				"sentEnergyTaxed": "Sent %{receivedAmount}e, spent %{sentAmount}e at %{taxRatePercentage}%% overhead",
+				"sentEnergyTaxedThreshold": "Sent %{receivedAmount}e, spent %{sentAmount}e at %{taxRatePercentage}%% overhead (free used %{sentAmountUntaxed}/%{resourceShareThreshold}e)",
 				"takeTeam": "I took %{name}.",
 				"takeTeamAmount": "I took %{name}: %{units} units, %{energy} energy and %{metal} metal."
 			}
diff --git a/luaui/Widgets/gui_chat.lua b/luaui/Widgets/gui_chat.lua
index e0607cd832..27289ec968 100644
--- a/luaui/Widgets/gui_chat.lua
+++ b/luaui/Widgets/gui_chat.lua
@@ -25,6 +25,7 @@ local LineTypes = {
 }
 
 local utf8 = VFS.Include('common/luaUtilities/utf8.lua')
+local TeamTransfer = VFS.Include("common/luaUtilities/team_transfer/team_transfer_unsynced.lua")
 
 local L_DEPRECATED = LOG.DEPRECATED
 local isDevSingle = (Spring.Utilities.IsDevMode() and Spring.Utilities.Gametype.IsSinglePlayer())
@@ -621,18 +622,49 @@ local function addChatLine(gameFrame, lineType, name, nameText, text, orgLineID,
 		local params = string.split(text, ':')
 		local t = {}
 		if params[1] then
-			for k,v in pairs(params) do
-				if k > 1 then
-					local pair = string.split(v, '=')
-					if pair[2] then
-						if playernames[pair[2]] then
-							t[ pair[1] ] = getPlayerColorString(pair[2], gameFrame)..playernames[pair[2]][7]..msgColor
-						elseif params[1]:lower():find('energy', nil, true) then
-							t[ pair[1] ] = energyValueColor..pair[2]..msgColor
-						elseif params[1]:lower():find('metal', nil, true) then
-							t[ pair[1] ] = metalValueColor..pair[2]..msgColor
+			local resourceType = nil
+			if params[1]:lower():find('energy', nil, true) then
+				resourceType = 'energy'
+			elseif params[1]:lower():find('metal', nil, true) then
+				resourceType = 'metal'
+			end
+			-- Check for explicit resourceType parameter (overrides key-based detection)
+			for i = 2, #params, 2 do
+				local key = params[i]
+				local value = params[i + 1]
+				if key == 'resourceType' and value then
+					resourceType = value
+					break
+				end
+			end
+
+			-- Second pass: process key-value pairs with determined resourceType
+			for i = 2, #params, 2 do
+				local key = params[i]
+				local value = params[i + 1]
+				if key and value then
+					if key == 'resourceType' then
+						-- Skip the resourceType parameter itself
+					elseif playernames[value] then
+						t[key] = getPlayerColorString(value, gameFrame)..playernames[value][7]..msgColor
+					else
+						local shouldHighlight = false
+						if key:lower():find('energy', nil, true) or key:lower():find('metal', nil, true) then
+							shouldHighlight = true
+						else
+							shouldHighlight = TeamTransfer.Resources.SendTransferChatMessageProtocolHighlights[key] == true
+						end
+
+						if shouldHighlight then
+							if resourceType == 'energy' then
+								t[key] = energyValueColor..value..msgColor
+							elseif resourceType == 'metal' then
+								t[key] = metalValueColor..value..msgColor
+							else
+								t[key] = value
+							end
 						else
-							t[ pair[1] ] = pair[2]
+							t[key] = value
 						end
 					end
 				end
diff --git a/modules/i18n/i18nlib/i18n/interpolate.lua b/modules/i18n/i18nlib/i18n/interpolate.lua
index 086cd4cd2d..3b097485e6 100644
--- a/modules/i18n/i18nlib/i18n/interpolate.lua
+++ b/modules/i18n/i18nlib/i18n/interpolate.lua
@@ -30,7 +30,20 @@ local function interpolate(str, vars)
   str = escapeDoublePercent(str)
   str = interpolateVariables(str, vars)
   str = interpolateFormattedVariables(str, vars)
-  str = string.format(str, unpack(vars))
+  -- Handle any remaining % positional placeholders (e.g., %s, %d)
+  -- Only if they exist and vars can be treated as array
+  if str:find('%%') and not str:find('%%{') and not str:find('%%<') then
+    local percentCount = 0
+    for _ in str:gmatch('%%') do
+      percentCount = percentCount + 1
+    end
+    -- For positional placeholders, assume vars[1], vars[2], etc.
+    local args = {}
+    for i = 1, percentCount do
+      args[i] = vars[i] or vars[tostring(i)] or 'nil'
+    end
+    str = string.format(str, unpack(args))
+  end
   str = unescapeDoublePercent(str)
   return str
 end

commit 5d985addd30583da6a06b62109b3c19cee925ea0
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Fri Oct 24 12:43:00 2025 -0600

    unit transfer fixes
    
    I definitely lost this work moving between branches/computers/or during a rebase squash/reorder gone wrong, but yeah second time I've created this function

diff --git a/common/luaUtilities/team_transfer/unit_transfer_shared.lua b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
index fb2ab76d7a..45e640702c 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
@@ -122,47 +122,67 @@ function Shared.DeserializePolicy(serialized, senderId, receiverId)
   })
 end
 
----Get globals published by the module
----@param unitDef table
----@param mode string
----@return boolean
-local function EvaluateUnitForSharing(unitDef, mode)
-  if not unitDef then return false end
-
-  -- Simple cases
+function Shared.GetModeUnitTypes(mode)
   if mode == SharedEnums.UnitSharingMode.Disabled then
-    return false
+    return {}
   end
 
   if mode == SharedEnums.UnitSharingMode.Enabled then
-    return true
+    return {
+      SharedEnums.UnitType.Combat,
+      SharedEnums.UnitType.Economic,
+      SharedEnums.UnitType.Utility,
+      SharedEnums.UnitType.T2Constructor
+    }
   end
 
-  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
-
   if mode == SharedEnums.UnitSharingMode.CombatUnits then
-    return unitType == SharedEnums.UnitType.Combat
+    return {SharedEnums.UnitType.Combat}
   end
 
   if mode == SharedEnums.UnitSharingMode.Economic then
-    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor
+    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor}
   end
 
   if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
-    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor or
-    unitType == SharedEnums.UnitType.Utility
+    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor, SharedEnums.UnitType.Utility}
   end
 
   if mode == SharedEnums.UnitSharingMode.T2Cons then
-    return unitType == SharedEnums.UnitType.T2Constructor
+    return {SharedEnums.UnitType.T2Constructor}
   end
 
   if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
-    return unitType == SharedEnums.UnitType.Combat or unitType == SharedEnums.UnitType.T2Constructor
+    return {SharedEnums.UnitType.Combat, SharedEnums.UnitType.T2Constructor}
+  end
+
+  error("Unknown mode: " .. mode)
+end
+
+local function UnitTypeMatchesMode(unitDef, mode)
+  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
+  local modeUnitTypes = Shared.GetModeUnitTypes(mode)
+  return table.contains(modeUnitTypes, unitType)
+end
+
+
+---Get globals published by the module
+---@param unitDef table
+---@param mode string
+---@return boolean
+local function EvaluateUnitForSharing(unitDef, mode)
+  if not unitDef then return false end
+
+  -- Simple cases
+  if mode == SharedEnums.UnitSharingMode.Disabled then
+    return false
+  end
+
+  if mode == SharedEnums.UnitSharingMode.Enabled then
+    return true
   end
 
-  Spring.Log("unit_transfer_shared", LOG.ERROR, "EvaluateUnitForSharing: unknown mode =", mode)
-  return false
+  return UnitTypeMatchesMode(unitDef, mode)
 end
 
 -- Allowed UnitDefID cache per mode for fast validation

commit 6fd098e42fa9494a6993fc643451ca96d7085c99
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Fri Oct 24 00:46:38 2025 -0600

    dont think these are used

diff --git a/types/team_transfer.lua b/types/team_transfer.lua
index 97509e2145..b14fdd0e5d 100644
--- a/types/team_transfer.lua
+++ b/types/team_transfer.lua
@@ -3,8 +3,6 @@
 
 ---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "guard_transfer" | "repair_transfer" | "reclaim_transfer"
 ---@alias ResourceType "metal" | "energy"
----@alias UnitValidationOutcome "success" | "disabled" | "partial_success"
----@alias SharingMode "disabled" | "enabled" | "limited_sharing"
 
 ---@class ValidationResult
 ---@field ok boolean

commit 288d57bea87493c46ca5d5a57a12dff5825bea6e
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Fri Oct 24 00:40:09 2025 -0600

    mod option magic string

diff --git a/luaui/Widgets/gui_top_bar.lua b/luaui/Widgets/gui_top_bar.lua
index e0690c48fb..0b5033fba9 100644
--- a/luaui/Widgets/gui_top_bar.lua
+++ b/luaui/Widgets/gui_top_bar.lua
@@ -12,6 +12,7 @@ function widget:GetInfo()
 		handler = true, --can use widgetHandler:x()
 	}
 end
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only
 
 -- Configuration
@@ -50,7 +51,7 @@ local numPlayers = Spring.Utilities.GetPlayerCount()
 local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()
 local chobbyLoaded = false
 local isSingle = false
-local resourceSharingEnabled = Spring.GetModOptions().game_resource_sharing_enabled
+local resourceSharingEnabled = Spring.GetModOptions()[SharedEnums.ModOptions.ResourceSharingEnabled] == true
 local gameStarted = (Spring.GetGameFrame() > 0)
 local gameFrame = Spring.GetGameFrame()
 local gameIsOver = false

commit dafec17e8402434091c40760bb630b13cae7d142
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Fri Oct 24 00:36:44 2025 -0600

    del spring.echo

diff --git a/luaui/Widgets/gui_advplayerslist.lua b/luaui/Widgets/gui_advplayerslist.lua
index 63b1d9b46f..43c409fdf5 100644
--- a/luaui/Widgets/gui_advplayerslist.lua
+++ b/luaui/Widgets/gui_advplayerslist.lua
@@ -3399,7 +3399,6 @@ function widget:MousePress(x, y, button)
                                             --Spring_SendCommands("say a: " .. Spring.I18N('ui.playersList.chat.needSupport'))
 											Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needSupport')
                                         else
-                                            Spring.Echo("Calling ShareResources UNIT")
                                             Spring_ShareResources(clickedPlayer.team, "units")
                                             Spring.PlaySoundFile("beep4", 1, 'ui')
                                         end

commit 7c3486201cf110139dbdcdac21e60afaa84d0456
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Fri Oct 24 00:34:44 2025 -0600

    minor fixes (scratch)
    
    Noticed we weren't using scratch objects, which really eliminates the need for packing/unpacking

diff --git a/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua b/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
index 76dcb0c743..4e39ea1f2b 100644
--- a/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
+++ b/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
@@ -9,17 +9,17 @@ local hoverChangeListeners = {}
 
 ---@param listener function
 function API.AddHoverChangeListener(listener)
-    table.insert(hoverChangeListeners, listener)
+  table.insert(hoverChangeListeners, listener)
 end
 
 ---@param listener function
 function API.RemoveHoverChangeListener(listener)
-    for i, existingListener in ipairs(hoverChangeListeners) do
-        if existingListener == listener then
-            table.remove(hoverChangeListeners, i)
-            break
-        end
+  for i, existingListener in ipairs(hoverChangeListeners) do
+    if existingListener == listener then
+      table.remove(hoverChangeListeners, i)
+      break
     end
+  end
 end
 
 ---Handle hover changes and notify about invalid units for the hovered player
@@ -28,31 +28,31 @@ end
 ---@param newHoverTeamID number | nil
 ---@param newHoverPlayerID number | nil
 function API.HandleHoverChange(myTeamID, selectedUnits, newHoverTeamID, newHoverPlayerID)
-    -- Notify hover change listeners
-    API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)
+  -- Notify hover change listeners
+  API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)
 
-    -- Notify about invalid units (or clear them if not hovering)
-    if newHoverTeamID and selectedUnits and #selectedUnits > 0 then
-        local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, newHoverTeamID)
-        local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits)
-        if #validationResult.invalidUnitIds > 0 then
-            API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, validationResult.invalidUnitIds)
-        else
-            -- No invalid units, but still notify to clear any previous invalid state
-            API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
-        end
+  -- Notify about invalid units (or clear them if not hovering)
+  if newHoverTeamID and selectedUnits and #selectedUnits > 0 then
+    local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, newHoverTeamID)
+    local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits)
+    if #validationResult.invalidUnitIds > 0 then
+      API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, validationResult.invalidUnitIds)
     else
-        -- Not hovering or no selected units, clear invalid state
-        API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
+      -- No invalid units, but still notify to clear any previous invalid state
+      API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
     end
+  else
+    -- Not hovering or no selected units, clear invalid state
+    API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
+  end
 end
 
 ---@param newHoverTeamID number | nil
 ---@param newHoverPlayerID number | nil
 function API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)
-    for _, listener in ipairs(hoverChangeListeners) do
-        listener(newHoverTeamID, newHoverPlayerID)
-    end
+  for _, listener in ipairs(hoverChangeListeners) do
+    listener(newHoverTeamID, newHoverPlayerID)
+  end
 end
 
 -- Hover invalid units listeners
@@ -60,26 +60,26 @@ local hoverInvalidUnitsListeners = {}
 
 ---@param listener function
 function API.AddHoverInvalidUnitsListener(listener)
-    table.insert(hoverInvalidUnitsListeners, listener)
+  table.insert(hoverInvalidUnitsListeners, listener)
 end
 
 ---@param listener function
 function API.RemoveHoverInvalidUnitsListener(listener)
-    for i, existingListener in ipairs(hoverInvalidUnitsListeners) do
-        if existingListener == listener then
-            table.remove(hoverInvalidUnitsListeners, i)
-            break
-        end
+  for i, existingListener in ipairs(hoverInvalidUnitsListeners) do
+    if existingListener == listener then
+      table.remove(hoverInvalidUnitsListeners, i)
+      break
     end
+  end
 end
 
 ---@param newHoverTeamID number | nil
 ---@param newHoverPlayerID number | nil
 ---@param invalidUnitIds number[]
 function API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
-    for _, listener in ipairs(hoverInvalidUnitsListeners) do
-        listener(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
-    end
+  for _, listener in ipairs(hoverInvalidUnitsListeners) do
+    listener(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
+  end
 end
 
 return API
diff --git a/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua b/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
index 414750cea3..7ebceba7c1 100644
--- a/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
+++ b/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
@@ -8,6 +8,22 @@ local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_t
 local METAL_POLICY_PREFIX = "metal_"
 local ENERGY_POLICY_PREFIX = "energy_"
 local UNIT_POLICY_PREFIX = "unit_"
+local UNIT_VALIDATION_PREFIX = "unit_validation_"
+
+local metalPlayerScratch = {}
+local energyPlayerScratch = {}
+local unitPlayerScratch = {}
+local validationResultScratch = {}
+
+local UnitValidationFields = {
+  status = true,
+  invalidUnitCount = true,
+  invalidUnitIds = true,
+  invalidUnitNames = true,
+  validUnitCount = true,
+  validUnitIds = true,
+  validUnitNames = true,
+}
 
 local Helpers = {}
 
@@ -16,7 +32,8 @@ local Helpers = {}
 ---@param senderTeamId number
 ---@return ResourcePolicyResult policyResult, string pascalResourceType
 function Helpers.GetPlayerPolicy(player, resourceType, senderTeamId)
-  local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
+  local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or
+  SharedEnums.TransferCategory.EnergyTransfer
   local policyResult = Helpers.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
   local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
   return policyResult, pascalResourceType
@@ -49,31 +66,42 @@ end
 ---@param validationResult UnitValidationResult
 ---@param playerData table
 function Helpers.PackSelectedUnitsValidation(validationResult, playerData)
-    playerData.selectedUnitsValidation = validationResult
+  for field, _ in pairs(UnitValidationFields) do
+    playerData[UNIT_VALIDATION_PREFIX .. field] = validationResult and validationResult[field] or nil
+  end
 end
 
 ---@param playerData table
 function Helpers.ClearSelectedUnitsValidation(playerData)
-    playerData.selectedUnitsValidation = nil
+  for field, _ in pairs(UnitValidationFields) do
+    playerData[UNIT_VALIDATION_PREFIX .. field] = nil
+  end
 end
 
 ---@param playerData table
 ---@return UnitValidationResult | nil
 function Helpers.UnpackSelectedUnitsValidation(playerData)
-    return playerData.selectedUnitsValidation
+  if playerData[UNIT_VALIDATION_PREFIX .. "status"] == nil then
+    return nil
+  end
+  local scratch = validationResultScratch
+  for field, _ in pairs(UnitValidationFields) do
+    scratch[field] = playerData[UNIT_VALIDATION_PREFIX .. field]
+  end
+  return scratch
 end
 
 ---@param playerData table
 ---@param myTeamID number
 ---@param playerTeamID number
 function Helpers.PackAllPoliciesForPlayer(playerData, myTeamID, playerTeamID)
-    -- Pack all policy types for the player
-    Helpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
-    Helpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)
+  -- Pack all policy types for the player
+  Helpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
+  Helpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)
 
-    -- For unit policy, we need to get it from cache and pack it
-    local unitPolicy = UnitShared.GetCachedPolicyResult(myTeamID, playerTeamID)
-    Helpers.PackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, unitPolicy, playerData)
+  -- For unit policy, we need to get it from cache and pack it
+  local unitPolicy = UnitShared.GetCachedPolicyResult(myTeamID, playerTeamID)
+  Helpers.PackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, unitPolicy, playerData)
 end
 
 ---@param playerData table
@@ -81,10 +109,10 @@ end
 ---@param team number
 ---@return table, table, table
 function Helpers.UnpackAllPolicies(playerData, myTeamID, team)
-    local metalPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, myTeamID, team)
-    local energyPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, myTeamID, team)
-    local unitPolicy = Helpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
-    return metalPolicy, energyPolicy, unitPolicy
+  local metalPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, myTeamID, team)
+  local energyPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, myTeamID, team)
+  local unitPolicy = Helpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
+  return metalPolicy, energyPolicy, unitPolicy
 end
 
 ---Unpack policy result for a given transfer category
@@ -94,28 +122,30 @@ end
 ---@param receiverTeamId number
 ---@return table
 function Helpers.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
-  local fields, prefix
+  local fields, prefix, scratch
   if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
     fields = ResourceShared.ResourcePolicyFields
     prefix = METAL_POLICY_PREFIX
+    scratch = metalPlayerScratch
   elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
     fields = ResourceShared.ResourcePolicyFields
     prefix = ENERGY_POLICY_PREFIX
+    scratch = energyPlayerScratch
   elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
     fields = UnitShared.UnitPolicyFields
     prefix = UNIT_POLICY_PREFIX
+    scratch = unitPlayerScratch
   else
     error("Invalid transfer category: " .. transferCategory)
   end
 
-  local result = {
-    senderTeamId = senderTeamId,
-    receiverTeamId = receiverTeamId
-  }
+  scratch.senderTeamId = senderTeamId
+  scratch.receiverTeamId = receiverTeamId
+
   for field, _ in pairs(fields) do
-    result[field] = playerData[prefix .. field]
+    scratch[field] = playerData[prefix .. field]
   end
-  return result
+  return scratch
 end
 
 ---Unpack unit policy result from player data
@@ -155,18 +185,18 @@ end
 ---@param myTeamID number
 ---@param player table
 function Helpers.PackMetalPolicyResult(team, myTeamID, player)
-    -- Get the metal policy and pack it
-    local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.METAL)
-    Helpers.PackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, policyResult, player)
+  -- Get the metal policy and pack it
+  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.METAL)
+  Helpers.PackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, policyResult, player)
 end
 
 ---@param team number
 ---@param myTeamID number
 ---@param player table
 function Helpers.PackEnergyPolicyResult(team, myTeamID, player)
-    -- Get the energy policy and pack it
-    local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.ENERGY)
-    Helpers.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policyResult, player)
+  -- Get the energy policy and pack it
+  local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.ENERGY)
+  Helpers.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policyResult, player)
 end
 
 -- Function to handle selection changes and update validations for all players
@@ -174,17 +204,17 @@ end
 ---@param myTeamID number
 ---@param selectedUnits number[]
 function Helpers.UpdatePlayerUnitValidations(player, myTeamID, selectedUnits)
-    for playerID, playerData in pairs(player) do
-        if playerData.team and playerID ~= myTeamID then
-            if selectedUnits and #selectedUnits > 0 then
-                local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, playerData.team)
-                local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits)
-                Helpers.PackSelectedUnitsValidation(validationResult, playerData)
-            else
-                Helpers.ClearSelectedUnitsValidation(playerData)
-            end
-        end
+  for playerID, playerData in pairs(player) do
+    if playerData.team and playerID ~= myTeamID then
+      if selectedUnits and #selectedUnits > 0 then
+        local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, playerData.team)
+        local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits)
+        Helpers.PackSelectedUnitsValidation(validationResult, playerData)
+      else
+        Helpers.ClearSelectedUnitsValidation(playerData)
+      end
     end
+  end
 end
 
 return Helpers
diff --git a/common/luaUtilities/team_transfer/unit_transfer_shared.lua b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
index ec33292229..fb2ab76d7a 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
@@ -172,7 +172,7 @@ local function BuildAllowedCacheForMode(mode)
   if allowedByMode[mode] then return end
   local cache = {}
   for unitDefID, unitDef in pairs(UnitDefs) do
-  if EvaluateUnitForSharing(unitDef, mode) then
+    if EvaluateUnitForSharing(unitDef, mode) then
       cache[unitDefID] = true
     end
   end
diff --git a/common/luaUtilities/team_transfer/unit_transfer_synced.lua b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
index 5723cc0c58..89c1ef5d5f 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_synced.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
@@ -47,7 +47,8 @@ function Synced.UnitTransfer(ctx)
   local failedUnits = {}
 
   for _, unitId in ipairs(ctx.validationResult.validUnitIds) do
-    local success = Spring.TransferUnit(unitId, ctx.receiverTeamId, ctx.given) -- ctx.given should always be false here because we short-circuit inside AllowResourceTransfer
+    -- ctx.given should always be false here because we short-circuit inside AllowResourceTransfer
+    local success = Spring.TransferUnit(unitId, ctx.receiverTeamId, ctx.given)
     if success then
       table.insert(transferredUnits, unitId)
     else
diff --git a/luarules/gadgets/game_allied_unit_reclaim_mode.lua b/luarules/gadgets/game_allied_unit_reclaim_mode.lua
index c5b8e4b373..35c895fd09 100644
--- a/luarules/gadgets/game_allied_unit_reclaim_mode.lua
+++ b/luarules/gadgets/game_allied_unit_reclaim_mode.lua
@@ -21,7 +21,7 @@ if not gadgetHandler:IsSyncedCode() then
   return false
 end
 
-local reclaimEnabled = Spring.GetModOptions() and Spring.GetModOptions()[SharedEnums.ModOptions.AlliedUnitReclaimMode] == SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted
+local reclaimEnabled = Spring.GetModOptions()[SharedEnums.ModOptions.AlliedUnitReclaimMode] == SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted
 if reclaimEnabled then
   return
 end
@@ -49,7 +49,8 @@ function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdO
     if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
       return false
     end
-  elseif (cmdID == CMD.GUARD) then -- Also block guarding allied units that can reclaim
+  -- Also block guarding allied units that can reclaim
+  elseif (cmdID == CMD.GUARD) then
     local targetID = cmdParams[1]
     local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
 

commit 5ec72f20961be19f642c9a7ef4054800a3d7b377
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Thu Oct 23 23:04:54 2025 -0600

    sharing modes
    
    Fixed a few bugs that I had missed in the rebase madness in resource sharing. I will fix the old commits if I ever have to break this apart but I really don't think it makes sense. This works as far as I can tell, with the chobby commit

diff --git a/common/luaUtilities/team_transfer/resource_transfer_comms.lua b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
index 3bee95cfa8..a927bedc34 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_comms.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
@@ -5,47 +5,36 @@ local Comms = {
 }
 Comms.__index = Comms
 
---- Determine communication case from parameters
----@param senderTeamId number
----@param receiverTeamId number
----@param taxRate number
----@param resourceShareThreshold number
+--- Determine communication case from policy result
+---@param policyResult ResourcePolicyResult
 ---@return integer
-function Comms.DecideCommunicationCaseFromParams(senderTeamId, receiverTeamId, taxRate, resourceShareThreshold)
-  if senderTeamId == receiverTeamId then
+function Comms.DecideCommunicationCase(policyResult)
+  if policyResult.senderTeamId == policyResult.receiverTeamId then
     return SharedEnums.ResourceCommunicationCase.OnSelf
   end
-  if taxRate <= 0 then
+  if not policyResult.canShare then
+    return SharedEnums.ResourceCommunicationCase.OnDisabled
+  end
+  if policyResult.taxRate <= 0 then
     return SharedEnums.ResourceCommunicationCase.OnTaxFree
   end
-  if resourceShareThreshold > 0 then
+  if policyResult.resourceShareThreshold > 0 then
     return SharedEnums.ResourceCommunicationCase.OnTaxedThreshold
   end
   return SharedEnums.ResourceCommunicationCase.OnTaxed
 end
 
---- Determine communication case from policy result
----@param policyResult ResourcePolicyResult
----@return integer
-function Comms.DecideCommunicationCase(policyResult)
-  return Comms.DecideCommunicationCaseFromParams(
-    policyResult.senderTeamId,
-    policyResult.receiverTeamId,
-    policyResult.taxRate,
-    policyResult.resourceShareThreshold
-  )
-end
-
 ---Format a number for UI display by flooring it to whole numbers, this mirrors behavior in ResourceTransfer, which rounds down to the nearest percentage when interpreting commands from the slider
 ---@param value number
 ---@return string
 function FormatNumberForUI(value)
   if type(value) == "number" then
-      return tostring(math.floor(value))
+    return tostring(math.floor(value))
   else
-      return tostring(value)
+    return tostring(value)
   end
 end
+
 Comms.FormatNumberForUI = FormatNumberForUI
 
 ---@param policyResult ResourcePolicyResult
@@ -54,25 +43,27 @@ function Comms.TooltipText(policyResult)
   local baseKey = 'ui.playersList'
   local case = Comms.DecideCommunicationCase(policyResult)
   if case == SharedEnums.ResourceCommunicationCase.OnSelf then
-      return Spring.I18N(baseKey .. '.request' .. pascalResourceType)
+    return Spring.I18N(baseKey .. '.request' .. pascalResourceType)
   elseif case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
-      return Spring.I18N(baseKey .. '.share' .. pascalResourceType)
+    return Spring.I18N(baseKey .. '.share' .. pascalResourceType)
+  elseif case == SharedEnums.ResourceCommunicationCase.OnDisabled then
+    return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'Disabled')
   elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
     local i18nData = {
-        amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
-        amountSendable = FormatNumberForUI(policyResult.amountSendable),
-        taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
+      amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
+      amountSendable = FormatNumberForUI(policyResult.amountSendable),
+      taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
     }
     return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'Taxed', i18nData)
   elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
-      local i18nData = {
-          amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
-          amountSendable = FormatNumberForUI(policyResult.amountSendable),
-          taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
-          resourceShareThreshold = FormatNumberForUI(policyResult.resourceShareThreshold),
-          sentAmountUntaxed = FormatNumberForUI(math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)),
-      }
-      return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'TaxedThreshold', i18nData)
+    local i18nData = {
+      amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
+      amountSendable = FormatNumberForUI(policyResult.amountSendable),
+      taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
+      resourceShareThreshold = FormatNumberForUI(policyResult.resourceShareThreshold),
+      sentAmountUntaxed = FormatNumberForUI(math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)),
+    }
+    return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'TaxedThreshold', i18nData)
   end
 end
 
@@ -111,4 +102,4 @@ function Comms.SendTransferChatMessages(transferResult, policyResult)
   end
 end
 
-return Comms
\ No newline at end of file
+return Comms
diff --git a/common/luaUtilities/team_transfer/resource_transfer_shared.lua b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
index 73ceedf9ab..8305bfb789 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
@@ -1,7 +1,8 @@
 local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
+local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
 
-local Shared = {}
+local Shared = Comms
 
 local FieldTypes = PolicyShared.FieldTypes
 
@@ -48,17 +49,34 @@ function Shared.DeserializePolicyResult(serialized, senderTeamId, receiverTeamId
   })
 end
 
---- Core helper: compute sender cost for a desired received amount under policyResult
----@param policyResult ResourcePolicyResult
----@param desiredReceived number
----@return number receivedAmount, number sentAmount, number untaxedPortion
-function Shared.CalculateSenderTaxedAmount(policyResult, desiredReceived)
-  local maxReceivable = policyResult.amountReceivable
-  local desired = math.min(desiredReceived, policyResult.amountSendable, maxReceivable)
-  if desired <= 0 then
-    return 0, 0, 0
-  end
+---@param senderTeamId number
+---@param receiverTeamId number
+---@param resourceType ResourceType
+---@return ResourcePolicyResult
+function Shared.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType)
+  ---@type ResourcePolicyResult
+  local result = {
+    senderTeamId = senderTeamId,
+    receiverTeamId = receiverTeamId,
+    canShare = false,
+    amountSendable = 0,
+    amountReceivable = 0,
+    taxedPortion = 0,
+    untaxedPortion = 0,
+    taxRate = 0,
+    resourceType = resourceType,
+    remainingTaxFreeAllowance = 0,
+    resourceShareThreshold = 0,
+    cumulativeSent = Shared.GetCumulativeSent(senderTeamId, resourceType),
+    overflowSliderEnabled = false
+  }
+  return result
+end
 
+---@param policyResult ResourcePolicyResult
+---@param desired number
+---@return number received, number sent, number untaxed
+function Shared.CalculateSenderTaxedAmount(policyResult, desired)
   local untaxed = math.min(desired, policyResult.untaxedPortion)
   local taxed = desired - untaxed
   local r = policyResult.taxRate
@@ -91,31 +109,14 @@ function Shared.GetCachedPolicyResult(senderId, receiverId, resourceType)
   local serialized = Spring.GetTeamRulesParam(senderId, baseKey)
 
   if serialized == nil then
-    -- default to deny
-    ---@type ResourcePolicyResult
-    local result = {
-      senderTeamId = senderId,
-      receiverTeamId = receiverId,
-      canShare = false,
-      amountSendable = 0,
-      amountReceivable = 0,
-      taxedPortion = 0,
-      untaxedPortion = 0,
-      taxRate = 0,
-      resourceType = resourceType,
-      remainingTaxFreeAllowance = 0,
-      resourceShareThreshold = 0,
-      cumulativeSent = 0,
-      overflowSliderEnabled = false
-    }
-    return result
+    return Shared.CreateDenyPolicy(senderId, receiverId, resourceType)
   end
 
   if type(serialized) ~= "string" then
     serialized = tostring(serialized)
   end
 
-  local result = Shared.DeserializePolicyResult(serialized)
+  local result = Shared.DeserializePolicyResult(serialized, senderId, receiverId)
   result.senderTeamId = senderId
   result.receiverTeamId = receiverId
   return result
diff --git a/common/luaUtilities/team_transfer/resource_transfer_synced.lua b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
index 133909f80e..2f22cb7c81 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_synced.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
@@ -20,40 +20,27 @@ local function isNonPlayerTeam(springRepo, teamId)
   return luaAI ~= nil
 end
 
--- Build a rejected policy result with zeroed capabilities
----@param ctx PolicyContext
----@param resourceType ResourceType
----@return ResourcePolicyResult
-local function rejectPolicy(ctx, resourceType)
-  return Shared.CreateDenyPolicy(
-    ctx.senderTeamId,
-    ctx.receiverTeamId,
-    resourceType,
-    Shared.GetCumulativeSent(ctx.senderTeamId, resourceType)
-  )
-end
-
 -- Encapsulate legacy AllowResourceTransfer gate rules
 ---@param ctx PolicyContext
 ---@param resourceType ResourceType
 ---@return ResourcePolicyResult|nil
-local function tryRejectPolicy(ctx, resourceType)
+local function TryDenyPolicy(ctx, resourceType)
   -- Globally disable any form of resource sharing if the modoption is turned off
   local modOpts = ctx.springRepo.GetModOptions and ctx.springRepo.GetModOptions()
-  if modOpts and modOpts.game_resource_sharing_enabled == false then
-    return rejectPolicy(ctx, resourceType)
+  if modOpts and modOpts[SharedEnums.ModOptions.ResourceSharingEnabled] == false then
+    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType)
   end
   if ctx.isCheatingEnabled then
     return nil
   end
   if not ctx.areAlliedTeams and not isNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
-    return rejectPolicy(ctx, resourceType)
+    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType)
   end
   local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
   local activePlayers = numActivePlayers and
       tonumber(ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")) or 0
   if activePlayers == 0 then
-    return rejectPolicy(ctx, resourceType)
+    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType)
   end
   return nil
 end
@@ -116,7 +103,7 @@ function Gadgets.BuildResultFactory(taxRate, metalThreshold, energyThreshold)
   ---@param resourceType ResourceType
   ---@return ResourcePolicyResult
   local function calcResourcePolicyResult(ctx, resourceType)
-    local rejected = tryRejectPolicy(ctx, resourceType)
+    local rejected = TryDenyPolicy(ctx, resourceType)
     if rejected then return rejected end
 
     local senderData
diff --git a/common/luaUtilities/team_transfer/unit_transfer_comms.lua b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
index 45d823dd76..5020ff9f95 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_comms.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
@@ -4,7 +4,7 @@ local Comms = {}
 Comms.__index = Comms
 
 ---Decide communication case for unit sharing based on policy and optional validation results
----@param policy UnitTransferPolicyResult
+---@param policy UnitPolicyResult
 ---@param validationResult UnitValidationResult?
 ---@return number SharedEnums.UnitCommunicationCase
 function Comms.DecideCommunicationCase(policy, validationResult)
@@ -25,9 +25,9 @@ function Comms.DecideCommunicationCase(policy, validationResult)
   end
 end
 
----@param policy UnitTransferPolicyResult
+---@param policy UnitPolicyResult
 ---@param validationResult UnitValidationResult?
-function Comms.UnitShareTooltip(policy, validationResult)
+function Comms.TooltipText(policy, validationResult)
   local baseKey = 'ui.playersList'
   local case = Comms.DecideCommunicationCase(policy, validationResult)
   local i18nData = {
diff --git a/common/luaUtilities/team_transfer/unit_transfer_shared.lua b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
index 51ed14b737..ec33292229 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
@@ -1,8 +1,9 @@
 local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
 local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
+local Comms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")
 
-local Shared = {}
+local Shared = Comms
 
 local FieldTypes = PolicyShared.FieldTypes
 Shared.UnitPolicyFields = {
@@ -11,7 +12,6 @@ Shared.UnitPolicyFields = {
   allowTakeBypass = FieldTypes.boolean,
 }
 
-
 ---Validate a list of unitIds under current mode
 ---Returns a structured result object designed for UI consumption.
 ---We don't make decisions here on how to display unit names etc, we just collate the data and let the UI decide.
diff --git a/language/en/interface.json b/language/en/interface.json
index 04e158f665..7a8cf65196 100644
--- a/language/en/interface.json
+++ b/language/en/interface.json
@@ -93,9 +93,11 @@
 			},
 			"shareUnitsDisabled": "Unit sharing not allowed (mode is %{unitSharingMode})",
 			"shareMetal": "Click-and-drag to share metal",
+			"shareMetalDisabled": "Metal sharing not allowed",
 			"shareMetalTaxed": "Click-and-drag to share metal, receivable: %{amountReceivable}m, spendable: %{amountSendable}m at %{taxRatePercentage}%%",
 			"shareMetalTaxedThreshold": "Click-and-drag to share metal, receivable: %{amountReceivable}m, spendable: %{amountSendable}m at %{taxRatePercentage}%% (free used %{sentAmountUntaxed}/%{resourceShareThreshold}m)",
 			"shareEnergy": "Click-and-drag to share energy",
+			"shareEnergyDisabled": "Energy sharing not allowed",
 			"shareEnergyTaxed": "Click-and-drag to share energy, receivable: %{amountReceivable}e, spendable: %{amountSendable}e at %{taxRatePercentage}%%",
 			"shareEnergyTaxedThreshold": "Click-and-drag to share energy, receivable: %{amountReceivable}e, spendable: %{amountSendable}e at %{taxRatePercentage}%% (free used %{sentAmountUntaxed}/%{resourceShareThreshold}e)",
 			"becomeEnemy": "Click to become enemy",
diff --git a/luarules/gadgets/game_assist_ally.lua b/luarules/gadgets/game_allied_assist_mode.lua
similarity index 89%
rename from luarules/gadgets/game_assist_ally.lua
rename to luarules/gadgets/game_allied_assist_mode.lua
index 88da8eb977..65819d2e1c 100644
--- a/luarules/gadgets/game_assist_ally.lua
+++ b/luarules/gadgets/game_allied_assist_mode.lua
@@ -12,12 +12,14 @@ function gadget:GetInfo()
 	}
 end
 
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+
 if not gadgetHandler:IsSyncedCode() then
 	return false
 end
 
-local allowAssist = not Spring.GetModOptions().disable_assist_ally_construction
-if allowAssist then
+local assistEnabled = Spring.GetModOptions()[SharedEnums.ModOptions.AlliedAssistMode] == SharedEnums.AlliedAssistMode.Enabled
+if assistEnabled then
 	return false
 end
 
diff --git a/luarules/gadgets/game_allied_reclaim.lua b/luarules/gadgets/game_allied_unit_reclaim_mode.lua
similarity index 88%
rename from luarules/gadgets/game_allied_reclaim.lua
rename to luarules/gadgets/game_allied_unit_reclaim_mode.lua
index 9ac9003110..c5b8e4b373 100644
--- a/luarules/gadgets/game_allied_reclaim.lua
+++ b/luarules/gadgets/game_allied_unit_reclaim_mode.lua
@@ -12,6 +12,8 @@ function gadget:GetInfo()
   }
 end
 
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+
 ----------------------------------------------------------------
 -- Synced only
 ----------------------------------------------------------------
@@ -19,8 +21,8 @@ if not gadgetHandler:IsSyncedCode() then
   return false
 end
 
-local alliedReclaimEnabled = Spring.GetModOptions() and Spring.GetModOptions().game_allied_reclaim == "enabled"
-if alliedReclaimEnabled then
+local reclaimEnabled = Spring.GetModOptions() and Spring.GetModOptions()[SharedEnums.ModOptions.AlliedUnitReclaimMode] == SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted
+if reclaimEnabled then
   return
 end
 
diff --git a/luarules/gadgets/game_tax_resource_sharing.lua b/luarules/gadgets/game_tax_resource_sharing.lua
index b6d550adc1..db6ad0ce76 100644
--- a/luarules/gadgets/game_tax_resource_sharing.lua
+++ b/luarules/gadgets/game_tax_resource_sharing.lua
@@ -99,7 +99,7 @@ function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType
 end
 
 function gadget:GameFrame(frame)
-  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
+  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE
   if frame < nextSchedHeavy then
     return
   end
diff --git a/modoptions.lua b/modoptions.lua
index f8c300a177..bc46463a29 100644
--- a/modoptions.lua
+++ b/modoptions.lua
@@ -45,6 +45,14 @@ local options = {
         weight  = 7,
     },
 
+    {
+        key		= "options_sharing",
+        name	= "Sharing",
+        desc   	= "Resource and unit sharing options",
+        type   	= "section",
+        weight  = 6,
+    },
+
     {
         key     = "sub_header",
         name    = "Options for changing base game settings.",
@@ -258,20 +266,13 @@ local options = {
     },
 
     {
-        key     = "options_sharing",
-        name    = "Sharing",
-        type    = "section", 
-        weight  = 6,
-    },
-    {
-        key     = "sharing_mode",
+        key     = SharedEnums.ModOptions.SharingMode,
         name    = "Sharing Mode",
         desc    = "Controls overall sharing policy and locks/unlocks specific options, see `sharing_modes/` for more details",
         type    = "list",
         section = "options_sharing",
-        sharing_category = "mode_selection",
         def     = "enabled",
-        items   = {}, -- Will be populated by UI code from sharing_modes
+        items   = {}, -- Will be populated dynamically by Chobby from sharing_modes/ directory
     },
 
     {
@@ -279,7 +280,6 @@ local options = {
         name    = "-- Units",
         type    = "subheader",
         section = "options_sharing",
-        sharing_category = "units",
         def     =  true,
     },
 	{
@@ -306,7 +306,6 @@ local options = {
         type    = "subheader",
         desc    = "",
         section = "options_sharing",
-        sharing_category = "resources",
         def     =  true,
     },
 	{
@@ -315,7 +314,6 @@ local options = {
 		desc	= "Enable or disable all player-to-player resource sharing and overflow",
 		type	= "bool",
 		section	= "options_sharing",
-        sharing_category = "resources",
 		def		= true,
 		column  = 1,
 	},
@@ -330,9 +328,7 @@ local options = {
 		max		= 0.99,
 		step	= 0.01,
 		section	= "options_sharing",
-		sharing_category = "resources",
 		column	= 1,
-		disabled= { key = SharedEnums.ModOptions.ResourceSharingEnabled, value = false},
 	},
 	{
 		key     = SharedEnums.ModOptions.PlayerMetalSendThreshold,
@@ -344,9 +340,7 @@ local options = {
 		max     = 100000,
 		step    = 10,
 		section = "options_sharing",
-		sharing_category = "resources",
 		column  = 1,
-		disabled= { key = SharedEnums.ModOptions.ResourceSharingEnabled, value = false},
 	},
 	{
 		key     = SharedEnums.ModOptions.PlayerEnergySendThreshold,
@@ -358,9 +352,7 @@ local options = {
 		max     = 100000,
 		step    = 10,
 		section = "options_sharing",
-		sharing_category = "resources",
 		column  = 2,
-		disabled= { key = SharedEnums.ModOptions.ResourceSharingEnabled, value = false},
 	},
 
     {
@@ -368,7 +360,6 @@ local options = {
         name    = "-- Allied Interactions",
         desc    = "",
         section = "options_sharing",
-        sharing_category = "allied_interactions",
         type    = "subheader",
         def     =  true,
     },
@@ -378,12 +369,11 @@ local options = {
 		desc	= "Controls whether units can assist allied construction and repair",
 		type	= "list",
 		section	= "options_sharing",
-        sharing_category = "allied_interactions",
 		def		= SharedEnums.AlliedAssistMode.Enabled,
 		column	= 1,
 		items	= {
 			{ key = SharedEnums.AlliedAssistMode.Disabled, name = "Disabled", desc = "Units cannot assist allied construction and repair" },
-			{ key = SharedEnums.AlliedAssistMode.Enabled,  name = "Enabled",  desc = "Units can assist allied construction and repair" },
+			{ key = SharedEnums.AlliedAssistMode.Enabled,  name = "Enabled Automation Restricted",  desc = "Units can assist allied construction and repair" },
 		},
 	},
 	{
@@ -392,11 +382,10 @@ local options = {
 		desc	= "Controls reclaiming allied units and guarding allied units that can reclaim",
 		type	= "list",
 		section	= "options_sharing",
-        sharing_category = "allied_interactions",
-		def		= SharedEnums.AlliedUnitReclaimMode.Enabled,
+		def		= SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted,
 		items	= {
 			{ key = SharedEnums.AlliedUnitReclaimMode.Disabled, name = "Disabled", desc = "Allied reclaim is disabled" },
-			{ key = SharedEnums.AlliedUnitReclaimMode.Enabled, name = "Enabled", desc = "Allied reclaim is allowed" },
+			{ key = SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted, name = "Enabled", desc = "Allied reclaim is allowed" },
 		},
 	},
 
diff --git a/sharing_modes/customize.lua b/sharing_modes/customize.lua
index 50d54d8b2f..b5d5d8808f 100644
--- a/sharing_modes/customize.lua
+++ b/sharing_modes/customize.lua
@@ -5,7 +5,7 @@ return {
     key = SharedEnums.SharingModes.Customize,
     name = "Customize",
     desc = "Choose your own settings.",
-    allowRanked = false,
+    allowRanked = true,
     modOptions = {
         [SharedEnums.ModOptions.UnitSharingMode] = {
             value = SharedEnums.UnitSharingMode.Enabled,
@@ -32,7 +32,7 @@ return {
             locked = false
         },
         [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
-            value = SharedEnums.AlliedUnitReclaimMode.Enabled,
+            value = SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted,
             locked = false
         },
     }
diff --git a/sharing_modes/enabled.lua b/sharing_modes/enabled.lua
index 3475c61cb8..f1a06145c7 100644
--- a/sharing_modes/enabled.lua
+++ b/sharing_modes/enabled.lua
@@ -35,7 +35,7 @@ return {
             locked = true,
         },
         [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
-            value = SharedEnums.AlliedUnitReclaimMode.Enabled,
+            value = SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted,
             locked = true,
         },
     }
diff --git a/sharing_modes/limited_sharing.lua b/sharing_modes/limited_sharing.lua
index d2667262c2..ef43270cef 100644
--- a/sharing_modes/limited_sharing.lua
+++ b/sharing_modes/limited_sharing.lua
@@ -27,12 +27,12 @@ return {
             value = 0,
             locked = false,
         },
-        [SharedEnums.ModOptions.AlliedAssist] = {
+        [SharedEnums.ModOptions.AlliedAssistMode] = {
             value = SharedEnums.AlliedAssistMode.Enabled,
             locked = false,
         },
         [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
-            value = SharedEnums.AlliedUnitReclaimMode.Enabled,
+            value = SharedEnums.AlliedUnitReclaimMode.EnabledAutomationRestricted,
             locked = false,
         },
     }
diff --git a/sharing_modes/no_sharing.lua b/sharing_modes/no_sharing.lua
index 183bbca62d..7ce07ded04 100644
--- a/sharing_modes/no_sharing.lua
+++ b/sharing_modes/no_sharing.lua
@@ -25,7 +25,12 @@ return {
             locked = true,
             ui = "hidden"
         },
-        [SharedEnums.ModOptions.AlliedAssist] = {
+        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
+            value = 0,
+            locked = true,
+            ui = "hidden"
+        },
+        [SharedEnums.ModOptions.AlliedAssistMode] = {
             value = SharedEnums.AlliedAssistMode.Disabled,
             locked = true
         },
diff --git a/sharing_modes/shared_enums.lua b/sharing_modes/shared_enums.lua
index 22608179cf..7c44fe03ca 100644
--- a/sharing_modes/shared_enums.lua
+++ b/sharing_modes/shared_enums.lua
@@ -7,6 +7,7 @@ M.ModOptions = {
 	PlayerEnergySendThreshold = "player_energy_send_threshold",
 	PlayerMetalSendThreshold = "player_metal_send_threshold",
 	ResourceSharingEnabled = "resource_sharing_enabled",
+	SharingMode = "sharing_mode",
 	TaxResourceSharingAmount = "tax_resource_sharing_amount",
 	UnitSharingMode = "unit_sharing_mode",
 }
@@ -76,7 +77,7 @@ M.AlliedAssistMode = {
 
 M.AlliedUnitReclaimMode = {
 	Disabled = "disabled",
-	Enabled = "enabled",
+	EnabledAutomationRestricted = "enabled_automation_restricted",
 }
 
 return M

commit c12e9b5aa5d919e0ec83c731981898e4622d4fc3
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Thu Oct 23 16:29:10 2025 -0600

    sharing modes
    
    went with a straight enum approach in a root sharing_modes folder. I dig it

diff --git a/common/luaUtilities/team_transfer/context_factory.lua b/common/luaUtilities/team_transfer/context_factory.lua
index 4142262828..da6d3886c9 100644
--- a/common/luaUtilities/team_transfer/context_factory.lua
+++ b/common/luaUtilities/team_transfer/context_factory.lua
@@ -1,4 +1,4 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 
 ---@class ContextFactory
 ---@field create fun(springRepo: ISpring): ContextFactory
diff --git a/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua b/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
index b35eaeff07..76dcb0c743 100644
--- a/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
+++ b/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
@@ -1,4 +1,4 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
 local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
 
diff --git a/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua b/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
index 3b342174c9..414750cea3 100644
--- a/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
+++ b/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
@@ -1,7 +1,7 @@
 --- holds helper functions for the gui_advplayerslist.lua
 --- these are related to team transfer, but highly specific to the gui
 --- gui_advplayerslist has severe restrictions on the number of local cosures due to lua 5.1's 200 cap
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
 local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
 
diff --git a/common/luaUtilities/team_transfer/modoption_enums.lua b/common/luaUtilities/team_transfer/modoption_enums.lua
deleted file mode 100644
index 4976ccc096..0000000000
--- a/common/luaUtilities/team_transfer/modoption_enums.lua
+++ /dev/null
@@ -1,11 +0,0 @@
----@class TeamTransferModOptions
-local M = {}
-
-M.Options = {
-	TaxResourceSharingAmount = "tax_resource_sharing_amount",
-	PlayerMetalSendThreshold = "player_metal_send_threshold",
-	PlayerEnergySendThreshold = "player_energy_send_threshold",
-	UnitSharingMode = "unit_sharing_mode",
-}
-
-return M
diff --git a/common/luaUtilities/team_transfer/resource_transfer_comms.lua b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
index d394738de5..3bee95cfa8 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_comms.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
@@ -1,4 +1,4 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 
 local Comms = {
   ResourceCommunicationCase = SharedEnums.ResourceCommunicationCase,
diff --git a/common/luaUtilities/team_transfer/resource_transfer_shared.lua b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
index cd47fca9a4..73ceedf9ab 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
@@ -1,8 +1,7 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
-local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
 
-local Shared = Comms
+local Shared = {}
 
 local FieldTypes = PolicyShared.FieldTypes
 
@@ -20,6 +19,35 @@ Shared.ResourcePolicyFields = {
   cumulativeSent = FieldTypes.number,
 }
 
+---Generate base key for policy caching
+---@param receiverId number
+---@param resourceType ResourceType
+---@return string
+function Shared.MakeBaseKey(receiverId, resourceType)
+  local transferCategory = resourceType == SharedEnums.ResourceType.METAL and SharedEnums.TransferCategory.MetalTransfer or
+  SharedEnums.TransferCategory.EnergyTransfer
+  return PolicyShared.MakeBaseKey(receiverId, transferCategory)
+end
+
+---Serialize ResourcePolicyResult to string for efficient storage
+---@param policyResult table
+---@return string
+function Shared.SerializeResourcePolicyResult(policyResult)
+  return PolicyShared.Serialize(Shared.ResourcePolicyFields, policyResult)
+end
+
+---Deserialize ResourcePolicyResult from string
+---@param serialized string
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return ResourcePolicyResult
+function Shared.DeserializePolicyResult(serialized, senderTeamId, receiverTeamId)
+  return PolicyShared.Deserialize(Shared.ResourcePolicyFields, serialized, {
+    senderTeamId = senderTeamId,
+    receiverTeamId = receiverTeamId,
+  })
+end
+
 --- Core helper: compute sender cost for a desired received amount under policyResult
 ---@param policyResult ResourcePolicyResult
 ---@param desiredReceived number
@@ -41,10 +69,10 @@ function Shared.CalculateSenderTaxedAmount(policyResult, desiredReceived)
     if r >= 1.0 then
       -- 100% tax means taxed portion cannot be sent (infinite cost)
       sent = untaxed
-      received = untaxed       -- only untaxed portion reaches receiver
+      received = untaxed -- only untaxed portion reaches receiver
     else
       sent = untaxed + (taxed / (1 - r))
-      received = desired       -- all desired amount reaches receiver
+      received = desired -- all desired amount reaches receiver
     end
   else
     sent = untaxed
@@ -63,14 +91,33 @@ function Shared.GetCachedPolicyResult(senderId, receiverId, resourceType)
   local serialized = Spring.GetTeamRulesParam(senderId, baseKey)
 
   if serialized == nil then
-    return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, 0)
+    -- default to deny
+    ---@type ResourcePolicyResult
+    local result = {
+      senderTeamId = senderId,
+      receiverTeamId = receiverId,
+      canShare = false,
+      amountSendable = 0,
+      amountReceivable = 0,
+      taxedPortion = 0,
+      untaxedPortion = 0,
+      taxRate = 0,
+      resourceType = resourceType,
+      remainingTaxFreeAllowance = 0,
+      resourceShareThreshold = 0,
+      cumulativeSent = 0,
+      overflowSliderEnabled = false
+    }
+    return result
   end
 
   if type(serialized) ~= "string" then
     serialized = tostring(serialized)
   end
 
-  local result = Shared.DeserializePolicyResult(serialized, senderId, receiverId)
+  local result = Shared.DeserializePolicyResult(serialized)
+  result.senderTeamId = senderId
+  result.receiverTeamId = receiverId
   return result
 end
 
@@ -92,55 +139,4 @@ function Shared.GetCumulativeSent(teamId, resourceType)
   return tonumber(Spring.GetTeamRulesParam(teamId, param)) or 0
 end
 
----Generate base key for policy caching
----@param receiverId number
----@param resourceType ResourceType
----@return string
-function Shared.MakeBaseKey(receiverId, resourceType)
-  local transferCategory = resourceType == SharedEnums.ResourceType.METAL and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
-  return PolicyShared.MakeBaseKey(receiverId, transferCategory)
-end
-
----Serialize ResourcePolicyResult to string for efficient storage
----@param policyResult table
----@return string
-function Shared.SerializeResourcePolicyResult(policyResult)
-  return PolicyShared.Serialize(Shared.ResourcePolicyFields, policyResult)
-end
-
----Deserialize ResourcePolicyResult from string
----@param serialized string
----@param senderTeamId number
----@param receiverTeamId number
----@return ResourcePolicyResult
-function Shared.DeserializePolicyResult(serialized, senderTeamId, receiverTeamId)
-  return PolicyShared.Deserialize(Shared.ResourcePolicyFields, serialized, {
-    senderTeamId = senderTeamId,
-    receiverTeamId = receiverTeamId,
-  })
-end
-
----Create a default deny ResourcePolicyResult
----@param senderTeamId number
----@param receiverTeamId number
----@param resourceType ResourceType
----@param cumulativeSent number?
----@return ResourcePolicyResult
-function Shared.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType, cumulativeSent)
-  return {
-    senderTeamId = senderTeamId,
-    receiverTeamId = receiverTeamId,
-    canShare = false,
-    amountSendable = 0,
-    amountReceivable = 0,
-    taxedPortion = 0,
-    untaxedPortion = 0,
-    taxRate = 0,
-    resourceType = resourceType,
-    remainingTaxFreeAllowance = 0,
-    resourceShareThreshold = 0,
-    cumulativeSent = cumulativeSent or 0,
-  }
-end
-
 return Shared
diff --git a/common/luaUtilities/team_transfer/resource_transfer_synced.lua b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
index ee5f96c361..133909f80e 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_synced.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
@@ -1,5 +1,4 @@
-local ModOptions = VFS.Include("common/luaUtilities/team_transfer/modoption_enums.lua")
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
 local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
 
diff --git a/common/luaUtilities/team_transfer/team_transfer_cache.lua b/common/luaUtilities/team_transfer/team_transfer_cache.lua
index 06e02bd133..32e5d229d9 100644
--- a/common/luaUtilities/team_transfer/team_transfer_cache.lua
+++ b/common/luaUtilities/team_transfer/team_transfer_cache.lua
@@ -1,4 +1,4 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 
 local M = {}
 
diff --git a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
index bfd25bc974..d6bfca8ee1 100644
--- a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
+++ b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
@@ -1,4 +1,4 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
 local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
 
diff --git a/common/luaUtilities/team_transfer/unit_sharing_categories.lua b/common/luaUtilities/team_transfer/unit_sharing_categories.lua
index 87d33d8d69..f779318dc0 100644
--- a/common/luaUtilities/team_transfer/unit_sharing_categories.lua
+++ b/common/luaUtilities/team_transfer/unit_sharing_categories.lua
@@ -1,4 +1,4 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 
 local sharing = {}
 
diff --git a/common/luaUtilities/team_transfer/unit_transfer_comms.lua b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
index 1b4d27f962..45d823dd76 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_comms.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
@@ -1,12 +1,10 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 
-local Comms = {
-  UnitCommunicationCase = SharedEnums.UnitCommunicationCase,
-}
+local Comms = {}
 Comms.__index = Comms
 
 ---Decide communication case for unit sharing based on policy and optional validation results
----@param policy UnitPolicyResult
+---@param policy UnitTransferPolicyResult
 ---@param validationResult UnitValidationResult?
 ---@return number SharedEnums.UnitCommunicationCase
 function Comms.DecideCommunicationCase(policy, validationResult)
@@ -27,17 +25,22 @@ function Comms.DecideCommunicationCase(policy, validationResult)
   end
 end
 
----@param policy UnitPolicyResult
+---@param policy UnitTransferPolicyResult
 ---@param validationResult UnitValidationResult?
-function Comms.TooltipText(policy, validationResult)
+function Comms.UnitShareTooltip(policy, validationResult)
   local baseKey = 'ui.playersList'
   local case = Comms.DecideCommunicationCase(policy, validationResult)
+  local i18nData = {
+    unitSharingMode = policy.sharingMode,
+  }
+  if validationResult then
+    i18nData.firstInvalidUnitName = validationResult.invalidUnitNames[1] or ""
+    i18nData.secondInvalidUnitName = validationResult.invalidUnitNames[2] or ""
+    i18nData.count = #validationResult.invalidUnitNames - 2
+  end
   if case == SharedEnums.UnitCommunicationCase.OnSelf then
     return Spring.I18N(baseKey .. '.requestSupport')
   elseif case == SharedEnums.UnitCommunicationCase.OnPolicyDisabled then
-    local i18nData = {
-      unitSharingMode = policy.sharingMode,
-    }
     return Spring.I18N(baseKey .. '.shareUnitsDisabled', i18nData)
   elseif case == SharedEnums.UnitCommunicationCase.OnSelectionValidationFailed then
     return Spring.I18N(baseKey .. '.shareUnitsInvalid.all')
@@ -60,7 +63,10 @@ function Comms.TooltipText(policy, validationResult)
     end
   elseif case == SharedEnums.UnitCommunicationCase.OnFullyShareable then
     if validationResult then
-      return Spring.I18N(baseKey .. '.shareUnits')
+      local i18nData = {
+        validUnitCount = validationResult.validUnitCount,
+      }
+      return Spring.I18N(baseKey .. '.shareUnits', i18nData)
     else
       return Spring.I18N(baseKey .. '.shareUnits')
     end
diff --git a/common/luaUtilities/team_transfer/unit_transfer_shared.lua b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
index 91fe1816ee..51ed14b737 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
@@ -1,9 +1,8 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
 local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
-local Comms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")
 
-local Shared = Comms
+local Shared = {}
 
 local FieldTypes = PolicyShared.FieldTypes
 Shared.UnitPolicyFields = {
@@ -40,6 +39,7 @@ function Shared.ValidateUnits(policyResult, unitIds)
   for _, unitId in ipairs(unitIds) do
     local unitDefID = Spring.GetUnitDefID(unitId)
     if not unitDefID then
+      Spring.Log("unit_transfer_shared", LOG.ERROR, "ValidateUnits: unitId", unitId, "not found")
       out.invalidUnitCount = out.invalidUnitCount + 1
       table.insert(out.invalidUnitIds, unitId)
       table.insert(out.invalidUnitNames, "Unknown Unit")
@@ -122,63 +122,47 @@ function Shared.DeserializePolicy(serialized, senderId, receiverId)
   })
 end
 
-function Shared.GetModeUnitTypes(mode)
+---Get globals published by the module
+---@param unitDef table
+---@param mode string
+---@return boolean
+local function EvaluateUnitForSharing(unitDef, mode)
+  if not unitDef then return false end
+
+  -- Simple cases
   if mode == SharedEnums.UnitSharingMode.Disabled then
-    return {}
+    return false
   end
-  
+
   if mode == SharedEnums.UnitSharingMode.Enabled then
-    return {
-      SharedEnums.UnitType.Combat,
-      SharedEnums.UnitType.Economic,
-      SharedEnums.UnitType.Utility,
-      SharedEnums.UnitType.T2Constructor
-    }
+    return true
   end
 
+  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
+
   if mode == SharedEnums.UnitSharingMode.CombatUnits then
-    return {SharedEnums.UnitType.Combat}
+    return unitType == SharedEnums.UnitType.Combat
   end
 
   if mode == SharedEnums.UnitSharingMode.Economic then
-    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor}
+    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor
   end
 
   if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
-    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor, SharedEnums.UnitType.Utility}
+    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor or
+    unitType == SharedEnums.UnitType.Utility
   end
 
   if mode == SharedEnums.UnitSharingMode.T2Cons then
-    return {SharedEnums.UnitType.T2Constructor}
+    return unitType == SharedEnums.UnitType.T2Constructor
   end
 
   if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
-    return {SharedEnums.UnitType.Combat, SharedEnums.UnitType.T2Constructor}
-  end
-end
-
-local function UnitTypeMatchesMode(unitDef, mode)
-  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
-  local modeUnitTypes = Shared.GetModeUnitTypes(mode)
-  return table.contains(modeUnitTypes, unitType)
-end
-
----Get globals published by the module
----@param unitDef table
----@param mode string
----@return boolean
-local function EvaluateUnitForSharing(unitDef, mode)
-  if not unitDef then return false end
-
-  if mode == SharedEnums.UnitSharingMode.Disabled then
-    return false
-  end
-
-  if mode == SharedEnums.UnitSharingMode.Enabled then
-    return true
+    return unitType == SharedEnums.UnitType.Combat or unitType == SharedEnums.UnitType.T2Constructor
   end
 
-  return UnitTypeMatchesMode(unitDef, mode)
+  Spring.Log("unit_transfer_shared", LOG.ERROR, "EvaluateUnitForSharing: unknown mode =", mode)
+  return false
 end
 
 -- Allowed UnitDefID cache per mode for fast validation
@@ -188,7 +172,7 @@ local function BuildAllowedCacheForMode(mode)
   if allowedByMode[mode] then return end
   local cache = {}
   for unitDefID, unitDef in pairs(UnitDefs) do
-    if EvaluateUnitForSharing(unitDef, mode) then
+  if EvaluateUnitForSharing(unitDef, mode) then
       cache[unitDefID] = true
     end
   end
diff --git a/common/luaUtilities/team_transfer/unit_transfer_synced.lua b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
index a1eab656ef..5723cc0c58 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_synced.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
@@ -1,4 +1,4 @@
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
 local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
 local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
diff --git a/luarules/gadgets/game_disable_assist_ally.lua b/luarules/gadgets/game_assist_ally.lua
similarity index 100%
rename from luarules/gadgets/game_disable_assist_ally.lua
rename to luarules/gadgets/game_assist_ally.lua
diff --git a/luarules/gadgets/game_disable_ally_geo_mex_upgrades.lua b/luarules/gadgets/game_disable_ally_geo_mex_upgrades.lua
index 3824f5fb53..790164f517 100644
--- a/luarules/gadgets/game_disable_ally_geo_mex_upgrades.lua
+++ b/luarules/gadgets/game_disable_ally_geo_mex_upgrades.lua
@@ -20,7 +20,7 @@ if not gadgetHandler:IsSyncedCode() then
 end
 
 local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 
 local mode = Spring.GetModOptions().unit_sharing_mode
 local modeUnitTypes = UnitTransfer.GetModeUnitTypes(mode)
diff --git a/luarules/gadgets/game_tax_resource_sharing.lua b/luarules/gadgets/game_tax_resource_sharing.lua
index b19ffe5a54..b6d550adc1 100644
--- a/luarules/gadgets/game_tax_resource_sharing.lua
+++ b/luarules/gadgets/game_tax_resource_sharing.lua
@@ -29,7 +29,7 @@ local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource
 local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
 local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
 local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 
 local RESOURCE_TYPES = SharedEnums.ResourceTypes
 local contextFactory = ContextFactoryModule.create(Spring)
diff --git a/luarules/gadgets/game_unit_sharing_mode.lua b/luarules/gadgets/game_unit_sharing_mode.lua
index 677fbb7f1b..2d9ef72086 100644
--- a/luarules/gadgets/game_unit_sharing_mode.lua
+++ b/luarules/gadgets/game_unit_sharing_mode.lua
@@ -21,7 +21,7 @@ if not gadgetHandler:IsSyncedCode() then
   return false
 end
 
-local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
 local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
 local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
 local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
diff --git a/luaui/Widgets/gui_advplayerslist.lua b/luaui/Widgets/gui_advplayerslist.lua
index 35724fc59c..63b1d9b46f 100644
--- a/luaui/Widgets/gui_advplayerslist.lua
+++ b/luaui/Widgets/gui_advplayerslist.lua
@@ -60,7 +60,7 @@ end
     v47   (Attean): introduce a policy cache and TeamTransfer module, removing a lot of economic and unit specific code from this file and enabling unit_sharing_mode and player_[resource]_send_threshold modoptions
 ]]--
 
-local SharedEnums = VFS.Include('common/luaUtilities/team_transfer/shared_enums.lua')
+local SharedEnums = VFS.Include('sharing_modes/shared_enums.lua')
 local TeamTransfer = VFS.Include('common/luaUtilities/team_transfer/team_transfer_unsynced.lua')
 local ResourceTransfer = TeamTransfer.Resources
 local ApiExtensions = VFS.Include('common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua')
diff --git a/modoptions.lua b/modoptions.lua
index 858574a634..f8c300a177 100644
--- a/modoptions.lua
+++ b/modoptions.lua
@@ -1,3 +1,5 @@
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+
 --  Custom Options Definition Table format
 --  NOTES:
 --  using an enumerated table lets you specify the options order
@@ -255,42 +257,85 @@ local options = {
         step   	= 1,
     },
 
+    {
+        key     = "options_sharing",
+        name    = "Sharing",
+        type    = "section", 
+        weight  = 6,
+    },
+    {
+        key     = "sharing_mode",
+        name    = "Sharing Mode",
+        desc    = "Controls overall sharing policy and locks/unlocks specific options, see `sharing_modes/` for more details",
+        type    = "list",
+        section = "options_sharing",
+        sharing_category = "mode_selection",
+        def     = "enabled",
+        items   = {}, -- Will be populated by UI code from sharing_modes
+    },
+
+    {
+        key     = "sub_header",
+        name    = "-- Units",
+        type    = "subheader",
+        section = "options_sharing",
+        sharing_category = "units",
+        def     =  true,
+    },
 	{
-		key		= "sub_header",
-		section	= "options_main",
-		type	= "separator",
-	},
-	{
-		key		= "sub_header",
-		name	= "-- Sharing and Taxes",
-		section	= "options_main",
-		type	= "subheader",
-		def		=  true,
+		key		= SharedEnums.ModOptions.UnitSharingMode,
+		name	= "Unit Sharing",
+		desc	= "Controls which units can be shared",
+		type	= "list",
+		section	= "options_sharing",
+		def		= SharedEnums.UnitSharingMode.Enabled,
+		items	= {
+			{ key = SharedEnums.UnitSharingMode.Enabled, name = "Enabled", desc = "All unit sharing allowed" },
+			{ key = SharedEnums.UnitSharingMode.T2Cons, name = "T2 Constructor Sharing Only", desc = "Only T2 constructors can be shared between allies" },
+			{ key = SharedEnums.UnitSharingMode.CombatUnits, name = "Combat Units Only", desc = "Only combat units can be shared (no economic units, factories, or constructors)" },
+			{ key = SharedEnums.UnitSharingMode.CombatT2Cons, name = "Combat Units + T2 Constructors", desc = "Combat units and T2 constructors can be shared" },
+			{ key = SharedEnums.UnitSharingMode.Economic, name = "Economic Units Only", desc = "Only combat units can be shared (no economic units, factories, or constructors)" },
+			{ key = SharedEnums.UnitSharingMode.EconomicPlusBuildings, name = "Economic Units and Buildings", desc = "All economic units and resource production buildings can be shared but no combat units" },
+			{ key = SharedEnums.UnitSharingMode.Disabled, name = "Disabled", desc = "No unit sharing allowed" },
+		},
 	},
+
+    {
+        key     = "sub_header",
+        name    = "-- Resources",
+        type    = "subheader",
+        desc    = "",
+        section = "options_sharing",
+        sharing_category = "resources",
+        def     =  true,
+    },
 	{
-		key		= "game_resource_sharing_enabled",
+		key		= SharedEnums.ModOptions.ResourceSharingEnabled,
 		name	= "Resource Sharing",
 		desc	= "Enable or disable all player-to-player resource sharing and overflow",
 		type	= "bool",
-		section	= "options_main",
+		section	= "options_sharing",
+        sharing_category = "resources",
 		def		= true,
 		column  = 1,
 	},
 	{
-		key		= "tax_resource_sharing_amount",
-		name	= "Resource Sharing Tax",
-		desc	=	"Taxes resource sharing".."\255\128\128\128".." and overflow (engine TODO:)\n"..
-					"Set to [0] to turn off. Recommended: [0.4]. (Ranges: 0 - 0.99)",
+		key		= SharedEnums.ModOptions.TaxResourceSharingAmount,
+		name	= "Resource Sharing Tax Rate",
+		desc	= "Taxes resource sharing and overflow"..
+				  "Set to [0] to turn off. Recommended: [0.3]. (Ranges: 0 - 0.99)",
 		type	= "number",
 		def		= 0,
 		min		= 0,
 		max		= 0.99,
 		step	= 0.01,
-		section	= "options_main",
+		section	= "options_sharing",
+		sharing_category = "resources",
 		column	= 1,
+		disabled= { key = SharedEnums.ModOptions.ResourceSharingEnabled, value = false},
 	},
 	{
-		key     = "player_metal_send_threshold",
+		key     = SharedEnums.ModOptions.PlayerMetalSendThreshold,
 		name    = "Player Metal Send Threshold",
 		desc    = "Max total metal a player can send tax-free cumulatively. Tax applies to amounts sent *after* this limit is reached. Set to 0 for immediate tax (if rate > 0).",
 		type    = "number",
@@ -298,12 +343,13 @@ local options = {
 		min     = 0,
 		max     = 100000,
 		step    = 10,
-		section = "options_main",
+		section = "options_sharing",
+		sharing_category = "resources",
 		column  = 1,
-		disabled= { key="tax_resource_sharing_amount", value = 0},
+		disabled= { key = SharedEnums.ModOptions.ResourceSharingEnabled, value = false},
 	},
 	{
-		key     = "player_energy_send_threshold",
+		key     = SharedEnums.ModOptions.PlayerEnergySendThreshold,
 		name    = "Player Energy Send Threshold",
 		desc    = "Max total energy a player can send tax-free cumulatively. Tax applies to amounts sent *after* this limit is reached. Set to 0 for immediate tax (if rate > 0).",
 		type    = "number",
@@ -311,48 +357,49 @@ local options = {
 		min     = 0,
 		max     = 100000,
 		step    = 10,
-		section = "options_main",
+		section = "options_sharing",
+		sharing_category = "resources",
 		column  = 2,
-		disabled= { key="tax_resource_sharing_amount", value = 0},
+		disabled= { key = SharedEnums.ModOptions.ResourceSharingEnabled, value = false},
 	},
+
+    {
+        key     = "sub_header",
+        name    = "-- Allied Interactions",
+        desc    = "",
+        section = "options_sharing",
+        sharing_category = "allied_interactions",
+        type    = "subheader",
+        def     =  true,
+    },
 	{
-		key		= "game_allied_reclaim",
-		name	= "Allied Reclaim",
-		desc	= "Controls reclaiming allied units and guarding allied units that can reclaim",
+		key		= SharedEnums.ModOptions.AlliedAssistMode,
+		name	= "Ally Assist",
+		desc	= "Controls whether units can assist allied construction and repair",
 		type	= "list",
-		section	= "options_main",
-		def		= "enabled",
+		section	= "options_sharing",
+        sharing_category = "allied_interactions",
+		def		= SharedEnums.AlliedAssistMode.Enabled,
+		column	= 1,
 		items	= {
-			{ key = "enabled", name = "Enabled", desc = "Allied reclaim is disabled" },
-			{ key = "disabled", name = "Disabled", desc = "Allied reclaim is allowed" },
+			{ key = SharedEnums.AlliedAssistMode.Disabled, name = "Disabled", desc = "Units cannot assist allied construction and repair" },
+			{ key = SharedEnums.AlliedAssistMode.Enabled,  name = "Enabled",  desc = "Units can assist allied construction and repair" },
 		},
 	},
 	{
-		key		= "unit_sharing_mode",
-		name	= "Unit Sharing Mode",
-		desc	= "Controls which units can be shared",
+		key		= SharedEnums.ModOptions.AlliedUnitReclaimMode,
+		name	= "Ally Unit Reclaim",
+		desc	= "Controls reclaiming allied units and guarding allied units that can reclaim",
 		type	= "list",
-		section	= "options_main",
-		def		= "enabled",
+		section	= "options_sharing",
+        sharing_category = "allied_interactions",
+		def		= SharedEnums.AlliedUnitReclaimMode.Enabled,
 		items	= {
-			{ key = "enabled", name = "Enabled", desc = "All unit sharing allowed" },
-			{ key = "t2_cons", name = "T2 Constructor Sharing Only", desc = "Only T2 constructors can be shared between allies" },
-			{ key = "combat", name = "Combat Units Only", desc = "Only combat units can be shared (no economic units, factories, or constructors)" },
-			{ key = "combat_t2_cons", name = "Combat Units + T2 Constructors", desc = "Combat units and T2 constructors can be shared" },
-			{ key = "economic", name = "Economic Units Only", desc = "Only combat units can be shared (no economic units, factories, or constructors)" },
-			{ key = "economic_plus_buildings", name = "Economic Units and Buildings", desc = "All economic units and resource production buildings can be shared but no combat units" },
-			{ key = "disabled", name = "Disabled", desc = "No unit sharing allowed" },
+			{ key = SharedEnums.AlliedUnitReclaimMode.Disabled, name = "Disabled", desc = "Allied reclaim is disabled" },
+			{ key = SharedEnums.AlliedUnitReclaimMode.Enabled, name = "Enabled", desc = "Allied reclaim is allowed" },
 		},
 	},
-	{
-		key		= "disable_assist_ally_construction",
-		name	= "Disable Assist Ally Construction",
-		desc	= "Disables assisting allied blueprints and labs.",
-		type	= "bool",
-		section	= "options_main",
-		def		=  false,
-		column	= 1,
-	},
+
     {
         key     = "sub_header",
         section = "options_main",
diff --git a/sharing_modes/customize.lua b/sharing_modes/customize.lua
new file mode 100644
index 0000000000..50d54d8b2f
--- /dev/null
+++ b/sharing_modes/customize.lua
@@ -0,0 +1,39 @@
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+
+---@type SharingModeConfig
+return {
+    key = SharedEnums.SharingModes.Customize,
+    name = "Customize",
+    desc = "Choose your own settings.",
+    allowRanked = false,
+    modOptions = {
+        [SharedEnums.ModOptions.UnitSharingMode] = {
+            value = SharedEnums.UnitSharingMode.Enabled,
+            locked = false,
+        },
+        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
+            value = true,
+            locked = false,
+        },
+        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
+            value = 0,
+            locked = false
+        },
+        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
+            value = 0,
+            locked = false
+        },
+        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
+            value = 0,
+            locked = false
+        },
+        [SharedEnums.ModOptions.AlliedAssistMode] = {
+            value = SharedEnums.AlliedAssistMode.Enabled,
+            locked = false
+        },
+        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
+            value = SharedEnums.AlliedUnitReclaimMode.Enabled,
+            locked = false
+        },
+    }
+}
diff --git a/sharing_modes/enabled.lua b/sharing_modes/enabled.lua
new file mode 100644
index 0000000000..3475c61cb8
--- /dev/null
+++ b/sharing_modes/enabled.lua
@@ -0,0 +1,42 @@
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+
+---@type SharingModeConfig
+return {
+    key = SharedEnums.SharingModes.Enabled,
+    name = "Enabled",
+    desc = "All sharing on with fixed defaults.",
+    allowRanked = true,
+    modOptions = {
+        [SharedEnums.ModOptions.UnitSharingMode] = {
+            value = SharedEnums.UnitSharingMode.Enabled,
+            locked = true,
+        },
+        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
+            value = true,
+            locked = true,
+        },
+        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
+            value = 0.0,
+            locked = true,
+            ui = "hidden"
+        },
+        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
+            value = 0,
+            locked = true,
+            ui = "hidden"
+        },
+        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
+            value = 0,
+            locked = true,
+            ui = "hidden"
+        },
+        [SharedEnums.ModOptions.AlliedAssistMode] = {
+            value = SharedEnums.AlliedAssistMode.Enabled,
+            locked = true,
+        },
+        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
+            value = SharedEnums.AlliedUnitReclaimMode.Enabled,
+            locked = true,
+        },
+    }
+}
diff --git a/sharing_modes/limited_sharing.lua b/sharing_modes/limited_sharing.lua
new file mode 100644
index 0000000000..d2667262c2
--- /dev/null
+++ b/sharing_modes/limited_sharing.lua
@@ -0,0 +1,39 @@
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+
+---@type SharingModeConfig
+return {
+    key = SharedEnums.SharingModes.LimitedSharing,
+    name = "Limited Sharing",
+    desc = "Allow T2 constructor sharing and payment, otherwise restrict sharing.",
+    allowRanked = true,
+    modOptions = {
+        [SharedEnums.ModOptions.UnitSharingMode] = {
+            value = SharedEnums.UnitSharingMode.T2Cons,
+            locked = true,
+        },
+        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
+            value = true,
+            locked = true,
+        },
+        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
+            value = 0.30,
+            locked = false,
+        },
+        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
+            value = 440,
+            locked = false,
+        },
+        [SharedEnums.ModOptions.PlayerEnergySendThreshold] = {
+            value = 0,
+            locked = false,
+        },
+        [SharedEnums.ModOptions.AlliedAssist] = {
+            value = SharedEnums.AlliedAssistMode.Enabled,
+            locked = false,
+        },
+        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
+            value = SharedEnums.AlliedUnitReclaimMode.Enabled,
+            locked = false,
+        },
+    }
+}
diff --git a/sharing_modes/no_sharing.lua b/sharing_modes/no_sharing.lua
new file mode 100644
index 0000000000..183bbca62d
--- /dev/null
+++ b/sharing_modes/no_sharing.lua
@@ -0,0 +1,37 @@
+local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
+
+---@type SharingModeConfig
+return {
+    key = SharedEnums.SharingModes.NoSharing,
+    name = "No Sharing",
+    desc = "Disable all sharing; apply a 30% tax; lock most controls.",
+    allowRanked = true,
+    modOptions = {
+        [SharedEnums.ModOptions.UnitSharingMode] = {
+            value = SharedEnums.UnitSharingMode.Disabled,
+            locked = true
+        },
+        [SharedEnums.ModOptions.ResourceSharingEnabled] = {
+            value = false,
+            locked = true
+        },
+        [SharedEnums.ModOptions.TaxResourceSharingAmount] = {
+            value = 0.30,
+            locked = false,
+            ui = "hidden"
+        },
+        [SharedEnums.ModOptions.PlayerMetalSendThreshold] = {
+            value = 0,
+            locked = true,
+            ui = "hidden"
+        },
+        [SharedEnums.ModOptions.AlliedAssist] = {
+            value = SharedEnums.AlliedAssistMode.Disabled,
+            locked = true
+        },
+        [SharedEnums.ModOptions.AlliedUnitReclaimMode] = {
+            value = SharedEnums.AlliedUnitReclaimMode.Disabled,
+            locked = true
+        },
+    }
+}
diff --git a/common/luaUtilities/team_transfer/shared_enums.lua b/sharing_modes/shared_enums.lua
similarity index 60%
rename from common/luaUtilities/team_transfer/shared_enums.lua
rename to sharing_modes/shared_enums.lua
index b6a67b0364..22608179cf 100644
--- a/common/luaUtilities/team_transfer/shared_enums.lua
+++ b/sharing_modes/shared_enums.lua
@@ -1,9 +1,26 @@
 local M = {}
 M.__index = M
 
+M.ModOptions = {
+	AlliedAssistMode = "allied_assist_mode",
+	AlliedUnitReclaimMode = "allied_reclaim_mode",
+	PlayerEnergySendThreshold = "player_energy_send_threshold",
+	PlayerMetalSendThreshold = "player_metal_send_threshold",
+	ResourceSharingEnabled = "resource_sharing_enabled",
+	TaxResourceSharingAmount = "tax_resource_sharing_amount",
+	UnitSharingMode = "unit_sharing_mode",
+}
+
+M.SharingModes = {
+	NoSharing = "no_sharing",
+	LimitedSharing = "limited_sharing",
+	Enabled = "enabled",
+	Customize = "customize",
+}
+
 M.TransferCategory = {
-	MetalTransfer = "metal_transfer",
 	EnergyTransfer = "energy_transfer",
+	MetalTransfer = "metal_transfer",
 	UnitTransfer = "unit_transfer"
 }
 
@@ -30,19 +47,19 @@ M.UnitCommunicationCase = {
 }
 
 M.UnitValidationOutcome = {
-	Success = "Success",
 	Failure = "Failure",
 	PartialSuccess = "PartialSuccess",
+	Success = "Success",
 }
 
 M.UnitSharingMode = {
 	Disabled = "disabled",
-	Enabled = "enabled",
+	CombatT2Cons = "combat_t2_cons",
 	CombatUnits = "combat",
 	Economic = "economic",
 	EconomicPlusBuildings = "economic_plus_buildings",
+	Enabled = "enabled",
 	T2Cons = "t2_cons",
-	CombatT2Cons = "combat_t2_cons",
 }
 
 M.UnitType = {
@@ -52,4 +69,14 @@ M.UnitType = {
 	T2Constructor = "t2_constructor",
 }
 
+M.AlliedAssistMode = {
+	Disabled = "disabled",
+	Enabled = "enabled",
+}
+
+M.AlliedUnitReclaimMode = {
+	Disabled = "disabled",
+	Enabled = "enabled",
+}
+
 return M
diff --git a/types/sharing_modes.lua b/types/sharing_modes.lua
new file mode 100644
index 0000000000..539b60b02f
--- /dev/null
+++ b/types/sharing_modes.lua
@@ -0,0 +1,18 @@
+---@class ModOptionConfig
+---@field value any The default value for this option
+---@field locked boolean Whether this option can be changed by users
+---@field bounds ModOptionBounds|nil Constraints on the option value
+---@field ui string|nil UI hints (e.g., "hidden")
+
+---@class ModOptionBounds
+---@field min number|nil Minimum value (for numeric options)
+---@field max number|nil Maximum value (for numeric options)
+---@field step number|nil Step size for numeric options
+---@field items table|nil Array of allowed values for list options
+
+---@class SharingModeConfig
+---@field key string Unique identifier for this sharing mode
+---@field name string Display name for this sharing mode
+---@field desc string Description of this sharing mode
+---@field allowRanked boolean Whether this mode is allowed in ranked games
+---@field modOptions table<string, ModOptionConfig> Map of mod option keys to their configurations
diff --git a/types/team_transfer.lua b/types/team_transfer.lua
index 098cf30348..97509e2145 100644
--- a/types/team_transfer.lua
+++ b/types/team_transfer.lua
@@ -4,6 +4,7 @@
 ---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "guard_transfer" | "repair_transfer" | "reclaim_transfer"
 ---@alias ResourceType "metal" | "energy"
 ---@alias UnitValidationOutcome "success" | "disabled" | "partial_success"
+---@alias SharingMode "disabled" | "enabled" | "limited_sharing"
 
 ---@class ValidationResult
 ---@field ok boolean

commit d84a11c782c0488470e90823b706f5fa58b9e766
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Wed Oct 22 10:53:41 2025 -0600

    Revert "feat: tax overflow"
    
    This reverts commit 8d6917d97a2c51db0f017a86388145f741d883fc.

diff --git a/luarules/gadgets/game_tax_resource_sharing.lua b/luarules/gadgets/game_tax_resource_sharing.lua
index 07fdee51d1..b19ffe5a54 100644
--- a/luarules/gadgets/game_tax_resource_sharing.lua
+++ b/luarules/gadgets/game_tax_resource_sharing.lua
@@ -12,7 +12,7 @@ function gadget:GetInfo()
   }
 end
 
-local POLICY_CACHE_TAINT_FRAME_RATE = 30 -- Rebuild policies every second to keep up with frequent cumulative sent changes
+local POLICY_CACHE_TAINT_FRAME_RATE = 30 -- every 1 second to keep up with overflow detection
 
 ----------------------------------------------------------------
 -- Synced only
@@ -37,12 +37,6 @@ local policyResultFactory = ResourceTransfer.BuildResultFactory(sharingTax, meta
 
 local lastGameFrameCacheUpdate = 0
 
--- Track engine-pipeline resource stats to detect overflow receives and engine-driven sends
--- We record cumulative counters and take diffs per update window.
-local lastRecvStats = {}   -- [teamId] = { m = 0, e = 0 }
-local lastSentStats = {}   -- [teamId] = { m = 0, e = 0 }
-local manualRecvSinceLastOverflowCalc = {} -- [teamId] = { m = 0, e = 0 }
-
 ----------------------------------------------------------------
 -- Initialization
 ----------------------------------------------------------------
@@ -72,22 +66,13 @@ local function InitializeNewTeam(senderTeamId, receiverTeamId)
 end
 
 function gadget:Initialize()
-  local teamList = Spring.GetTeamList()
+  local teamList = Spring.GetTeamList() or {}
 
   for _, senderTeamId in ipairs(teamList) do
     for _, receiverTeamId in ipairs(teamList) do
       InitializeNewTeam(senderTeamId, receiverTeamId)
     end
   end
-
-  -- snapshot engine cumulative stats so first diff is zero
-  for _, teamId in ipairs(teamList) do
-    local _uM, _pM, _xM, recvM, sentM = Spring.GetTeamResourceStats(teamId, "m")
-    local _uE, _pE, _xE, recvE, sentE = Spring.GetTeamResourceStats(teamId, "e")
-    lastRecvStats[teamId] = { m = recvM, e = recvE }
-    lastSentStats[teamId] = { m = sentM, e = sentE }
-    manualRecvSinceLastOverflowCalc[teamId] = { m = 0, e = 0 }
-  end
   lastGameFrameCacheUpdate = Spring.GetGameFrame()
 end
 
@@ -106,109 +91,26 @@ function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType
 
   -- immediately rebuild the cache for this resource
   local policyCtx = contextFactory.policy(senderTeamId, receiverTeamId)
+  local frame = Spring.GetGameFrame()
   local updatedPolicyResult = BuildPolicyCache(policyCtx, resType)
   Comms.SendTransferChatMessages(transferResult, updatedPolicyResult)
 
-  -- Track manual receives to avoid canceling/taxing them in overflow step
-  if transferResult and transferResult.success and transferResult.received and transferResult.received > 0 then
-    local key = (resType == SharedEnums.ResourceType.METAL) and 'm' or 'e'
-    local bucket = manualRecvSinceLastOverflowCalc[receiverTeamId]
-    if not bucket then
-      bucket = { m = 0, e = 0 }
-      manualRecvSinceLastOverflowCalc[receiverTeamId] = bucket
-    end
-    bucket[key] = (bucket[key]) + transferResult.received
-  end
-
   return false
 end
 
 function gadget:GameFrame(frame)
-  -- rebuild policy caches every 30 frames
-  -- exactly one frame after teamhandler calls team->SlowUpdate() where overflow happens (and teamres stats get updated)
-  if (frame % POLICY_CACHE_TAINT_FRAME_RATE) ~= 1 then
+  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
+  if frame < nextSchedHeavy then
     return
   end
-
-  local teamList = Spring.GetTeamList()
-
-  -- tax overflows immediately when detected to prevent spending before taxation
-  -- it is still theoretically possible to spend before taxation, but it is very unlikely
-  if sharingTax and sharingTax > 0 then
-    for _, teamId in ipairs(teamList) do
-      local _uM, _pM, _xM, curRecvM, curSentM = Spring.GetTeamResourceStats(teamId, "m")
-      local _uE, _pE, _xE, curRecvE, curSentE = Spring.GetTeamResourceStats(teamId, "e")
-
-      local prevRecv = lastRecvStats[teamId]
-      local prevSent = lastSentStats[teamId]
-      if not prevRecv then
-        prevRecv = { m = 0, e = 0 }
-        lastRecvStats[teamId] = prevRecv
-      end
-      if not prevSent then
-        prevSent = { m = 0, e = 0 }
-        lastSentStats[teamId] = prevSent
-      end
-
-      local diffRecvM = math.max(0, curRecvM - prevRecv.m)
-      local diffRecvE = math.max(0, curRecvE - prevRecv.e)
-
-      local diffSentM = math.max(0, curSentM - prevSent.m)
-      local diffSentE = math.max(0, curSentE - prevSent.e)
-
-      -- Apply receiver-side tax only to overflow portion (engine received minus manual receives tracked)
-      local manual = manualRecvSinceLastOverflowCalc[teamId]
-      local overflowRecvM = math.max(0, diffRecvM - manual.m)
-      local overflowRecvE = math.max(0, diffRecvE - manual.e)
-
-      -- Tax overflow immediately when detected to prevent spending before taxation
-      if overflowRecvM > 0 then
-        local taxedM = overflowRecvM * sharingTax
-        if taxedM > 0 then
-          Spring.UseTeamResource(teamId, "metal", taxedM)
-        end
-      end
-      if overflowRecvE > 0 then
-        local taxedE = overflowRecvE * sharingTax
-        if taxedE > 0 then
-          Spring.UseTeamResource(teamId, "energy", taxedE)
-        end
-      end
-
-      -- Attribute engine-driven sends to our cumulative sender counters so thresholds include overflow sharing
-      -- Manual transfers bypass engine pipeline so they're counted in RegisterPostTransfer, overflow sends here
-      if diffSentM > 0 then
-        local cumulativeParam = Shared.GetCumulativeParam(SharedEnums.ResourceType.METAL)
-        local cumulativeVal = tonumber(Spring.GetTeamRulesParam(teamId, cumulativeParam))
-        Spring.SetTeamRulesParam(teamId, cumulativeParam, cumulativeVal + diffSentM)
-      end
-      if diffSentE > 0 then
-        local cumulativeParam = Shared.GetCumulativeParam(SharedEnums.ResourceType.ENERGY)
-        local cumulativeVal = tonumber(Spring.GetTeamRulesParam(teamId, cumulativeParam))
-        Spring.SetTeamRulesParam(teamId, cumulativeParam, cumulativeVal + diffSentE)
-      end
-
-      -- Update stats for next frame comparison
-      lastRecvStats[teamId].m = curRecvM
-      lastRecvStats[teamId].e = curRecvE
-      lastSentStats[teamId].m = curSentM
-      lastSentStats[teamId].e = curSentE
-    end
-  end
-
-  for _, teamId in ipairs(teamList) do
-    manualRecvSinceLastOverflowCalc[teamId] = { m = 0, e = 0 }
-  end
-
-  -- 2) Rebuild policy caches
-  local cacheRebuildCount = 0
+  local teamList = Spring.GetTeamList() or {}
+  lastGameFrameCacheUpdate = frame
   for _, senderTeamId in ipairs(teamList) do
     -- we also calculate me -> me for standardized resource request limits
     for _, receiverTeamId in ipairs(teamList) do
       local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
       for _, resourceType in ipairs(RESOURCE_TYPES) do
         BuildPolicyCache(ctx, resourceType)
-        cacheRebuildCount = cacheRebuildCount + 1
       end
     end
   end

commit 8c843399cecdfaa36a4cb80f54b0858b339311dc
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Tue Oct 21 18:28:43 2025 -0600

    feat: highlight invalid units
    
    Had to add an api_extensions because gui_advplayerlist (especially draw) is hitting its local variable limit. Split it off into its own file in teamtransfer since it's api_extensions for that thing

diff --git a/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua b/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
new file mode 100644
index 0000000000..b35eaeff07
--- /dev/null
+++ b/common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua
@@ -0,0 +1,85 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
+local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
+
+local API = {}
+
+-- Hover listener management
+local hoverChangeListeners = {}
+
+---@param listener function
+function API.AddHoverChangeListener(listener)
+    table.insert(hoverChangeListeners, listener)
+end
+
+---@param listener function
+function API.RemoveHoverChangeListener(listener)
+    for i, existingListener in ipairs(hoverChangeListeners) do
+        if existingListener == listener then
+            table.remove(hoverChangeListeners, i)
+            break
+        end
+    end
+end
+
+---Handle hover changes and notify about invalid units for the hovered player
+---@param myTeamID number
+---@param selectedUnits number[]
+---@param newHoverTeamID number | nil
+---@param newHoverPlayerID number | nil
+function API.HandleHoverChange(myTeamID, selectedUnits, newHoverTeamID, newHoverPlayerID)
+    -- Notify hover change listeners
+    API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)
+
+    -- Notify about invalid units (or clear them if not hovering)
+    if newHoverTeamID and selectedUnits and #selectedUnits > 0 then
+        local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, newHoverTeamID)
+        local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits)
+        if #validationResult.invalidUnitIds > 0 then
+            API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, validationResult.invalidUnitIds)
+        else
+            -- No invalid units, but still notify to clear any previous invalid state
+            API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
+        end
+    else
+        -- Not hovering or no selected units, clear invalid state
+        API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
+    end
+end
+
+---@param newHoverTeamID number | nil
+---@param newHoverPlayerID number | nil
+function API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)
+    for _, listener in ipairs(hoverChangeListeners) do
+        listener(newHoverTeamID, newHoverPlayerID)
+    end
+end
+
+-- Hover invalid units listeners
+local hoverInvalidUnitsListeners = {}
+
+---@param listener function
+function API.AddHoverInvalidUnitsListener(listener)
+    table.insert(hoverInvalidUnitsListeners, listener)
+end
+
+---@param listener function
+function API.RemoveHoverInvalidUnitsListener(listener)
+    for i, existingListener in ipairs(hoverInvalidUnitsListeners) do
+        if existingListener == listener then
+            table.remove(hoverInvalidUnitsListeners, i)
+            break
+        end
+    end
+end
+
+---@param newHoverTeamID number | nil
+---@param newHoverPlayerID number | nil
+---@param invalidUnitIds number[]
+function API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
+    for _, listener in ipairs(hoverInvalidUnitsListeners) do
+        listener(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
+    end
+end
+
+return API
diff --git a/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua b/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
new file mode 100644
index 0000000000..3b342174c9
--- /dev/null
+++ b/common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua
@@ -0,0 +1,190 @@
+--- holds helper functions for the gui_advplayerslist.lua
+--- these are related to team transfer, but highly specific to the gui
+--- gui_advplayerslist has severe restrictions on the number of local cosures due to lua 5.1's 200 cap
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
+local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
+
+local METAL_POLICY_PREFIX = "metal_"
+local ENERGY_POLICY_PREFIX = "energy_"
+local UNIT_POLICY_PREFIX = "unit_"
+
+local Helpers = {}
+
+---@param player table
+---@param resourceType string
+---@param senderTeamId number
+---@return ResourcePolicyResult policyResult, string pascalResourceType
+function Helpers.GetPlayerPolicy(player, resourceType, senderTeamId)
+  local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
+  local policyResult = Helpers.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
+  local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
+  return policyResult, pascalResourceType
+end
+
+--- Handle resource transfer logic
+---@param targetPlayer table
+---@param resourceType string
+---@param shareAmount number
+---@param senderTeamId number
+function Helpers.HandleResourceTransfer(targetPlayer, resourceType, shareAmount, senderTeamId)
+  local policyResult, pascalResourceType = Helpers.GetPlayerPolicy(targetPlayer, resourceType, senderTeamId)
+
+  local case = ResourceShared.DecideCommunicationCase(policyResult)
+
+  if case == SharedEnums.ResourceCommunicationCase.OnSelf then
+    if shareAmount > 0 then
+      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount=' .. shareAmount)
+    else
+      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
+    end
+  else
+    if shareAmount and shareAmount > 0 then
+      Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
+    end
+  end
+end
+
+-- UI state packing functions for player data
+---@param validationResult UnitValidationResult
+---@param playerData table
+function Helpers.PackSelectedUnitsValidation(validationResult, playerData)
+    playerData.selectedUnitsValidation = validationResult
+end
+
+---@param playerData table
+function Helpers.ClearSelectedUnitsValidation(playerData)
+    playerData.selectedUnitsValidation = nil
+end
+
+---@param playerData table
+---@return UnitValidationResult | nil
+function Helpers.UnpackSelectedUnitsValidation(playerData)
+    return playerData.selectedUnitsValidation
+end
+
+---@param playerData table
+---@param myTeamID number
+---@param playerTeamID number
+function Helpers.PackAllPoliciesForPlayer(playerData, myTeamID, playerTeamID)
+    -- Pack all policy types for the player
+    Helpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
+    Helpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)
+
+    -- For unit policy, we need to get it from cache and pack it
+    local unitPolicy = UnitShared.GetCachedPolicyResult(myTeamID, playerTeamID)
+    Helpers.PackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, unitPolicy, playerData)
+end
+
+---@param playerData table
+---@param myTeamID number
+---@param team number
+---@return table, table, table
+function Helpers.UnpackAllPolicies(playerData, myTeamID, team)
+    local metalPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, myTeamID, team)
+    local energyPolicy = Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, myTeamID, team)
+    local unitPolicy = Helpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
+    return metalPolicy, energyPolicy, unitPolicy
+end
+
+---Unpack policy result for a given transfer category
+---@param transferCategory string SharedEnums.TransferCategory
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return table
+function Helpers.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
+  local fields, prefix
+  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = METAL_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = ENERGY_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
+    fields = UnitShared.UnitPolicyFields
+    prefix = UNIT_POLICY_PREFIX
+  else
+    error("Invalid transfer category: " .. transferCategory)
+  end
+
+  local result = {
+    senderTeamId = senderTeamId,
+    receiverTeamId = receiverTeamId
+  }
+  for field, _ in pairs(fields) do
+    result[field] = playerData[prefix .. field]
+  end
+  return result
+end
+
+---Unpack unit policy result from player data
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return UnitPolicyResult
+function Helpers.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
+  return Helpers.UnpackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
+    receiverTeamId)
+end
+
+---Pack policy result for a given transfer category
+---@param transferCategory string SharedEnums.TransferCategory
+---@param policy table
+---@param playerData table
+function Helpers.PackPolicyResult(transferCategory, policy, playerData)
+  local fields, prefix
+  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = METAL_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = ENERGY_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
+    fields = UnitShared.UnitPolicyFields
+    prefix = UNIT_POLICY_PREFIX
+  else
+    error("Invalid transfer category: " .. transferCategory)
+  end
+  for field, _ in pairs(fields) do
+    playerData[prefix .. field] = policy[field]
+  end
+end
+
+---@param team number
+---@param myTeamID number
+---@param player table
+function Helpers.PackMetalPolicyResult(team, myTeamID, player)
+    -- Get the metal policy and pack it
+    local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.METAL)
+    Helpers.PackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, policyResult, player)
+end
+
+---@param team number
+---@param myTeamID number
+---@param player table
+function Helpers.PackEnergyPolicyResult(team, myTeamID, player)
+    -- Get the energy policy and pack it
+    local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, SharedEnums.ResourceType.ENERGY)
+    Helpers.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policyResult, player)
+end
+
+-- Function to handle selection changes and update validations for all players
+---@param player table -- The player table from gui_advplayerslist.lua
+---@param myTeamID number
+---@param selectedUnits number[]
+function Helpers.UpdatePlayerUnitValidations(player, myTeamID, selectedUnits)
+    for playerID, playerData in pairs(player) do
+        if playerData.team and playerID ~= myTeamID then
+            if selectedUnits and #selectedUnits > 0 then
+                local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, playerData.team)
+                local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits)
+                Helpers.PackSelectedUnitsValidation(validationResult, playerData)
+            else
+                Helpers.ClearSelectedUnitsValidation(playerData)
+            end
+        end
+    end
+end
+
+return Helpers
diff --git a/common/luaUtilities/team_transfer/resource_transfer_comms.lua b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
index 9a6feb24d0..d394738de5 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_comms.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
@@ -1,6 +1,8 @@
 local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
 
-local Comms = {}
+local Comms = {
+  ResourceCommunicationCase = SharedEnums.ResourceCommunicationCase,
+}
 Comms.__index = Comms
 
 --- Determine communication case from parameters
diff --git a/common/luaUtilities/team_transfer/resource_transfer_shared.lua b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
index f922483c50..cd47fca9a4 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
@@ -1,7 +1,8 @@
 local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
 local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
+local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
 
-local Shared = {}
+local Shared = Comms
 
 local FieldTypes = PolicyShared.FieldTypes
 
diff --git a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
index 5d8c050ab1..bfd25bc974 100644
--- a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
+++ b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
@@ -1,255 +1,10 @@
 local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
-local TeamTransferCache = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
-
-local ResourceComms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
-local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
-
 local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
-local UnitComms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")
-
-local metalPolicyScratch = {}
-local energyPolicyScratch = {}
-local unitPolicyScratch = {}
-local selectedUnitsValidationScratch = {}
-
-local METAL_POLICY_PREFIX = "metalPolicy_"
-local ENERGY_POLICY_PREFIX = "energyPolicy_"
-local UNIT_POLICY_PREFIX = "unitPolicy_"
-local SELECTED_UNITS_VALIDATION_PREFIX = "selectedUnitsValidation_"
-local SELECTED_UNITS_VALIDATION_FIELDS = {
-  "status",
-  "validUnitCount",
-  "validUnitIds",
-  "invalidUnitCount",
-  "invalidUnitIds",
-  "validUnitNames",
-  "invalidUnitNames"
-}
-
-local ResourceWidgets = {
-  CalculateSenderTaxedAmount = ResourceShared.CalculateSenderTaxedAmount,
-  FormatNumberForUI = ResourceComms.FormatNumberForUI,
-  CommunicationCase = SharedEnums.ResourceCommunicationCase,
-  GetCachedPolicyResult = ResourceShared.GetCachedPolicyResult,
-  ResourceTypes = SharedEnums.ResourceTypes,
-  DecideCommunicationCase = ResourceComms.DecideCommunicationCase,
-  TooltipText = ResourceComms.TooltipText,
-  SendTransferChatMessages = ResourceComms.SendTransferChatMessages,
-}
-ResourceWidgets.__index = ResourceWidgets
-
-local UnitWidgets = {
-  GetCachedPolicyResult = UnitShared.GetCachedPolicyResult,
-  ValidateUnits = UnitShared.ValidateUnits,
-  DecideCommunicationCase = UnitComms.DecideCommunicationCase,
-  TooltipText = UnitComms.UnitShareTooltip,
-}
-UnitWidgets.__index = UnitWidgets
-
-local TeamTransfer = {
-  Resources = ResourceWidgets,
-  Units = UnitWidgets,
-}
-
---------------------------------------------------------
---- Resource Transfer
---------------------------------------------------------
-
----@param player table
----@param resourceType string
----@param senderTeamId number
----@return ResourcePolicyResult policyResult
-function ResourceWidgets.GetPlayerPolicy(player, resourceType, senderTeamId)
-  local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
-  local policyResult = TeamTransfer.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
-  return policyResult
-end
-
---- Handle resource transfer logic
----@param targetPlayer table
----@param resourceType string
----@param shareAmount number
----@param senderTeamId number
-function ResourceWidgets.HandleResourceTransfer(targetPlayer, resourceType, shareAmount, senderTeamId)
-  local policyResult, pascalResourceType = ResourceWidgets.GetPlayerPolicy(targetPlayer, resourceType, senderTeamId)
-
-  local case = ResourceWidgets.DecideCommunicationCase(policyResult)
-
-  if case == ResourceWidgets.CommunicationCase.OnSelf then
-    if shareAmount > 0 then
-      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount=' .. shareAmount)
-    else
-      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
-    end
-  else
-    if shareAmount and shareAmount > 0 then
-      Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
-    end
-  end
-end
-
---------------------------------------------------------
---- gui_advplayerlist.lua helper functions
---------------------------------------------------------
-
----@param playerData table
----@param senderTeamId number
----@param receiverTeamId number
----@return ResourcePolicyResult? metalPolicy, ResourcePolicyResult? energyPolicy, UnitPolicyResult? unitPolicy
-function TeamTransfer.UnpackAllPolicies(playerData, senderTeamId, receiverTeamId)
-  local hasPackedData = playerData[METAL_POLICY_PREFIX .. "canShare"] ~= nil
-  if not hasPackedData then return nil, nil, nil end
-
-  local metalPolicy = TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
-  local energyPolicy = TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
-  local unitPolicy = TeamTransfer.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
-
-  return metalPolicy, energyPolicy, unitPolicy
-end
-
----Unpack selected units validation result from player data
----@param playerData table
----@return UnitValidationResult
-function TeamTransfer.UnpackSelectedUnitsValidation(playerData)
-  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
-    selectedUnitsValidationScratch[field] = playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field]
-  end
-  return selectedUnitsValidationScratch
-end
-
----Pack selected units validation result into player data
----@param validationResult table
----@param playerData table
-function TeamTransfer.PackSelectedUnitsValidation(validationResult, playerData)
-  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
-    playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field] = validationResult[field]
-  end
-end
-
----Clear selected units validation result from player data
----@param playerData table
-function TeamTransfer.ClearSelectedUnitsValidation(playerData)
-  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
-    playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field] = nil
-  end
-end
-
----This and its sibling hydrate existing tables with a policyResult so we don't thrash GC
----@param transferCategory string SharedEnums.TransferCategory
----@param playerData table
----@param senderTeamId number
----@param receiverTeamId number
-function TeamTransfer.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
-  local scratch, fields, prefix
-  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
-    scratch = metalPolicyScratch
-    fields = ResourceShared.ResourcePolicyFields
-    prefix = METAL_POLICY_PREFIX
-  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
-    scratch = energyPolicyScratch
-    fields = ResourceShared.ResourcePolicyFields
-    prefix = ENERGY_POLICY_PREFIX
-  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
-    scratch = unitPolicyScratch
-    fields = UnitShared.UnitPolicyFields
-    prefix = UNIT_POLICY_PREFIX
-  end
-  scratch.senderTeamId = senderTeamId
-  scratch.receiverTeamId = receiverTeamId
-  for field, _ in pairs(fields) do
-    scratch[field] = playerData[prefix .. field]
-  end
-  return scratch
-end
-
----Unpack metal policy result from player data
----@param playerData table
----@param senderTeamId number
----@param receiverTeamId number
----@return ResourcePolicyResult
-function TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
-  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, senderTeamId,
-    receiverTeamId)
-end
-
----Unpack energy policy result from player data
----@param playerData table
----@param senderTeamId number
----@param receiverTeamId number
----@return ResourcePolicyResult
-function TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
-  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, senderTeamId,
-    receiverTeamId)
-end
-
----Unpack unit policy result from player data
----@param playerData table
----@param senderTeamId number
----@param receiverTeamId number
----@return UnitPolicyResult
-function TeamTransfer.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
-  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
-    receiverTeamId)
-end
-
----Pack policy result for a given transfer category
----@param transferCategory string SharedEnums.TransferCategory
----@param policy table
----@param playerData table
-function TeamTransfer.PackPolicyResult(transferCategory, policy, playerData)
-  local fields, prefix
-  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
-    fields = ResourceShared.ResourcePolicyFields
-    prefix = METAL_POLICY_PREFIX
-  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
-    fields = ResourceShared.ResourcePolicyFields
-    prefix = ENERGY_POLICY_PREFIX
-  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
-    fields = UnitShared.UnitPolicyFields
-    prefix = UNIT_POLICY_PREFIX
-  else
-    error("Invalid transfer category: " .. transferCategory)
-  end
-  for field, _ in pairs(fields) do
-    playerData[prefix .. field] = policy[field]
-  end
-end
-
----Pack metal policy result into player data
----@param senderTeamId number
----@param receiverTeamId number
----@param playerData table
-function TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
-  local policy = ResourceWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId, "metal")
-  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, policy, playerData)
-end
-
----Pack energy policy result into player data
----@param senderTeamId number
----@param receiverTeamId number
----@param playerData table
-function TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
-  local policy = ResourceWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId, "energy")
-  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policy, playerData)
-end
+local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
 
----Pack unit policy result into player data
----@param senderTeamId number
----@param receiverTeamId number
----@param playerData table
-function TeamTransfer.PackUnitPolicyResult(senderTeamId, receiverTeamId, playerData)
-  local policy = UnitWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId)
-  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, policy, playerData)
-end
+local TeamTransfer = {}
 
---- Pack all policies for a given player
----@param playerData table
----@param senderTeamId number
----@param receiverTeamId number
-function TeamTransfer.PackAllPoliciesForPlayer(playerData, senderTeamId, receiverTeamId)
-  TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
-  TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
-  TeamTransfer.PackUnitPolicyResult(senderTeamId, receiverTeamId, playerData)
-end
+TeamTransfer.Units = UnitShared
+TeamTransfer.Resources = ResourceShared
 
 return TeamTransfer
diff --git a/common/luaUtilities/team_transfer/unit_transfer_comms.lua b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
index 68839f531b..1b4d27f962 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_comms.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
@@ -1,6 +1,8 @@
 local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
 
-local Comms = {}
+local Comms = {
+  UnitCommunicationCase = SharedEnums.UnitCommunicationCase,
+}
 Comms.__index = Comms
 
 ---Decide communication case for unit sharing based on policy and optional validation results
@@ -58,10 +60,7 @@ function Comms.TooltipText(policy, validationResult)
     end
   elseif case == SharedEnums.UnitCommunicationCase.OnFullyShareable then
     if validationResult then
-      local i18nData = {
-        validUnitCount = validationResult.validUnitCount,
-      }
-      return Spring.I18N(baseKey .. '.shareUnits', i18nData)
+      return Spring.I18N(baseKey .. '.shareUnits')
     else
       return Spring.I18N(baseKey .. '.shareUnits')
     end
diff --git a/common/luaUtilities/team_transfer/unit_transfer_shared.lua b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
index 783bcd729a..91fe1816ee 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
@@ -1,8 +1,9 @@
 local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
 local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
 local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
+local Comms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")
 
-local Shared = {}
+local Shared = Comms
 
 local FieldTypes = PolicyShared.FieldTypes
 Shared.UnitPolicyFields = {
@@ -39,7 +40,6 @@ function Shared.ValidateUnits(policyResult, unitIds)
   for _, unitId in ipairs(unitIds) do
     local unitDefID = Spring.GetUnitDefID(unitId)
     if not unitDefID then
-      Spring.Log("unit_transfer_shared", LOG.ERROR, "ValidateUnits: unitId", unitId, "not found")
       out.invalidUnitCount = out.invalidUnitCount + 1
       table.insert(out.invalidUnitIds, unitId)
       table.insert(out.invalidUnitNames, "Unknown Unit")
diff --git a/language/en/interface.json b/language/en/interface.json
index eebed2a1c4..04e158f665 100644
--- a/language/en/interface.json
+++ b/language/en/interface.json
@@ -84,7 +84,7 @@
 			"requestSupport": "Double-click to ask for support",
 			"requestMetal": "Click-and-drag to ask for metal",
 			"requestEnergy": "Click-and-drag to ask for energy",
-			"shareUnits": "Double-click to share %{validUnitCount} units",
+			"shareUnits": "Double-click to share units",
 			"shareUnitsInvalid": {
 				"all": "Sharing these units are not allowed",
 				"one": "Double-click to share units (mode is %{unitSharingMode} - %{firstInvalidUnitName} cannot be shared)",
diff --git a/luaui/Shaders/DrawPrimitiveAtUnit.frag.glsl b/luaui/Shaders/DrawPrimitiveAtUnit.frag.glsl
index 5fe795c294..30f5b80866 100644
--- a/luaui/Shaders/DrawPrimitiveAtUnit.frag.glsl
+++ b/luaui/Shaders/DrawPrimitiveAtUnit.frag.glsl
@@ -13,6 +13,7 @@ uniform float iconDistance = 20000.0;
 in DataGS {
 	vec4 g_color;
 	vec4 g_uv;
+	float g_invalid;
 };
 
 uniform sampler2D DrawPrimitiveAtUnitTexture;
diff --git a/luaui/Shaders/DrawPrimitiveAtUnit.geom.glsl b/luaui/Shaders/DrawPrimitiveAtUnit.geom.glsl
index b805d9b64f..c2333a31b4 100644
--- a/luaui/Shaders/DrawPrimitiveAtUnit.geom.glsl
+++ b/luaui/Shaders/DrawPrimitiveAtUnit.geom.glsl
@@ -29,6 +29,7 @@ in DataVS {
 out DataGS {
 	vec4 g_color;
 	vec4 g_uv;
+	float g_invalid;
 };
 
 mat3 rotY;
@@ -56,6 +57,7 @@ void offsetVertex4(float x, float y, float z, float u, float v, float addRadiusC
 		gl_Position.z = (gl_Position.z) - ZPULL / (gl_Position.w); // send 16 elmos forward in depth buffer
 	#endif 
 	g_uv.zw = dataIn[0].v_parameters.zw;
+	g_invalid = dataIn[0].v_parameters.y;
 	POST_GEOMETRY
 	EmitVertex();
 }
diff --git a/luaui/Widgets/gui_advplayerslist.lua b/luaui/Widgets/gui_advplayerslist.lua
index f5cd841bbf..35724fc59c 100644
--- a/luaui/Widgets/gui_advplayerslist.lua
+++ b/luaui/Widgets/gui_advplayerslist.lua
@@ -63,7 +63,8 @@ end
 local SharedEnums = VFS.Include('common/luaUtilities/team_transfer/shared_enums.lua')
 local TeamTransfer = VFS.Include('common/luaUtilities/team_transfer/team_transfer_unsynced.lua')
 local ResourceTransfer = TeamTransfer.Resources
-local UnitTransfer = TeamTransfer.Units
+local ApiExtensions = VFS.Include('common/luaUtilities/team_transfer/gui_advplayerlist_api_extensions.lua')
+local Helpers = VFS.Include('common/luaUtilities/team_transfer/gui_advplayerlist_helpers.lua')
 
 --------------------------------------------------------------------------------
 -- Config
@@ -228,8 +229,10 @@ local Background, ShareSlider, BackgroundGuishader, tipText, tipTextTitle, drawT
 --local specJoinedOnce, scheduledSpecFullView
 --local prevClickedPlayer, clickedPlayerTime, clickedPlayerID
 local lockPlayerID  --leftPosX, lastSliderSound, release
+local hoveredPlayerID = nil
 local MainList, MainList2, MainList3, drawListOffset
 
+
 local deadPlayerHeightReduction = 8
 
 local reportTake = false
@@ -759,18 +762,7 @@ function ActivityEvent(playerID)
 end
 
 function widget:SelectionChanged(selectedUnits)
-    local myTeamID = Spring_GetMyTeamID()
-    for playerID, playerData in pairs(player) do
-        if playerData.team and playerID ~= myTeamID then
-            if selectedUnits and #selectedUnits > 0 then
-                local policyResult = UnitTransfer.GetCachedPolicyResult(myTeamID, playerData.team)
-                local validationResult = UnitTransfer.ValidateUnits(policyResult, selectedUnits)
-                TeamTransfer.PackSelectedUnitsValidation(validationResult, playerData)
-            else
-                TeamTransfer.ClearSelectedUnitsValidation(playerData)
-            end
-        end
-    end
+    Helpers.UpdatePlayerUnitValidations(player, myTeamID, selectedUnits)
 end
 
 
@@ -972,6 +964,11 @@ function widget:Initialize()
 		end
 	end
 
+	WG['advplayerlist_api'].AddHoverChangeListener = ApiExtensions.AddHoverChangeListener
+	WG['advplayerlist_api'].RemoveHoverChangeListener = ApiExtensions.RemoveHoverChangeListener
+	WG['advplayerlist_api'].AddHoverInvalidUnitsListener = ApiExtensions.AddHoverInvalidUnitsListener
+	WG['advplayerlist_api'].RemoveHoverInvalidUnitsListener = ApiExtensions.RemoveHoverInvalidUnitsListener
+
 	widgetHandler:AddAction("speclist", speclistCmd, nil, 't')
 end
 
@@ -1393,7 +1390,7 @@ function UpdatePlayerResources()
 			end
         end
         if player[playerID].team then
-            TeamTransfer.PackAllPoliciesForPlayer(player[playerID], myTeamID, player[playerID].team)
+            Helpers.PackAllPoliciesForPlayer(player[playerID], myTeamID, player[playerID].team)
         end
     end
 
@@ -1899,7 +1896,7 @@ end
 ---------------------------------------------------------------------------------------------------
 
 local function updateShareAmount(player, resourceType)
-    local policyResult = ResourceTransfer.GetPlayerPolicy(player, resourceType, myTeamID)
+    local policyResult = Helpers.GetPlayerPolicy(player, resourceType, myTeamID)
     if not policyResult.amountSendable then
         shareAmount = 0
         return
@@ -2229,8 +2226,8 @@ function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY, onlyMainList, onl
     local alliances = player[playerID].alliances
     local metalPolicy, energyPolicy, unitPolicy, unitValidationResult
     if not spec then
-        metalPolicy, energyPolicy, unitPolicy = TeamTransfer.UnpackAllPolicies(player[playerID], myTeamID, team)
-        unitValidationResult = TeamTransfer.UnpackSelectedUnitsValidation(player[playerID])
+        metalPolicy, energyPolicy, unitPolicy = Helpers.UnpackAllPolicies(player[playerID], myTeamID, team)
+        unitValidationResult = Helpers.UnpackSelectedUnitsValidation(player[playerID])
     end
     local posY = widgetPosY + widgetHeight - vOffset
     local tipPosY = widgetPosY + ((widgetHeight - vOffset) * widgetScale)
@@ -2254,8 +2251,15 @@ function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY, onlyMainList, onl
             alpha = alphaActivity
         end
     end
-    if mouseY >= tipPosY and mouseY <= tipPosY + (16 * widgetScale * playerScale) then
+    -- detect hover on the entire row bounds so we can detect when the moust leaves the row
+    local rowTop = posY
+    local rowBottom = posY + (playerOffset*playerScale)
+    if IsOnRect(mouseX, mouseY, widgetPosX, rowTop, widgetPosX + widgetWidth, rowBottom) then
         tipY = true
+        if hoveredPlayerID ~= playerID and player[playerID] and player[playerID].team then
+            local selectedUnits = Spring.GetSelectedUnits()
+            ApiExtensions.HandleHoverChange(myTeamID, selectedUnits, player[playerID].team, playerID)
+        end
     end
 
     if onlyMainList and lockPlayerID and lockPlayerID == playerID then
@@ -3068,7 +3072,7 @@ end
 
 function ShareTip(mouseX, unitPolicy, metalPolicy, energyPolicy, unitValidationResult)
     if mouseX >= widgetPosX + (m_share.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (17*playerScale)) * widgetScale then
-        tipText = UnitTransfer.TooltipText(unitPolicy, unitValidationResult)
+        tipText = TeamTransfer.Units.TooltipText(unitPolicy, unitValidationResult)
     elseif mouseX >= widgetPosX + (m_share.posX + (19*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (35*playerScale)) * widgetScale then
         tipText = ResourceTransfer.TooltipText(energyPolicy)
     elseif mouseX >= widgetPosX + (m_share.posX + (37*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (53*playerScale)) * widgetScale then
@@ -3203,10 +3207,10 @@ end
 ---------------------------------------------------------------------------------------------------
 
 local function RenderShareSliderText(posY, player, resourceType, baseOffset)
-    local policyResult = ResourceTransfer.GetPlayerPolicy(player, resourceType, myTeamID)
+    local policyResult = Helpers.GetPlayerPolicy(player, resourceType, myTeamID)
     local case = ResourceTransfer.DecideCommunicationCase(policyResult)
     local label
-    if case == ResourceTransfer.CommunicationCase.OnTaxFree then
+    if case == ResourceTransfer.ResourceCommunicationCase.OnTaxFree then
         -- For tax-free sharing, just show the amount being shared
         label = ResourceTransfer.FormatNumberForUI(shareAmount)
     else
@@ -3234,9 +3238,9 @@ function CreateShareSlider()
 
     -- Refresh policy data for focused players before drawing
     if energyPlayer then
-        TeamTransfer.PackMetalPolicyResult(energyPlayer.team, myTeamID, energyPlayer)
+        Helpers.PackMetalPolicyResult(energyPlayer.team, myTeamID, energyPlayer)
     elseif metalPlayer then
-        TeamTransfer.PackEnergyPolicyResult(metalPlayer.team, myTeamID, metalPlayer)
+        Helpers.PackEnergyPolicyResult(metalPlayer.team, myTeamID, metalPlayer)
     end
 
     ShareSlider = gl_CreateList(function()
@@ -3395,6 +3399,7 @@ function widget:MousePress(x, y, button)
                                             --Spring_SendCommands("say a: " .. Spring.I18N('ui.playersList.chat.needSupport'))
 											Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needSupport')
                                         else
+                                            Spring.Echo("Calling ShareResources UNIT")
                                             Spring_ShareResources(clickedPlayer.team, "units")
                                             Spring.PlaySoundFile("beep4", 1, 'ui')
                                         end
@@ -3498,34 +3503,6 @@ function widget:MouseMove(x, y, dx, dy, button)
     end
 end
 
----@param receiverTeamId number
----@param resourceType ResourceType
-local function handleResourceTransfer(receiverTeamId, resourceType)
-    local targetPlayer = (resourceType == "metal" and metalPlayer) or energyPlayer
-    local policyResult, pascalResourceType = ResourceTransfer.GetPlayerPolicy(targetPlayer, resourceType, myTeamID)
-
-    local case = ResourceTransfer.DecideCommunicationCase(policyResult)
-
-    if case == ResourceTransfer.CommunicationCase.OnSelf then
-      if shareAmount > 0 then
-          Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount='..shareAmount)
-        else
-          Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
-        end
-    end
-
-    if shareAmount and shareAmount > 0 then
-        Spring_ShareResources(receiverTeamId, resourceType, shareAmount)
-        -- post-transfer messaging now handled by game_tax_resource_sharing.lua
-    end
-    
-    sliderOrigin = nil
-    sliderPosition = nil
-    shareAmount = 0
-    energyPlayer = nil
-    metalPlayer = nil
-end
-
 function widget:MouseRelease(x, y, button)
     if button == 1 then
         if firstclick ~= nil then
@@ -3536,13 +3513,19 @@ function widget:MouseRelease(x, y, button)
             release = nil
         end
 
-        if energyPlayer ~= nil and shareAmount then
-            handleResourceTransfer(energyPlayer.team, "energy")
-        end
+          if energyPlayer ~= nil and shareAmount then
+             Helpers.HandleResourceTransfer(energyPlayer, "energy", shareAmount, myTeamID)
+          end
 
-        if metalPlayer ~= nil and shareAmount then
-            handleResourceTransfer(metalPlayer.team, "metal")
-        end
+          if metalPlayer ~= nil and shareAmount then
+             Helpers.HandleResourceTransfer(metalPlayer, "metal", shareAmount, myTeamID)
+          end
+        
+        sliderOrigin = nil
+        sliderPosition = nil
+        shareAmount = 0
+        energyPlayer = nil
+        metalPlayer = nil
     end
 end
 
@@ -3842,8 +3825,12 @@ end
 function widget:Update(delta)
     --handles takes & related messages
     local mx, my = Spring.GetMouseState()
+    local wasHoveringPlayerlist = hoverPlayerlist
     hoverPlayerlist = false
-    if math_isInRect(mx, my, apiAbsPosition[2] - 1, apiAbsPosition[3] - 1, apiAbsPosition[4] + 1, apiAbsPosition[1] + 1 ) then
+
+    -- Determine if the mouse is over the full player list bounding box
+    local insidePlayerlist = math_isInRect(mx, my, apiAbsPosition[2], apiAbsPosition[3], apiAbsPosition[4], apiAbsPosition[1])
+    if insidePlayerlist then
         hoverPlayerlist = true
 
 		if leaderboardOffset then
@@ -3949,6 +3936,12 @@ function widget:Update(delta)
             CreateLists(curFrame==0, updateMainList2, updateMainList3)
         end
     end
+
+    -- Clear hover state when mouse leaves player list entirely (any side)
+    if wasHoveringPlayerlist and not hoverPlayerlist then
+        local selectedUnits = Spring.GetSelectedUnits()
+        ApiExtensions.HandleHoverChange(myTeamID, selectedUnits, nil, nil)
+    end
 end
 
 ---------------------------------------------------------------------------------------------------
diff --git a/luaui/Widgets/gui_selectedunits_gl4.lua b/luaui/Widgets/gui_selectedunits_gl4.lua
index 3e5ba75cb4..54bef59ce7 100644
--- a/luaui/Widgets/gui_selectedunits_gl4.lua
+++ b/luaui/Widgets/gui_selectedunits_gl4.lua
@@ -59,6 +59,9 @@ local selectedUnits = Spring.GetSelectedUnits()
 local unitTeam = {}
 local unitUnitDefID = {}
 
+local invalidUnits = {} -- units that are invalid for sharing with hovered player
+local hoverListenerRegistered = false
+
 local unitScale = {}
 local unitCanFly = {}
 local unitBuilding = {}
@@ -76,7 +79,6 @@ for unitDefID, unitDef in pairs(UnitDefs) do
 end
 local unitBufferUniformCache = {0}
 
-
 local function AddPrimitiveAtUnit(unitID)
 	if Spring.ValidUnitID(unitID) ~= true or Spring.GetUnitIsDead(unitID) == true or Spring.IsGUIHidden() then return end
 	local gf = Spring.GetGameFrame()
@@ -111,18 +113,19 @@ local function AddPrimitiveAtUnit(unitID)
 		width = radius
 		length = radius
 	end
+	local isInvalid = invalidUnits[unitID] ~= nil
 	if selectionHighlight then
-		unitBufferUniformCache[1] = 1
+		unitBufferUniformCache[1] = isInvalid and -1 or 1
 		gl.SetUnitBufferUniforms(unitID, unitBufferUniformCache, 6)
 	end
-	--Spring.Echo(unitID,radius,radius, Spring.GetUnitTeam(unitID), numvertices, 1, gf)
+	local invalidFlag = isInvalid and 1 or 0
 	pushElementInstance(
 		(unitCanFly[unitDefID] and selectionVBOAir) or selectionVBOGround, -- push into this Instance VBO Table
 		{
 			length, width, cornersize, additionalheight,  -- lengthwidthcornerheight
 			unitTeam[unitID], -- teamID
 			numVertices, -- how many trianges should we make
-			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
+			gf, invalidFlag, 0, 0, -- the gameFrame (for animations), and invalid flag
 			0, 1, 0, 1, -- These are our default UV atlas tranformations
 			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
 		},
@@ -133,7 +136,6 @@ local function AddPrimitiveAtUnit(unitID)
 	)
 end
 
-
 local function DrawSelections(selectionVBO, isAir)
 	if selectionVBO.usedElements > 0 then
 		if hasBadCulling then
@@ -204,6 +206,30 @@ local function RemovePrimitive(unitID)
 	end
 end
 
+local function OnHoverInvalidUnitsChanged(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
+	local newInvalidUnits = {}
+	for _, unitID in ipairs(invalidUnitIds) do
+		newInvalidUnits[unitID] = true
+	end
+
+	local oldInvalidUnits = invalidUnits
+	invalidUnits = newInvalidUnits
+
+	-- Only rebuild primitives for units whose invalid state actually changed (otherwise we get flickering)
+	for unitID, _ in pairs(selUnits) do
+		if Spring.ValidUnitID(unitID) then
+			local wasInvalid = oldInvalidUnits[unitID] ~= nil
+			local isInvalid = newInvalidUnits[unitID] ~= nil
+
+			-- Only update if the invalid state changed
+			if wasInvalid ~= isInvalid then
+				RemovePrimitive(unitID)
+				AddPrimitiveAtUnit(unitID)
+			end
+		end
+	end
+end
+
 function widget:SelectionChanged(sel)
 	updateSelection = true
 end
@@ -257,7 +283,6 @@ function widget:Update(dt)
 		updateSelection = false
 
 		local newSelUnits = {}
-		-- add to selection
 		for i, unitID in ipairs(selectedUnits) do
 			newSelUnits[unitID] = true
 			if not selUnits[unitID] then
@@ -273,6 +298,13 @@ function widget:Update(dt)
 		selUnits = newSelUnits
 	end
 
+	if not hoverListenerRegistered then
+		if WG['advplayerlist_api'] and WG['advplayerlist_api'].AddHoverInvalidUnitsListener then
+			WG['advplayerlist_api'].AddHoverInvalidUnitsListener(OnHoverInvalidUnitsChanged)
+			hoverListenerRegistered = true
+		end
+	end
+
 	-- We move the check for mouseovered units here,
 	-- as this widget is the ground truth for our unitbufferuniform[2].z (#6)
 	-- 0 means unit is un selected
@@ -291,7 +323,9 @@ function widget:Update(dt)
 				if lastMouseOverUnitID ~= unitID then
 					ClearLastMouseOver()
 					local newUniform = (selUnits[unitID] and 1 or 0 ) + 2
-					gl.SetUnitBufferUniforms(unitID, {newUniform}, 6)
+					-- Preserve the selection highlight value when setting mouseover
+					local currentHighlight = invalidUnits[unitID] and -1 or 1
+					gl.SetUnitBufferUniforms(unitID, {currentHighlight, newUniform}, 6)
 					lastMouseOverUnitID = unitID
 				end
 			elseif result == 'feature' and not Spring.IsGUIHidden() then
@@ -335,7 +369,7 @@ local function init()
 	shaderConfig.GROWTHRATE = 3.5
 	shaderConfig.TEAMCOLORIZATION = teamcolorOpacity	-- not implemented, doing it via POST_SHADING below instead
 	shaderConfig.HEIGHTOFFSET = 4
-	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(mix(g_color.rgb * texcolor.rgb + addRadius, vec3(1.0), "..(1-teamcolorOpacity)..") , texcolor.a * TRANSPARENCY + addRadius);"
+	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(g_invalid > 0.5 ? vec3(1.0, 0.0, 0.0) : (g_color.rgb * texcolor.rgb + addRadius), texcolor.a * TRANSPARENCY + addRadius);";
 	selectionVBOGround, selectShader = InitDrawPrimitiveAtUnit(shaderConfig, "selectedUnitsGround")
 	if mapHasWater then
 		selectionVBOAir = InitDrawPrimitiveAtUnit(shaderConfig, "selectedUnitsAir")
@@ -400,6 +434,10 @@ function widget:Shutdown()
 		Spring.LoadCmdColorsConfig('unitBox  0 1 0 1')
 	end
 	WG.selectedunits = nil
+
+	if hoverListenerRegistered and WG['advplayerlist_api'] and WG['advplayerlist_api'].RemoveHoverInvalidUnitsListener then
+		WG['advplayerlist_api'].RemoveHoverInvalidUnitsListener(OnHoverInvalidUnitsChanged)
+	end
 end
 
 function widget:GetConfigData(data)

commit 0e69c09656014e6005681fc08c6deb00809d12a9
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Mon Oct 20 20:01:59 2025 -0600

    feat: tax overflow
    
    It is a bit kludgey but it is isolated and works surprisingly well until we get engine hooks.
    
    Co-authored-by: Fx-Doo <hedibertille93@gmail.com>

diff --git a/luarules/gadgets/game_tax_resource_sharing.lua b/luarules/gadgets/game_tax_resource_sharing.lua
index b19ffe5a54..07fdee51d1 100644
--- a/luarules/gadgets/game_tax_resource_sharing.lua
+++ b/luarules/gadgets/game_tax_resource_sharing.lua
@@ -12,7 +12,7 @@ function gadget:GetInfo()
   }
 end
 
-local POLICY_CACHE_TAINT_FRAME_RATE = 30 -- every 1 second to keep up with overflow detection
+local POLICY_CACHE_TAINT_FRAME_RATE = 30 -- Rebuild policies every second to keep up with frequent cumulative sent changes
 
 ----------------------------------------------------------------
 -- Synced only
@@ -37,6 +37,12 @@ local policyResultFactory = ResourceTransfer.BuildResultFactory(sharingTax, meta
 
 local lastGameFrameCacheUpdate = 0
 
+-- Track engine-pipeline resource stats to detect overflow receives and engine-driven sends
+-- We record cumulative counters and take diffs per update window.
+local lastRecvStats = {}   -- [teamId] = { m = 0, e = 0 }
+local lastSentStats = {}   -- [teamId] = { m = 0, e = 0 }
+local manualRecvSinceLastOverflowCalc = {} -- [teamId] = { m = 0, e = 0 }
+
 ----------------------------------------------------------------
 -- Initialization
 ----------------------------------------------------------------
@@ -66,13 +72,22 @@ local function InitializeNewTeam(senderTeamId, receiverTeamId)
 end
 
 function gadget:Initialize()
-  local teamList = Spring.GetTeamList() or {}
+  local teamList = Spring.GetTeamList()
 
   for _, senderTeamId in ipairs(teamList) do
     for _, receiverTeamId in ipairs(teamList) do
       InitializeNewTeam(senderTeamId, receiverTeamId)
     end
   end
+
+  -- snapshot engine cumulative stats so first diff is zero
+  for _, teamId in ipairs(teamList) do
+    local _uM, _pM, _xM, recvM, sentM = Spring.GetTeamResourceStats(teamId, "m")
+    local _uE, _pE, _xE, recvE, sentE = Spring.GetTeamResourceStats(teamId, "e")
+    lastRecvStats[teamId] = { m = recvM, e = recvE }
+    lastSentStats[teamId] = { m = sentM, e = sentE }
+    manualRecvSinceLastOverflowCalc[teamId] = { m = 0, e = 0 }
+  end
   lastGameFrameCacheUpdate = Spring.GetGameFrame()
 end
 
@@ -91,26 +106,109 @@ function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType
 
   -- immediately rebuild the cache for this resource
   local policyCtx = contextFactory.policy(senderTeamId, receiverTeamId)
-  local frame = Spring.GetGameFrame()
   local updatedPolicyResult = BuildPolicyCache(policyCtx, resType)
   Comms.SendTransferChatMessages(transferResult, updatedPolicyResult)
 
+  -- Track manual receives to avoid canceling/taxing them in overflow step
+  if transferResult and transferResult.success and transferResult.received and transferResult.received > 0 then
+    local key = (resType == SharedEnums.ResourceType.METAL) and 'm' or 'e'
+    local bucket = manualRecvSinceLastOverflowCalc[receiverTeamId]
+    if not bucket then
+      bucket = { m = 0, e = 0 }
+      manualRecvSinceLastOverflowCalc[receiverTeamId] = bucket
+    end
+    bucket[key] = (bucket[key]) + transferResult.received
+  end
+
   return false
 end
 
 function gadget:GameFrame(frame)
-  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
-  if frame < nextSchedHeavy then
+  -- rebuild policy caches every 30 frames
+  -- exactly one frame after teamhandler calls team->SlowUpdate() where overflow happens (and teamres stats get updated)
+  if (frame % POLICY_CACHE_TAINT_FRAME_RATE) ~= 1 then
     return
   end
-  local teamList = Spring.GetTeamList() or {}
-  lastGameFrameCacheUpdate = frame
+
+  local teamList = Spring.GetTeamList()
+
+  -- tax overflows immediately when detected to prevent spending before taxation
+  -- it is still theoretically possible to spend before taxation, but it is very unlikely
+  if sharingTax and sharingTax > 0 then
+    for _, teamId in ipairs(teamList) do
+      local _uM, _pM, _xM, curRecvM, curSentM = Spring.GetTeamResourceStats(teamId, "m")
+      local _uE, _pE, _xE, curRecvE, curSentE = Spring.GetTeamResourceStats(teamId, "e")
+
+      local prevRecv = lastRecvStats[teamId]
+      local prevSent = lastSentStats[teamId]
+      if not prevRecv then
+        prevRecv = { m = 0, e = 0 }
+        lastRecvStats[teamId] = prevRecv
+      end
+      if not prevSent then
+        prevSent = { m = 0, e = 0 }
+        lastSentStats[teamId] = prevSent
+      end
+
+      local diffRecvM = math.max(0, curRecvM - prevRecv.m)
+      local diffRecvE = math.max(0, curRecvE - prevRecv.e)
+
+      local diffSentM = math.max(0, curSentM - prevSent.m)
+      local diffSentE = math.max(0, curSentE - prevSent.e)
+
+      -- Apply receiver-side tax only to overflow portion (engine received minus manual receives tracked)
+      local manual = manualRecvSinceLastOverflowCalc[teamId]
+      local overflowRecvM = math.max(0, diffRecvM - manual.m)
+      local overflowRecvE = math.max(0, diffRecvE - manual.e)
+
+      -- Tax overflow immediately when detected to prevent spending before taxation
+      if overflowRecvM > 0 then
+        local taxedM = overflowRecvM * sharingTax
+        if taxedM > 0 then
+          Spring.UseTeamResource(teamId, "metal", taxedM)
+        end
+      end
+      if overflowRecvE > 0 then
+        local taxedE = overflowRecvE * sharingTax
+        if taxedE > 0 then
+          Spring.UseTeamResource(teamId, "energy", taxedE)
+        end
+      end
+
+      -- Attribute engine-driven sends to our cumulative sender counters so thresholds include overflow sharing
+      -- Manual transfers bypass engine pipeline so they're counted in RegisterPostTransfer, overflow sends here
+      if diffSentM > 0 then
+        local cumulativeParam = Shared.GetCumulativeParam(SharedEnums.ResourceType.METAL)
+        local cumulativeVal = tonumber(Spring.GetTeamRulesParam(teamId, cumulativeParam))
+        Spring.SetTeamRulesParam(teamId, cumulativeParam, cumulativeVal + diffSentM)
+      end
+      if diffSentE > 0 then
+        local cumulativeParam = Shared.GetCumulativeParam(SharedEnums.ResourceType.ENERGY)
+        local cumulativeVal = tonumber(Spring.GetTeamRulesParam(teamId, cumulativeParam))
+        Spring.SetTeamRulesParam(teamId, cumulativeParam, cumulativeVal + diffSentE)
+      end
+
+      -- Update stats for next frame comparison
+      lastRecvStats[teamId].m = curRecvM
+      lastRecvStats[teamId].e = curRecvE
+      lastSentStats[teamId].m = curSentM
+      lastSentStats[teamId].e = curSentE
+    end
+  end
+
+  for _, teamId in ipairs(teamList) do
+    manualRecvSinceLastOverflowCalc[teamId] = { m = 0, e = 0 }
+  end
+
+  -- 2) Rebuild policy caches
+  local cacheRebuildCount = 0
   for _, senderTeamId in ipairs(teamList) do
     -- we also calculate me -> me for standardized resource request limits
     for _, receiverTeamId in ipairs(teamList) do
       local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
       for _, resourceType in ipairs(RESOURCE_TYPES) do
         BuildPolicyCache(ctx, resourceType)
+        cacheRebuildCount = cacheRebuildCount + 1
       end
     end
   end

commit 9dc64c8b6b7ba5f6ebccc1b322cab64547ac72f6
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Mon Oct 20 17:30:28 2025 -0600

    feat: resource sharing enabled
    
    I needed some way to turn sharing off completely and tax=1 didn't seem intuitive (or desirable since semantically following the logic of tax = 1 the sender would lose everything and the receiver would get nothing).

diff --git a/common/luaUtilities/team_transfer/resource_transfer_synced.lua b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
index e2478df768..ee5f96c361 100644
--- a/common/luaUtilities/team_transfer/resource_transfer_synced.lua
+++ b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
@@ -39,6 +39,11 @@ end
 ---@param resourceType ResourceType
 ---@return ResourcePolicyResult|nil
 local function tryRejectPolicy(ctx, resourceType)
+  -- Globally disable any form of resource sharing if the modoption is turned off
+  local modOpts = ctx.springRepo.GetModOptions and ctx.springRepo.GetModOptions()
+  if modOpts and modOpts.game_resource_sharing_enabled == false then
+    return rejectPolicy(ctx, resourceType)
+  end
   if ctx.isCheatingEnabled then
     return nil
   end
diff --git a/luarules/gadgets/game_unit_sharing_mode.lua b/luarules/gadgets/game_unit_sharing_mode.lua
index 2ab576a2d1..677fbb7f1b 100644
--- a/luarules/gadgets/game_unit_sharing_mode.lua
+++ b/luarules/gadgets/game_unit_sharing_mode.lua
@@ -4,7 +4,7 @@ function gadget:GetInfo()
   return {
     name    = 'Unit Sharing Mode',
     desc    = 'Controls which units can be shared with allies',
-    author  = 'Rimilel',
+    author  = 'Rimilel, Attean',
     date    = 'April 2024',
     license = 'GNU GPL, v2 or later',
     layer   = 0,
diff --git a/luaui/Widgets/gui_top_bar.lua b/luaui/Widgets/gui_top_bar.lua
index bf0b9f86cd..e0690c48fb 100644
--- a/luaui/Widgets/gui_top_bar.lua
+++ b/luaui/Widgets/gui_top_bar.lua
@@ -50,6 +50,7 @@ local numPlayers = Spring.Utilities.GetPlayerCount()
 local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()
 local chobbyLoaded = false
 local isSingle = false
+local resourceSharingEnabled = Spring.GetModOptions().game_resource_sharing_enabled
 local gameStarted = (Spring.GetGameFrame() > 0)
 local gameFrame = Spring.GetGameFrame()
 local gameIsOver = false
@@ -787,7 +788,7 @@ local function updateResbar(res)
 		end
 
 		-- Share slider
-		if not isSingle then
+		if not isSingle and resourceSharingEnabled then
 			if res == 'energy' then
 				energyOverflowLevel = r[res][6]
 			else
@@ -2071,7 +2072,7 @@ function widget:MousePress(x, y, button)
 		end
 
 		if not spec then
-			if not isSingle then
+			if not isSingle and resourceSharingEnabled then
 				if math_isInRect(x, y, shareIndicatorArea['metal'][1], shareIndicatorArea['metal'][2], shareIndicatorArea['metal'][3], shareIndicatorArea['metal'][4]) then
 					draggingShareIndicator = 'metal'
 				end
diff --git a/modoptions.lua b/modoptions.lua
index b58ba03ac7..858574a634 100644
--- a/modoptions.lua
+++ b/modoptions.lua
@@ -267,6 +267,15 @@ local options = {
 		type	= "subheader",
 		def		=  true,
 	},
+	{
+		key		= "game_resource_sharing_enabled",
+		name	= "Resource Sharing",
+		desc	= "Enable or disable all player-to-player resource sharing and overflow",
+		type	= "bool",
+		section	= "options_main",
+		def		= true,
+		column  = 1,
+	},
 	{
 		key		= "tax_resource_sharing_amount",
 		name	= "Resource Sharing Tax",

commit 20237f7e38595890a73657c6391acd5bd00f5aca
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Mon Oct 20 16:38:19 2025 -0600

    feat: game geo mex upgrades
    
    all credit to hobo on this one I just tied in my unit_sharing_mode
    
    Co-authored-by: thehobojoe <the.hobo.joe@gmail.com>

diff --git a/common/luaUtilities/team_transfer/unit_transfer_shared.lua b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
index fd2f76a4bb..783bcd729a 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_shared.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
@@ -126,7 +126,7 @@ function Shared.GetModeUnitTypes(mode)
   if mode == SharedEnums.UnitSharingMode.Disabled then
     return {}
   end
-
+  
   if mode == SharedEnums.UnitSharingMode.Enabled then
     return {
       SharedEnums.UnitType.Combat,
@@ -170,7 +170,6 @@ end
 local function EvaluateUnitForSharing(unitDef, mode)
   if not unitDef then return false end
 
-  -- Simple cases
   if mode == SharedEnums.UnitSharingMode.Disabled then
     return false
   end
@@ -179,31 +178,7 @@ local function EvaluateUnitForSharing(unitDef, mode)
     return true
   end
 
-  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
-
-  if mode == SharedEnums.UnitSharingMode.CombatUnits then
-    return unitType == SharedEnums.UnitType.Combat
-  end
-
-  if mode == SharedEnums.UnitSharingMode.Economic then
-    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor
-  end
-
-  if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
-    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor or
-    unitType == SharedEnums.UnitType.Utility
-  end
-
-  if mode == SharedEnums.UnitSharingMode.T2Cons then
-    return unitType == SharedEnums.UnitType.T2Constructor
-  end
-
-  if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
-    return unitType == SharedEnums.UnitType.Combat or unitType == SharedEnums.UnitType.T2Constructor
-  end
-
-  Spring.Log("unit_transfer_shared", LOG.ERROR, "EvaluateUnitForSharing: unknown mode =", mode)
-  return false
+  return UnitTypeMatchesMode(unitDef, mode)
 end
 
 -- Allowed UnitDefID cache per mode for fast validation
diff --git a/common/luaUtilities/team_transfer/unit_transfer_synced.lua b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
index 924631f468..a1eab656ef 100644
--- a/common/luaUtilities/team_transfer/unit_transfer_synced.lua
+++ b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
@@ -6,6 +6,7 @@ local Hack = VFS.Include("common/luaUtilities/team_transfer/take_hack.lua")
 
 local Synced = {
   ValidateUnits = Shared.ValidateUnits,
+  GetModeUnitTypes = Shared.GetModeUnitTypes,
 }
 
 ---Get per-pair policy (expose) and cache it for UI consumption
diff --git a/luarules/gadgets/game_disable_ally_geo_mex_upgrades.lua b/luarules/gadgets/game_disable_ally_geo_mex_upgrades.lua
new file mode 100644
index 0000000000..3824f5fb53
--- /dev/null
+++ b/luarules/gadgets/game_disable_ally_geo_mex_upgrades.lua
@@ -0,0 +1,90 @@
+local gadget = gadget ---@type Gadget
+
+function gadget:GetInfo()
+	return {
+		name    = 'Disable ally extractor upgrade',
+		desc    = 'Removes the ability for players to upgrade teammate mexes and geos in-place',
+		author  = 'Hobo Joe',
+		date    = 'August 2025',
+		license = 'GNU GPL, v2 or later',
+		layer   = 1,
+		enabled = true
+	}
+end
+
+----------------------------------------------------------------
+-- Decide whether to activate
+----------------------------------------------------------------
+if not gadgetHandler:IsSyncedCode() then
+	return false
+end
+
+local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+
+local mode = Spring.GetModOptions().unit_sharing_mode
+local modeUnitTypes = UnitTransfer.GetModeUnitTypes(mode)
+local enableShare = table.contains(modeUnitTypes, SharedEnums.UnitType.Utility)
+
+if enableShare then
+	return false
+end
+
+----------------------------------------------------------------
+-- Caching
+----------------------------------------------------------------
+local extractorRadius = Game.extractorRadius
+
+local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
+local spGetUnitDefID = Spring.GetUnitDefID
+local spGetUnitTeam = Spring.GetUnitTeam
+
+-- create a table of all mex and geo unitDefIDs
+local isMex = {}
+local isGeo = {}
+for unitDefID, unitDef in pairs(UnitDefs) do
+	if unitDef.extractsMetal > 0 then
+		isMex[unitDefID] = true
+	end
+	if unitDef.customParams.geothermal then
+		isGeo[unitDefID] = true
+	end
+end
+
+----------------------------------------------------------------
+-- Main behavior
+----------------------------------------------------------------
+
+local function mexBlocked(myTeam, x, y, z)
+	local units = spGetUnitsInCylinder(x, z, extractorRadius)
+	for _, unitID in ipairs(units) do
+		if isMex[spGetUnitDefID(unitID)] then
+			if spGetUnitTeam(unitID) ~= myTeam then
+				return true
+			end
+		end
+	end
+	return false
+end
+
+local function geoBlocked(myTeam, x, y, z)
+	local units = spGetUnitsInCylinder(x, z, extractorRadius)
+	for _, unitID in ipairs(units) do
+		if isGeo[spGetUnitDefID(unitID)] then
+			if spGetUnitTeam(unitID) ~= myTeam then
+				return true
+			end
+		end
+	end
+	return false
+end
+
+function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
+	-- Disallow upgrading allied mexes and allied geos
+	if isMex[unitDefID] then
+		return not mexBlocked(builderTeam, x, y, z)
+	elseif isGeo[unitDefID] then
+		return not geoBlocked(builderTeam, x, y, z)
+	end
+	return true
+end
diff --git a/luarules/gadgets/game_unit_sharing_mode.lua b/luarules/gadgets/game_unit_sharing_mode.lua
index 138f7be9a3..2ab576a2d1 100644
--- a/luarules/gadgets/game_unit_sharing_mode.lua
+++ b/luarules/gadgets/game_unit_sharing_mode.lua
@@ -4,10 +4,10 @@ function gadget:GetInfo()
   return {
     name    = 'Unit Sharing Mode',
     desc    = 'Controls which units can be shared with allies',
-    author  = 'Rimilel, Attean',
+    author  = 'Rimilel',
     date    = 'April 2024',
     license = 'GNU GPL, v2 or later',
-    layer   = 1,
+    layer   = 0,
     enabled = true
   }
 end

commit 553ec6bdacf1d2c520f9e3c30883c100679d0f57
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Mon Oct 20 13:24:23 2025 -0600

    feat: game allied reclaim mod option
    
    Ported out of taxes to make it explicit.

diff --git a/luarules/gadgets/game_allied_reclaim.lua b/luarules/gadgets/game_allied_reclaim.lua
new file mode 100644
index 0000000000..9ac9003110
--- /dev/null
+++ b/luarules/gadgets/game_allied_reclaim.lua
@@ -0,0 +1,67 @@
+local gadget = gadget ---@type Gadget
+
+function gadget:GetInfo()
+  return {
+    name    = 'Allied Reclaim Control',
+    desc    = 'Controls reclaiming allied units based on modoption',
+    author  = 'Rimilel',
+    date    = 'October 2025',
+    license = 'GNU GPL, v2 or later',
+    layer   = 1,
+    enabled = true
+  }
+end
+
+----------------------------------------------------------------
+-- Synced only
+----------------------------------------------------------------
+if not gadgetHandler:IsSyncedCode() then
+  return false
+end
+
+local alliedReclaimEnabled = Spring.GetModOptions() and Spring.GetModOptions().game_allied_reclaim == "enabled"
+if alliedReclaimEnabled then
+  return
+end
+
+function gadget:Initialize()
+  gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
+  gadgetHandler:RegisterAllowCommand(CMD.GUARD)
+end
+
+function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
+  -- Disallow reclaiming allied units for metal
+  if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
+    local targetID = cmdParams[1]
+    local targetTeam
+
+    if (targetID >= Game.maxUnits) then
+      return true
+    end
+
+    targetTeam = Spring.GetUnitTeam(targetID)
+    if targetTeam == nil then
+      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
+    end
+
+    if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
+      return false
+    end
+  elseif (cmdID == CMD.GUARD) then -- Also block guarding allied units that can reclaim
+    local targetID = cmdParams[1]
+    local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
+
+    local targetTeam = Spring.GetUnitTeam(targetID)
+    if targetTeam == nil then
+      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
+    end
+
+    if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
+      -- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
+      if targetUnitDef.canReclaim then
+        return false
+      end
+    end
+  end
+  return true
+end
diff --git a/luarules/gadgets/game_tax_resource_sharing.lua b/luarules/gadgets/game_tax_resource_sharing.lua
index d369f3b1cf..b19ffe5a54 100644
--- a/luarules/gadgets/game_tax_resource_sharing.lua
+++ b/luarules/gadgets/game_tax_resource_sharing.lua
@@ -127,38 +127,3 @@ function gadget:PlayerAdded(playerID)
   end
 end
 
-function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
-  -- Disallow reclaiming allied units for metal
-  if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
-    local targetID = cmdParams[1]
-    local targetTeam
-    if (targetID >= Game.maxUnits) then
-      return true
-    end
-
-    targetTeam = Spring.GetUnitTeam(targetID)
-    if targetTeam == nil then
-      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
-    end
-
-    if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
-      return false
-    end
-  elseif (cmdID == CMD.GUARD) then -- Also block guarding allied units that can reclaim
-    local targetID = cmdParams[1]
-    local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
-
-    local targetTeam = Spring.GetUnitTeam(targetID)
-    if targetTeam == nil then
-      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
-    end
-
-    if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
-      -- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
-      if targetUnitDef.canReclaim then
-        return false
-      end
-    end
-  end
-  return true
-end
diff --git a/modoptions.lua b/modoptions.lua
index e8f57b0bd4..b58ba03ac7 100644
--- a/modoptions.lua
+++ b/modoptions.lua
@@ -306,6 +306,18 @@ local options = {
 		column  = 2,
 		disabled= { key="tax_resource_sharing_amount", value = 0},
 	},
+	{
+		key		= "game_allied_reclaim",
+		name	= "Allied Reclaim",
+		desc	= "Controls reclaiming allied units and guarding allied units that can reclaim",
+		type	= "list",
+		section	= "options_main",
+		def		= "enabled",
+		items	= {
+			{ key = "enabled", name = "Enabled", desc = "Allied reclaim is disabled" },
+			{ key = "disabled", name = "Disabled", desc = "Allied reclaim is allowed" },
+		},
+	},
 	{
 		key		= "unit_sharing_mode",
 		name	= "Unit Sharing Mode",

commit cb5bd6b73165ad2d529bcdc1d9a92ebdc72f9eeb
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Sun Oct 19 13:48:14 2025 -0600

    feat(Sharing): unit_sharing_mode
    
    Refactor unit sharing mode into the policy cache/policyResult format and simplify gui_advplayerslist.
    
    ded line units

diff --git a/common/luaUtilities/team_transfer/context_factory.lua b/common/luaUtilities/team_transfer/context_factory.lua
index 2ea8b16d4e..4142262828 100644
--- a/common/luaUtilities/team_transfer/context_factory.lua
+++ b/common/luaUtilities/team_transfer/context_factory.lua
@@ -5,7 +5,7 @@ local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.
 ---@field policy fun(senderTeamID: number, receiverTeamID: number): PolicyContext
 ---@field action fun(senderTeamId: number, receiverTeamId: number, transferCategory: string): PolicyActionContext
 ---@field resourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: ResourceType, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
----@field unitTransfer fun(senderTeamId: number, receiverTeamId: number, unitIds: number[], given: boolean, policyResult: UnitTransferPolicyResult): UnitTransferContext
+---@field unitTransfer fun(senderTeamId: number, receiverTeamId: number, unitIds: number[], given: boolean, policyResult: UnitPolicyResult, unitValidationResult: UnitValidationResult): UnitTransferContext
 local ContextFactory = {}
 
 ---@param springRepo ISpring
@@ -115,9 +115,29 @@ function ContextFactory.create(springRepo)
     })
   end
 
+  ---Create unit transfer context for transfer actions
+  ---@param senderTeamId number
+  ---@param receiverTeamId number
+  ---@param unitIds number[]
+  ---@param given boolean?
+  ---@param policyResult UnitPolicyResult\
+  ---@param validationResult UnitValidationResult
+  ---@return UnitTransferContext
+  local function unitTransfer(senderTeamId, receiverTeamId, unitIds, given, policyResult, validationResult)
+    return buildContext(senderTeamId, receiverTeamId, {
+        transferCategory = SharedEnums.TransferCategory.UnitTransfer,
+        unitIds = unitIds,
+        given = given,
+        policyResult = policyResult,
+        validationResult = validationResult
+    })
+  end
+
   return {
     policy = policy,
     action = policyAction,
+    resourceTransfer = resourceTransfer,
+    unitTransfer = unitTransfer,
   }
 end
 
diff --git a/common/luaUtilities/team_transfer/modoption_enums.lua b/common/luaUtilities/team_transfer/modoption_enums.lua
index a5fd69839c..4976ccc096 100644
--- a/common/luaUtilities/team_transfer/modoption_enums.lua
+++ b/common/luaUtilities/team_transfer/modoption_enums.lua
@@ -4,6 +4,8 @@ local M = {}
 M.Options = {
 	TaxResourceSharingAmount = "tax_resource_sharing_amount",
 	PlayerMetalSendThreshold = "player_metal_send_threshold",
+	PlayerEnergySendThreshold = "player_energy_send_threshold",
+	UnitSharingMode = "unit_sharing_mode",
 }
 
 return M
diff --git a/common/luaUtilities/team_transfer/shared_enums.lua b/common/luaUtilities/team_transfer/shared_enums.lua
index 9930c4ec1e..b6a67b0364 100644
--- a/common/luaUtilities/team_transfer/shared_enums.lua
+++ b/common/luaUtilities/team_transfer/shared_enums.lua
@@ -4,6 +4,7 @@ M.__index = M
 M.TransferCategory = {
 	MetalTransfer = "metal_transfer",
 	EnergyTransfer = "energy_transfer",
+	UnitTransfer = "unit_transfer"
 }
 
 M.ResourceType = {
@@ -20,4 +21,35 @@ M.ResourceCommunicationCase = {
 	OnTaxed = 4,
 }
 
+M.UnitCommunicationCase = {
+	OnSelf = 1,
+	OnFullyShareable = 2,
+	OnPartiallyShareable = 3,
+	OnPolicyDisabled = 4,
+	OnSelectionValidationFailed = 5,
+}
+
+M.UnitValidationOutcome = {
+	Success = "Success",
+	Failure = "Failure",
+	PartialSuccess = "PartialSuccess",
+}
+
+M.UnitSharingMode = {
+	Disabled = "disabled",
+	Enabled = "enabled",
+	CombatUnits = "combat",
+	Economic = "economic",
+	EconomicPlusBuildings = "economic_plus_buildings",
+	T2Cons = "t2_cons",
+	CombatT2Cons = "combat_t2_cons",
+}
+
+M.UnitType = {
+	Combat = "combat",
+	Economic = "economic",
+	Utility = "utility",
+	T2Constructor = "t2_constructor",
+}
+
 return M
diff --git a/common/luaUtilities/team_transfer/take_hack.lua b/common/luaUtilities/team_transfer/take_hack.lua
new file mode 100644
index 0000000000..83e3b32aed
--- /dev/null
+++ b/common/luaUtilities/team_transfer/take_hack.lua
@@ -0,0 +1,23 @@
+local Hack = {}
+
+-- TODO: remove this function when we refactor /take out of the engine and into the game lua
+function Hack.CheckTakeCondition(senderTeamID, receiverTeamID)
+  -- Check if sender is allied
+  if Spring.AreTeamsAllied(senderTeamID, receiverTeamID) then
+    -- Loop to see if sender has any active human players
+    local playerList = Spring.GetPlayerList() or {}
+    for _, playerID in ipairs(playerList) do
+      local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID)
+      if active and not spectator and teamID == senderTeamID then
+        -- Found an active player, so this is NOT the /take condition.
+        return false
+      end
+    end
+    -- If loop finished without finding an active player, it matches the /take condition.
+    -- Allow the transfer, bypassing sharing rules.
+    return true
+  end
+  return false
+end
+
+return Hack
\ No newline at end of file
diff --git a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
index e26564dc24..5d8c050ab1 100644
--- a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
+++ b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
@@ -4,37 +4,65 @@ local TeamTransferCache = VFS.Include("common/luaUtilities/team_transfer/team_tr
 local ResourceComms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
 local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
 
+local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
+local UnitComms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")
+
 local metalPolicyScratch = {}
 local energyPolicyScratch = {}
+local unitPolicyScratch = {}
+local selectedUnitsValidationScratch = {}
 
 local METAL_POLICY_PREFIX = "metalPolicy_"
 local ENERGY_POLICY_PREFIX = "energyPolicy_"
+local UNIT_POLICY_PREFIX = "unitPolicy_"
+local SELECTED_UNITS_VALIDATION_PREFIX = "selectedUnitsValidation_"
+local SELECTED_UNITS_VALIDATION_FIELDS = {
+  "status",
+  "validUnitCount",
+  "validUnitIds",
+  "invalidUnitCount",
+  "invalidUnitIds",
+  "validUnitNames",
+  "invalidUnitNames"
+}
 
 local ResourceWidgets = {
   CalculateSenderTaxedAmount = ResourceShared.CalculateSenderTaxedAmount,
+  FormatNumberForUI = ResourceComms.FormatNumberForUI,
   CommunicationCase = SharedEnums.ResourceCommunicationCase,
-  DecideCommunicationCase = ResourceShared.DecideCommunicationCase,
   GetCachedPolicyResult = ResourceShared.GetCachedPolicyResult,
   ResourceTypes = SharedEnums.ResourceTypes,
+  DecideCommunicationCase = ResourceComms.DecideCommunicationCase,
   TooltipText = ResourceComms.TooltipText,
   SendTransferChatMessages = ResourceComms.SendTransferChatMessages,
 }
 ResourceWidgets.__index = ResourceWidgets
 
+local UnitWidgets = {
+  GetCachedPolicyResult = UnitShared.GetCachedPolicyResult,
+  ValidateUnits = UnitShared.ValidateUnits,
+  DecideCommunicationCase = UnitComms.DecideCommunicationCase,
+  TooltipText = UnitComms.UnitShareTooltip,
+}
+UnitWidgets.__index = UnitWidgets
+
+local TeamTransfer = {
+  Resources = ResourceWidgets,
+  Units = UnitWidgets,
+}
+
 --------------------------------------------------------
 --- Resource Transfer
 --------------------------------------------------------
 
---- Get policy result and pascal resource type for a player
 ---@param player table
 ---@param resourceType string
 ---@param senderTeamId number
----@return ResourcePolicyResult policyResult, string pascalResourceType
+---@return ResourcePolicyResult policyResult
 function ResourceWidgets.GetPlayerPolicy(player, resourceType, senderTeamId)
-  local pascalResourceType = resourceType:gsub("^%l", string.upper)
-  local prefix = resourceType == "metal" and METAL_POLICY_PREFIX or ENERGY_POLICY_PREFIX
-  local policyResult = ResourceWidgets.UnpackPolicyResult(player, prefix, senderTeamId, player.team)
-  return policyResult, pascalResourceType
+  local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
+  local policyResult = TeamTransfer.UnpackPolicyResult(transferCategory, player, senderTeamId, player.team)
+  return policyResult
 end
 
 --- Handle resource transfer logic
@@ -53,10 +81,10 @@ function ResourceWidgets.HandleResourceTransfer(targetPlayer, resourceType, shar
     else
       Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
     end
-  end
-
-  if shareAmount and shareAmount > 0 then
-    Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
+  else
+    if shareAmount and shareAmount > 0 then
+      Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
+    end
   end
 end
 
@@ -67,17 +95,44 @@ end
 ---@param playerData table
 ---@param senderTeamId number
 ---@param receiverTeamId number
----@return ResourcePolicyResult? metalPolicy, ResourcePolicyResult? energyPolicy, UnitTransferPolicyResult? unitPolicy
+---@return ResourcePolicyResult? metalPolicy, ResourcePolicyResult? energyPolicy, UnitPolicyResult? unitPolicy
 function TeamTransfer.UnpackAllPolicies(playerData, senderTeamId, receiverTeamId)
   local hasPackedData = playerData[METAL_POLICY_PREFIX .. "canShare"] ~= nil
   if not hasPackedData then return nil, nil, nil end
 
   local metalPolicy = TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
   local energyPolicy = TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
+  local unitPolicy = TeamTransfer.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
 
-  return metalPolicy, energyPolicy
+  return metalPolicy, energyPolicy, unitPolicy
 end
 
+---Unpack selected units validation result from player data
+---@param playerData table
+---@return UnitValidationResult
+function TeamTransfer.UnpackSelectedUnitsValidation(playerData)
+  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
+    selectedUnitsValidationScratch[field] = playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field]
+  end
+  return selectedUnitsValidationScratch
+end
+
+---Pack selected units validation result into player data
+---@param validationResult table
+---@param playerData table
+function TeamTransfer.PackSelectedUnitsValidation(validationResult, playerData)
+  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
+    playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field] = validationResult[field]
+  end
+end
+
+---Clear selected units validation result from player data
+---@param playerData table
+function TeamTransfer.ClearSelectedUnitsValidation(playerData)
+  for _, field in ipairs(SELECTED_UNITS_VALIDATION_FIELDS) do
+    playerData[SELECTED_UNITS_VALIDATION_PREFIX .. field] = nil
+  end
+end
 
 ---This and its sibling hydrate existing tables with a policyResult so we don't thrash GC
 ---@param transferCategory string SharedEnums.TransferCategory
@@ -94,6 +149,10 @@ function TeamTransfer.UnpackPolicyResult(transferCategory, playerData, senderTea
     scratch = energyPolicyScratch
     fields = ResourceShared.ResourcePolicyFields
     prefix = ENERGY_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
+    scratch = unitPolicyScratch
+    fields = UnitShared.UnitPolicyFields
+    prefix = UNIT_POLICY_PREFIX
   end
   scratch.senderTeamId = senderTeamId
   scratch.receiverTeamId = receiverTeamId
@@ -108,7 +167,7 @@ end
 ---@param senderTeamId number
 ---@param receiverTeamId number
 ---@return ResourcePolicyResult
-function ResourceWidgets.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
+function TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
   return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, senderTeamId,
     receiverTeamId)
 end
@@ -118,7 +177,7 @@ end
 ---@param senderTeamId number
 ---@param receiverTeamId number
 ---@return ResourcePolicyResult
-function ResourceWidgets.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
+function TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
   return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, senderTeamId,
     receiverTeamId)
 end
@@ -127,8 +186,8 @@ end
 ---@param playerData table
 ---@param senderTeamId number
 ---@param receiverTeamId number
----@return UnitTransferPolicyResult
-function UnitWidgets.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
+---@return UnitPolicyResult
+function TeamTransfer.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
   return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
     receiverTeamId)
 end
@@ -145,6 +204,11 @@ function TeamTransfer.PackPolicyResult(transferCategory, policy, playerData)
   elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
     fields = ResourceShared.ResourcePolicyFields
     prefix = ENERGY_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
+    fields = UnitShared.UnitPolicyFields
+    prefix = UNIT_POLICY_PREFIX
+  else
+    error("Invalid transfer category: " .. transferCategory)
   end
   for field, _ in pairs(fields) do
     playerData[prefix .. field] = policy[field]
@@ -169,6 +233,15 @@ function TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playe
   TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policy, playerData)
 end
 
+---Pack unit policy result into player data
+---@param senderTeamId number
+---@param receiverTeamId number
+---@param playerData table
+function TeamTransfer.PackUnitPolicyResult(senderTeamId, receiverTeamId, playerData)
+  local policy = UnitWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId)
+  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, policy, playerData)
+end
+
 --- Pack all policies for a given player
 ---@param playerData table
 ---@param senderTeamId number
@@ -176,6 +249,7 @@ end
 function TeamTransfer.PackAllPoliciesForPlayer(playerData, senderTeamId, receiverTeamId)
   TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
   TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
+  TeamTransfer.PackUnitPolicyResult(senderTeamId, receiverTeamId, playerData)
 end
 
 return TeamTransfer
diff --git a/common/luaUtilities/team_transfer/unit_sharing_categories.lua b/common/luaUtilities/team_transfer/unit_sharing_categories.lua
new file mode 100644
index 0000000000..87d33d8d69
--- /dev/null
+++ b/common/luaUtilities/team_transfer/unit_sharing_categories.lua
@@ -0,0 +1,96 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+
+local sharing = {}
+
+---Classify a unit definition by type
+---Each unit def resolves to exactly 1 category
+---@param unitDef table Unit definition from UnitDefs
+---@return string unitType One of SharedEnums.UnitType values
+function sharing.classifyUnitDef(unitDef)
+	-- Economic units include T2 constructors, so check economic first
+	if sharing.isEconomicUnitDef(unitDef) then
+		-- T2 constructors are a special subset of economic units
+		if sharing.isT2ConstructorDef(unitDef) then
+			return SharedEnums.UnitType.T2Constructor
+		end
+		return SharedEnums.UnitType.Economic
+	end
+
+	if sharing.isUtilityUnitDef(unitDef) then
+		return SharedEnums.UnitType.Utility
+	end
+
+	if sharing.isCombatUnitDef(unitDef) then
+		return SharedEnums.UnitType.Combat
+	end
+
+	-- Default to combat for unclassified units
+	return SharedEnums.UnitType.Combat
+end
+
+---Check if a unit definition is a T2 constructor
+---@param unitDef table Unit definition from UnitDefs
+---@return boolean isT2Con True if the unit is a T2 constructor
+function sharing.isT2ConstructorDef(unitDef)
+	return not unitDef.isFactory
+			and #(unitDef.buildOptions or {}) > 0
+			and unitDef.customParams.techlevel == "2"
+end
+
+---Check if a unit definition is combat-oriented (weapons, defense, offense)
+---@param unitDef table Unit definition from UnitDefs
+---@return boolean isCombat True if the unit is combat-focused
+function sharing.isCombatUnitDef(unitDef)
+	if unitDef.customParams and (
+				unitDef.customParams.unitgroup == "weapon" or
+				unitDef.customParams.unitgroup == "aa" or
+				unitDef.customParams.unitgroup == "sub" or
+				unitDef.customParams.unitgroup == "weaponaa" or
+				unitDef.customParams.unitgroup == "weaponsub" or
+				unitDef.customParams.unitgroup == "emp" or
+				unitDef.customParams.unitgroup == "nuke" or
+				unitDef.customParams.unitgroup == "antinuke" or
+				unitDef.customParams.unitgroup == "explo"
+			) then
+		return true
+	end
+
+	if unitDef.weapons and #unitDef.weapons > 0 then
+		return true
+	end
+
+	return false
+end
+
+-- Economic units: builders, factories, assist units (construction-focused)
+---@param unitDef table Unit definition from UnitDefs
+---@return boolean isEconomic True if the unit is for construction/building
+function sharing.isEconomicUnitDef(unitDef)
+	if unitDef.canAssist or unitDef.isFactory or unitDef.builder then
+		return true
+	end
+
+	return false
+end
+
+---Check if a unit definition is a utility building (resource generation, storage, etc.)
+---@param unitDef table Unit definition from UnitDefs
+---@return boolean isUtility True if the unit is a utility building
+function sharing.isUtilityUnitDef(unitDef)
+	-- Resource generation units: energy and metal producers/extractors
+	if unitDef.customParams and (
+				unitDef.customParams.unitgroup == SharedEnums.ResourceType.ENERGY or
+				unitDef.customParams.unitgroup == SharedEnums.ResourceType.METAL
+			) then
+		return true
+	end
+
+	-- Utility buildings that support economy (not combat)
+	if unitDef.customParams and unitDef.customParams.unitgroup == "util" then
+		return true
+	end
+
+	return false
+end
+
+return sharing
diff --git a/common/luaUtilities/team_transfer/unit_transfer_comms.lua b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
new file mode 100644
index 0000000000..68839f531b
--- /dev/null
+++ b/common/luaUtilities/team_transfer/unit_transfer_comms.lua
@@ -0,0 +1,73 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+
+local Comms = {}
+Comms.__index = Comms
+
+---Decide communication case for unit sharing based on policy and optional validation results
+---@param policy UnitPolicyResult
+---@param validationResult UnitValidationResult?
+---@return number SharedEnums.UnitCommunicationCase
+function Comms.DecideCommunicationCase(policy, validationResult)
+  if policy.senderTeamId == policy.receiverTeamId then
+    return SharedEnums.UnitCommunicationCase.OnSelf
+  elseif not policy.canShare then
+    return SharedEnums.UnitCommunicationCase.OnPolicyDisabled
+  elseif validationResult then
+    if validationResult.status == SharedEnums.UnitValidationOutcome.PartialSuccess then
+      return SharedEnums.UnitCommunicationCase.OnPartiallyShareable
+    elseif validationResult.status == SharedEnums.UnitValidationOutcome.Success then
+      return SharedEnums.UnitCommunicationCase.OnFullyShareable
+    else
+      return SharedEnums.UnitCommunicationCase.OnSelectionValidationFailed
+    end
+  else
+    return SharedEnums.UnitCommunicationCase.OnFullyShareable
+  end
+end
+
+---@param policy UnitPolicyResult
+---@param validationResult UnitValidationResult?
+function Comms.TooltipText(policy, validationResult)
+  local baseKey = 'ui.playersList'
+  local case = Comms.DecideCommunicationCase(policy, validationResult)
+  if case == SharedEnums.UnitCommunicationCase.OnSelf then
+    return Spring.I18N(baseKey .. '.requestSupport')
+  elseif case == SharedEnums.UnitCommunicationCase.OnPolicyDisabled then
+    local i18nData = {
+      unitSharingMode = policy.sharingMode,
+    }
+    return Spring.I18N(baseKey .. '.shareUnitsDisabled', i18nData)
+  elseif case == SharedEnums.UnitCommunicationCase.OnSelectionValidationFailed then
+    return Spring.I18N(baseKey .. '.shareUnitsInvalid.all')
+  elseif case == SharedEnums.UnitCommunicationCase.OnPartiallyShareable then
+    if not validationResult then error("This should not be possible.") end
+
+    local invalidNames = validationResult.invalidUnitNames
+    local i18nData = {
+      unitSharingMode = policy.sharingMode,
+      firstInvalidUnitName = invalidNames[1] or "",
+      secondInvalidUnitName = invalidNames[2] or "",
+      count = #invalidNames - 2,
+    }
+    if #invalidNames == 1 then
+      return Spring.I18N(baseKey .. '.shareUnitsInvalid.one', i18nData)
+    elseif #invalidNames == 2 then
+      return Spring.I18N(baseKey .. '.shareUnitsInvalid.two', i18nData)
+    else
+      return Spring.I18N(baseKey .. '.shareUnitsInvalid.other', i18nData)
+    end
+  elseif case == SharedEnums.UnitCommunicationCase.OnFullyShareable then
+    if validationResult then
+      local i18nData = {
+        validUnitCount = validationResult.validUnitCount,
+      }
+      return Spring.I18N(baseKey .. '.shareUnits', i18nData)
+    else
+      return Spring.I18N(baseKey .. '.shareUnits')
+    end
+  else
+    error('Invalid unit communication case: ' .. case)
+  end
+end
+
+return Comms
diff --git a/common/luaUtilities/team_transfer/unit_transfer_shared.lua b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
new file mode 100644
index 0000000000..fd2f76a4bb
--- /dev/null
+++ b/common/luaUtilities/team_transfer/unit_transfer_shared.lua
@@ -0,0 +1,229 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
+local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
+
+local Shared = {}
+
+local FieldTypes = PolicyShared.FieldTypes
+Shared.UnitPolicyFields = {
+  canShare = FieldTypes.boolean,
+  sharingMode = FieldTypes.string,
+  allowTakeBypass = FieldTypes.boolean,
+}
+
+
+---Validate a list of unitIds under current mode
+---Returns a structured result object designed for UI consumption.
+---We don't make decisions here on how to display unit names etc, we just collate the data and let the UI decide.
+---@param policyResult UnitPolicyResult -- note that policyResult is useless right now but is passed in for future use
+---@param unitIds number[]
+---@return UnitValidationResult
+function Shared.ValidateUnits(policyResult, unitIds)
+  local out = {
+    status = SharedEnums.UnitValidationOutcome.Failure,
+    validUnitCount = 0,
+    validUnitNames = {},
+    validUnitIds = {},
+    invalidUnitCount = 0,
+    invalidUnitNames = {},
+    invalidUnitIds = {},
+  }
+
+  if (not policyResult.canShare) or (not unitIds or #unitIds == 0) then
+    return out
+  end
+
+  local mode = policyResult.sharingMode
+  local validUnitNamesSet = {}
+  local invalidUnitNamesSet = {}
+  for _, unitId in ipairs(unitIds) do
+    local unitDefID = Spring.GetUnitDefID(unitId)
+    if not unitDefID then
+      Spring.Log("unit_transfer_shared", LOG.ERROR, "ValidateUnits: unitId", unitId, "not found")
+      out.invalidUnitCount = out.invalidUnitCount + 1
+      table.insert(out.invalidUnitIds, unitId)
+      table.insert(out.invalidUnitNames, "Unknown Unit")
+      return out
+    else
+      local ok = Shared.IsShareableDef(unitDefID, mode)
+      local unitName = UnitDefs[unitDefID] and (UnitDefs[unitDefID].translatedHumanName or UnitDefs[unitDefID].name)
+
+      if ok then
+        out.validUnitCount = out.validUnitCount + 1
+        table.insert(out.validUnitIds, unitId)
+        if not validUnitNamesSet[unitName] then
+          validUnitNamesSet[unitName] = true
+          table.insert(out.validUnitNames, unitName)
+        end
+      else
+        out.invalidUnitCount = out.invalidUnitCount + 1
+        table.insert(out.invalidUnitIds, unitId)
+        if not invalidUnitNamesSet[unitName] then
+          invalidUnitNamesSet[unitName] = true
+          table.insert(out.invalidUnitNames, unitName)
+        end
+      end
+    end
+  end
+
+  if out.validUnitCount > 0 and out.invalidUnitCount == 0 then
+    out.status = SharedEnums.UnitValidationOutcome.Success
+  elseif out.validUnitCount > 0 and out.invalidUnitCount > 0 then
+    out.status = SharedEnums.UnitValidationOutcome.PartialSuccess
+  else
+    out.status = SharedEnums.UnitValidationOutcome.Failure
+  end
+
+  return out
+end
+
+---UI getter for per-pair policy expose from cache
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return UnitPolicyResult
+function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId)
+  local baseKey = PolicyShared.MakeBaseKey(receiverTeamId, SharedEnums.TransferCategory.UnitTransfer)
+  local serialized = Spring.GetTeamRulesParam(senderTeamId, baseKey)
+  if serialized == nil then
+    -- default to deny
+    ---@type UnitPolicyResult
+    return {
+      senderTeamId = senderTeamId,
+      receiverTeamId = receiverTeamId,
+      canShare = false,
+      sharingMode = SharedEnums.UnitSharingMode.Disabled,
+      allowTakeBypass = false
+    }
+  end
+
+  if type(serialized) ~= "string" then
+    serialized = tostring(serialized)
+  end
+
+  return Shared.DeserializePolicy(serialized, senderTeamId, receiverTeamId)
+end
+
+---Serialize unit policy expose to compact string
+---@param policy table
+---@return string
+function Shared.SerializePolicy(policy)
+  return PolicyShared.Serialize(Shared.UnitPolicyFields, policy)
+end
+
+---Deserialize unit policy expose from string
+---@param serialized string
+---@param senderId number
+---@param receiverId number
+---@return UnitPolicyResult
+function Shared.DeserializePolicy(serialized, senderId, receiverId)
+  return PolicyShared.Deserialize(Shared.UnitPolicyFields, serialized, {
+    senderTeamId = senderId,
+    receiverTeamId = receiverId,
+  })
+end
+
+function Shared.GetModeUnitTypes(mode)
+  if mode == SharedEnums.UnitSharingMode.Disabled then
+    return {}
+  end
+
+  if mode == SharedEnums.UnitSharingMode.Enabled then
+    return {
+      SharedEnums.UnitType.Combat,
+      SharedEnums.UnitType.Economic,
+      SharedEnums.UnitType.Utility,
+      SharedEnums.UnitType.T2Constructor
+    }
+  end
+
+  if mode == SharedEnums.UnitSharingMode.CombatUnits then
+    return {SharedEnums.UnitType.Combat}
+  end
+
+  if mode == SharedEnums.UnitSharingMode.Economic then
+    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor}
+  end
+
+  if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
+    return {SharedEnums.UnitType.Economic, SharedEnums.UnitType.T2Constructor, SharedEnums.UnitType.Utility}
+  end
+
+  if mode == SharedEnums.UnitSharingMode.T2Cons then
+    return {SharedEnums.UnitType.T2Constructor}
+  end
+
+  if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
+    return {SharedEnums.UnitType.Combat, SharedEnums.UnitType.T2Constructor}
+  end
+end
+
+local function UnitTypeMatchesMode(unitDef, mode)
+  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
+  local modeUnitTypes = Shared.GetModeUnitTypes(mode)
+  return table.contains(modeUnitTypes, unitType)
+end
+
+---Get globals published by the module
+---@param unitDef table
+---@param mode string
+---@return boolean
+local function EvaluateUnitForSharing(unitDef, mode)
+  if not unitDef then return false end
+
+  -- Simple cases
+  if mode == SharedEnums.UnitSharingMode.Disabled then
+    return false
+  end
+
+  if mode == SharedEnums.UnitSharingMode.Enabled then
+    return true
+  end
+
+  local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
+
+  if mode == SharedEnums.UnitSharingMode.CombatUnits then
+    return unitType == SharedEnums.UnitType.Combat
+  end
+
+  if mode == SharedEnums.UnitSharingMode.Economic then
+    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor
+  end
+
+  if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
+    return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor or
+    unitType == SharedEnums.UnitType.Utility
+  end
+
+  if mode == SharedEnums.UnitSharingMode.T2Cons then
+    return unitType == SharedEnums.UnitType.T2Constructor
+  end
+
+  if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
+    return unitType == SharedEnums.UnitType.Combat or unitType == SharedEnums.UnitType.T2Constructor
+  end
+
+  Spring.Log("unit_transfer_shared", LOG.ERROR, "EvaluateUnitForSharing: unknown mode =", mode)
+  return false
+end
+
+-- Allowed UnitDefID cache per mode for fast validation
+local allowedByMode = {}
+
+local function BuildAllowedCacheForMode(mode)
+  if allowedByMode[mode] then return end
+  local cache = {}
+  for unitDefID, unitDef in pairs(UnitDefs) do
+    if EvaluateUnitForSharing(unitDef, mode) then
+      cache[unitDefID] = true
+    end
+  end
+  allowedByMode[mode] = cache
+end
+
+function Shared.IsShareableDef(unitDefId, mode)
+  if not unitDefId or not mode then return false end
+  BuildAllowedCacheForMode(mode)
+  return allowedByMode[mode][unitDefId] == true
+end
+
+return Shared
diff --git a/common/luaUtilities/team_transfer/unit_transfer_synced.lua b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
new file mode 100644
index 0000000000..924631f468
--- /dev/null
+++ b/common/luaUtilities/team_transfer/unit_transfer_synced.lua
@@ -0,0 +1,81 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local UnitSharingCategories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
+local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
+local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
+local Hack = VFS.Include("common/luaUtilities/team_transfer/take_hack.lua")
+
+local Synced = {
+  ValidateUnits = Shared.ValidateUnits,
+}
+
+---Get per-pair policy (expose) and cache it for UI consumption
+---@param ctx PolicyContext
+---@return UnitPolicyResult
+function Synced.GetPolicy(ctx)
+  local mode = Spring.GetModOptions().unit_sharing_mode
+  local allowTakeBypass = Hack.CheckTakeCondition(ctx.senderTeamId, ctx.receiverTeamId)
+  local canShare = ctx.areAlliedTeams and mode ~= SharedEnums.UnitSharingMode.Disabled
+  return {
+    canShare = canShare,
+    senderTeamId = ctx.senderTeamId,
+    receiverTeamId = ctx.receiverTeamId,
+    sharingMode = mode,
+    allowTakeBypass = allowTakeBypass,
+  }
+end
+
+---Execute unit transfer with pre-validated units
+---@param ctx UnitTransferContext
+---@return UnitTransferResult
+function Synced.UnitTransfer(ctx)
+  local policyResult = ctx.policyResult
+
+  if not policyResult.canShare then
+    ---@type UnitTransferResult
+    return {
+      success = false,
+      outcome = SharedEnums.UnitValidationOutcome.Failure,
+      senderTeamId = ctx.senderTeamId,
+      receiverTeamId = ctx.receiverTeamId,
+      validationResult = ctx.validationResult,
+      policyResult = ctx.policyResult
+    }
+  end
+
+  local transferredUnits = {}
+  local failedUnits = {}
+
+  for _, unitId in ipairs(ctx.validationResult.validUnitIds) do
+    local success = Spring.TransferUnit(unitId, ctx.receiverTeamId, ctx.given) -- ctx.given should always be false here because we short-circuit inside AllowResourceTransfer
+    if success then
+      table.insert(transferredUnits, unitId)
+    else
+      table.insert(failedUnits, unitId)
+    end
+  end
+
+  for _, unitId in ipairs(ctx.validationResult.invalidUnitIds) do
+    table.insert(failedUnits, unitId)
+  end
+
+  ---@type UnitTransferResult
+  return {
+    outcome = ctx.validationResult.status,
+    senderTeamId = ctx.senderTeamId,
+    receiverTeamId = ctx.receiverTeamId,
+    validationResult = ctx.validationResult,
+    policyResult = ctx.policyResult
+  }
+end
+
+---@param springRepo ISpring
+---@param senderId number
+---@param receiverId number
+---@param policyResult UnitPolicyResult
+function Synced.CachePolicyResult(springRepo, senderId, receiverId, policyResult)
+  local baseKey = PolicyShared.MakeBaseKey(receiverId, SharedEnums.TransferCategory.UnitTransfer)
+  local serialized = Shared.SerializePolicy(policyResult)
+  springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
+end
+
+return Synced
diff --git a/language/en/interface.json b/language/en/interface.json
index 1ea02dffed..eebed2a1c4 100644
--- a/language/en/interface.json
+++ b/language/en/interface.json
@@ -84,7 +84,14 @@
 			"requestSupport": "Double-click to ask for support",
 			"requestMetal": "Click-and-drag to ask for metal",
 			"requestEnergy": "Click-and-drag to ask for energy",
-			"shareUnits": "Double-click to share units",
+			"shareUnits": "Double-click to share %{validUnitCount} units",
+			"shareUnitsInvalid": {
+				"all": "Sharing these units are not allowed",
+				"one": "Double-click to share units (mode is %{unitSharingMode} - %{firstInvalidUnitName} cannot be shared)",
+				"two": "Double-click to share units (mode is %{unitSharingMode} - %{firstInvalidUnitName} and %{secondInvalidUnitName} cannot be shared)",
+				"other": "Double-click to share units (mode is %{unitSharingMode} - %{firstInvalidUnitName}, %{secondInvalidUnitName} and %{count} others cannot be shared)"
+			},
+			"shareUnitsDisabled": "Unit sharing not allowed (mode is %{unitSharingMode})",
 			"shareMetal": "Click-and-drag to share metal",
 			"shareMetalTaxed": "Click-and-drag to share metal, receivable: %{amountReceivable}m, spendable: %{amountSendable}m at %{taxRatePercentage}%%",
 			"shareMetalTaxedThreshold": "Click-and-drag to share metal, receivable: %{amountReceivable}m, spendable: %{amountSendable}m at %{taxRatePercentage}%% (free used %{sentAmountUntaxed}/%{resourceShareThreshold}m)",
diff --git a/luarules/gadgets/cmd_idle_players.lua b/luarules/gadgets/cmd_idle_players.lua
index feccb1a575..5949e04a9a 100644
--- a/luarules/gadgets/cmd_idle_players.lua
+++ b/luarules/gadgets/cmd_idle_players.lua
@@ -232,17 +232,6 @@ if gadgetHandler:IsSyncedCode() then
 		end
 	end
 
-	function gadget:AllowResourceTransfer(fromTeamID, toTeamID, restype, level)
-		-- prevent resources to leak to uncontrolled teams
-		return GetTeamRulesParam(toTeamID,"numActivePlayers") ~= 0 or IsCheatingEnabled()
-	end
-
-	function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
-		-- prevent units to be shared to uncontrolled teams
-		return capture or GetTeamRulesParam(toTeamID,"numActivePlayers") ~= 0 or IsCheatingEnabled()
-	end
-
-
 else	-- UNSYNCED
 
 
diff --git a/luarules/gadgets/game_disable_unit_sharing.lua b/luarules/gadgets/game_disable_unit_sharing.lua
deleted file mode 100644
index 8629fa5d24..0000000000
--- a/luarules/gadgets/game_disable_unit_sharing.lua
+++ /dev/null
@@ -1,31 +0,0 @@
-local gadget = gadget ---@type Gadget
-
-function gadget:GetInfo()
-	return {
-		name    = 'Disable Unit Sharing',
-		desc    = 'Disable unit sharing when modoption is enabled',
-		author  = 'Rimilel',
-		date    = 'April 2024',
-		license = 'GNU GPL, v2 or later',
-		layer   = 0,
-		enabled = true
-	}
-end
-
-----------------------------------------------------------------
--- Synced only
-----------------------------------------------------------------
-if not gadgetHandler:IsSyncedCode() then
-	return false
-end
-
-if not Spring.GetModOptions().disable_unit_sharing then
-	return false
-end
-
-function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
-	if (capture) then
-		return true
-	end
-	return false
-end
diff --git a/luarules/gadgets/game_unit_sharing_mode.lua b/luarules/gadgets/game_unit_sharing_mode.lua
new file mode 100644
index 0000000000..138f7be9a3
--- /dev/null
+++ b/luarules/gadgets/game_unit_sharing_mode.lua
@@ -0,0 +1,94 @@
+local gadget = gadget ---@type Gadget
+
+function gadget:GetInfo()
+  return {
+    name    = 'Unit Sharing Mode',
+    desc    = 'Controls which units can be shared with allies',
+    author  = 'Rimilel, Attean',
+    date    = 'April 2024',
+    license = 'GNU GPL, v2 or later',
+    layer   = 1,
+    enabled = true
+  }
+end
+
+local POLICY_CACHE_TAINT_FRAME_RATE_HEAVY = 150 --5 seconds
+
+----------------------------------------------------------------
+-- Synced only
+----------------------------------------------------------------
+if not gadgetHandler:IsSyncedCode() then
+  return false
+end
+
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
+local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
+local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
+
+------------------------------------------------
+--- Initialization
+------------------------------------------------
+
+local contextFactory = ContextFactoryModule.create(Spring)
+
+local lastGameFrameCacheUpdate = 0
+
+---@param policyContext PolicyContext
+---@return UnitPolicyResult
+function BuildPolicyCache(policyContext)
+  local policyResult = UnitTransfer.GetPolicy(policyContext)
+  UnitTransfer.CachePolicyResult(
+    Spring,
+    policyContext.senderTeamId,
+    policyContext.receiverTeamId,
+    policyResult
+  )
+  return policyResult
+end
+
+local function InitializeNewTeam(senderTeamId, receiverTeamId)
+  local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
+  BuildPolicyCache(ctx)
+end
+
+function gadget:Initialize()
+  local teams = Spring.GetTeamList() or {}
+  for _, sender in ipairs(teams) do
+    for _, receiver in ipairs(teams) do
+      InitializeNewTeam(sender, receiver)
+    end
+  end
+  lastGameFrameCacheUpdate = Spring.GetGameFrame()
+end
+
+function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
+  if capture then
+    return true
+  end
+  local policyResult = Shared.GetCachedPolicyResult(fromTeamID, toTeamID)
+  local given = false
+  local validation = Shared.ValidateUnits(policyResult, { unitID })
+  if validation and validation.status ~= SharedEnums.UnitValidationOutcome.Failure then
+    local transferCtx = contextFactory.unitTransfer(fromTeamID, toTeamID, { unitID }, given, policyResult, validation)
+    UnitTransfer.UnitTransfer(transferCtx)
+  end
+
+  return false
+end
+
+function gadget:GameFrame(frame)
+  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
+  if frame < nextSchedHeavy then
+    return
+  end
+  local teamList = Spring.GetTeamList() or {}
+  lastGameFrameCacheUpdate = frame
+  -- Update policies for all team pairs to ensure UI has current alliance status
+  for _, senderTeamId in ipairs(teamList) do
+    for _, receiverTeamId in ipairs(teamList) do
+      local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
+      BuildPolicyCache(ctx)
+    end
+  end
+end
diff --git a/luarules/gadgets/unit_prevent_share_self_d.lua b/luarules/gadgets/unit_prevent_share_self_d.lua
index f5dec7122a..d21729db6b 100644
--- a/luarules/gadgets/unit_prevent_share_self_d.lua
+++ b/luarules/gadgets/unit_prevent_share_self_d.lua
@@ -21,10 +21,10 @@ local monitorPlayers = {}
 local spGetPlayerInfo = Spring.GetPlayerInfo
 
 function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
-	if Spring.GetUnitSelfDTime(unitID) > 0 then
-		Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
-	end
-	return true
+    if Spring.GetUnitSelfDTime(unitID) > 0 then
+        Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
+    end
+    return true
 end
 
 local function removeSelfdOrders(teamID)
diff --git a/luaui/Widgets/gui_advplayerslist.lua b/luaui/Widgets/gui_advplayerslist.lua
index ddd01852cd..f5cd841bbf 100644
--- a/luaui/Widgets/gui_advplayerslist.lua
+++ b/luaui/Widgets/gui_advplayerslist.lua
@@ -63,6 +63,7 @@ end
 local SharedEnums = VFS.Include('common/luaUtilities/team_transfer/shared_enums.lua')
 local TeamTransfer = VFS.Include('common/luaUtilities/team_transfer/team_transfer_unsynced.lua')
 local ResourceTransfer = TeamTransfer.Resources
+local UnitTransfer = TeamTransfer.Units
 
 --------------------------------------------------------------------------------
 -- Config
@@ -757,6 +758,22 @@ function ActivityEvent(playerID)
     lastActivity[playerID] = os.clock()
 end
 
+function widget:SelectionChanged(selectedUnits)
+    local myTeamID = Spring_GetMyTeamID()
+    for playerID, playerData in pairs(player) do
+        if playerData.team and playerID ~= myTeamID then
+            if selectedUnits and #selectedUnits > 0 then
+                local policyResult = UnitTransfer.GetCachedPolicyResult(myTeamID, playerData.team)
+                local validationResult = UnitTransfer.ValidateUnits(policyResult, selectedUnits)
+                TeamTransfer.PackSelectedUnitsValidation(validationResult, playerData)
+            else
+                TeamTransfer.ClearSelectedUnitsValidation(playerData)
+            end
+        end
+    end
+end
+
+
 ---------------------------------------------------------------------------------------------------
 --  Init/GameStart (creating players)
 ---------------------------------------------------------------------------------------------------
@@ -2210,9 +2227,10 @@ function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY, onlyMainList, onl
     local dead = player[playerID].dead
     local ai = player[playerID].ai
     local alliances = player[playerID].alliances
-    local metalPolicy, energyPolicy
+    local metalPolicy, energyPolicy, unitPolicy, unitValidationResult
     if not spec then
-        metalPolicy, energyPolicy = ResourceTransfer.GetAllPolicies(player[playerID], myTeamID, team)
+        metalPolicy, energyPolicy, unitPolicy = TeamTransfer.UnpackAllPolicies(player[playerID], myTeamID, team)
+        unitValidationResult = TeamTransfer.UnpackSelectedUnitsValidation(player[playerID])
     end
     local posY = widgetPosY + widgetHeight - vOffset
     local tipPosY = widgetPosY + ((widgetHeight - vOffset) * widgetScale)
@@ -2273,10 +2291,10 @@ function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY, onlyMainList, onl
                                 end
                             end
                         end
-                        if m_share.active and not dead and not hideShareIcons and (metalPolicy and energyPolicy) then
-                            DrawShareButtons(posY, metalPolicy, energyPolicy)
+                        if m_share.active and not dead and not hideShareIcons and (unitPolicy and metalPolicy and energyPolicy) then
+                            DrawShareButtons(posY, unitPolicy, metalPolicy, energyPolicy, unitValidationResult)
                             if tipY then
-                                ShareTip(mouseX, metalPolicy, energyPolicy)
+                                ShareTip(mouseX, unitPolicy, metalPolicy, energyPolicy, unitValidationResult)
                             end
                         end
                     end
@@ -2429,7 +2447,7 @@ local function DrawSharingIconOverlay(posY, enabled, offsetX)
     end
 end
 
-function DrawShareButtons(posY, unitPolicy, metalPolicy, energyPolicy)
+function DrawShareButtons(posY, unitPolicy, metalPolicy, energyPolicy, unitValidationResult)
     gl_Color(1, 1, 1, 1)
     gl_Texture(pics["unitsPic"])
     DrawRect(m_share.posX + widgetPosX + (1*playerScale), posY, m_share.posX + widgetPosX + (17*playerScale), posY + (16*playerScale))
@@ -2438,8 +2456,10 @@ function DrawShareButtons(posY, unitPolicy, metalPolicy, energyPolicy)
     gl_Texture(pics["metalPic"])
     DrawRect(m_share.posX + widgetPosX + (33*playerScale), posY, m_share.posX + widgetPosX + (49*playerScale), posY + (16*playerScale))
 
-    DrawSharingIconOverlay(posY, energyPolicy, 17 * playerScale)
-    DrawSharingIconOverlay(posY, metalPolicy, 33 * playerScale)
+    local shareButtonEnabled = unitPolicy.canShare and (not unitValidationResult or unitValidationResult.status ~= SharedEnums.UnitValidationOutcome.Failure)
+    DrawSharingIconOverlay(posY, shareButtonEnabled, 1 * playerScale)
+    DrawSharingIconOverlay(posY, energyPolicy.canShare, 17 * playerScale)
+    DrawSharingIconOverlay(posY, metalPolicy.canShare, 33 * playerScale)
 
     gl_Texture(false)
 end
@@ -3046,13 +3066,9 @@ function NameTip(mouseX, playerID, accountID, nameIsAlias)
 	end
 end
 
-function ShareTip(mouseX, metalPolicy, energyPolicy)
+function ShareTip(mouseX, unitPolicy, metalPolicy, energyPolicy, unitValidationResult)
     if mouseX >= widgetPosX + (m_share.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (17*playerScale)) * widgetScale then
-        if myPlayerID == metalPolicy.receiverTeamId then
-            tipText = Spring.I18N('ui.playersList.shareUnits')
-        else
-            tipText = Spring.I18N('ui.playersList.shareUnits')
-        end
+        tipText = UnitTransfer.TooltipText(unitPolicy, unitValidationResult)
     elseif mouseX >= widgetPosX + (m_share.posX + (19*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (35*playerScale)) * widgetScale then
         tipText = ResourceTransfer.TooltipText(energyPolicy)
     elseif mouseX >= widgetPosX + (m_share.posX + (37*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (53*playerScale)) * widgetScale then
diff --git a/modoptions.lua b/modoptions.lua
index d1bc77a49c..e8f57b0bd4 100644
--- a/modoptions.lua
+++ b/modoptions.lua
@@ -306,8 +306,22 @@ local options = {
 		column  = 2,
 		disabled= { key="tax_resource_sharing_amount", value = 0},
 	},
+	{
+		key		= "unit_sharing_mode",
+		name	= "Unit Sharing Mode",
+		desc	= "Controls which units can be shared",
+		type	= "list",
 		section	= "options_main",
-		def		= false,
+		def		= "enabled",
+		items	= {
+			{ key = "enabled", name = "Enabled", desc = "All unit sharing allowed" },
+			{ key = "t2_cons", name = "T2 Constructor Sharing Only", desc = "Only T2 constructors can be shared between allies" },
+			{ key = "combat", name = "Combat Units Only", desc = "Only combat units can be shared (no economic units, factories, or constructors)" },
+			{ key = "combat_t2_cons", name = "Combat Units + T2 Constructors", desc = "Combat units and T2 constructors can be shared" },
+			{ key = "economic", name = "Economic Units Only", desc = "Only combat units can be shared (no economic units, factories, or constructors)" },
+			{ key = "economic_plus_buildings", name = "Economic Units and Buildings", desc = "All economic units and resource production buildings can be shared but no combat units" },
+			{ key = "disabled", name = "Disabled", desc = "No unit sharing allowed" },
+		},
 	},
 	{
 		key		= "disable_assist_ally_construction",
diff --git a/types/team_transfer.lua b/types/team_transfer.lua
index 7dc4c19f6a..098cf30348 100644
--- a/types/team_transfer.lua
+++ b/types/team_transfer.lua
@@ -16,7 +16,7 @@
 
 -- Unit Transfer Action
 
----@class UnitTransferPolicyResult : PolicyResult
+---@class UnitPolicyResult : PolicyResult
 ---@field canShare boolean
 ---@field sharingMode string
 ---@field allowTakeBypass boolean
@@ -25,7 +25,7 @@
 ---@field unitIds number[]
 ---@field given boolean?
 ---@field validationResult UnitValidationResult
----@field policyResult UnitTransferPolicyResult
+---@field policyResult UnitPolicyResult
 
 ---@class UnitDefValidationSummary
 ---@field ok boolean
@@ -36,10 +36,10 @@
 ---@class UnitValidationResult
 ---@field status string SharedEnums.UnitValidationOutcome
 ---@field invalidUnitCount number
----@field invalidUnitCategoryCount number
+---@field invalidUnitIds number[]
 ---@field invalidUnitNames string[]
 ---@field validUnitCount number
----@field validUnitCategoryCount number
+---@field validUnitIds number[]
 ---@field validUnitNames string[]
 
 ---@class UnitTransferResult
@@ -47,7 +47,7 @@
 ---@field senderTeamId number
 ---@field receiverTeamId number
 ---@field validationResult UnitValidationResult
----@field policyResult UnitTransferPolicyResult
+---@field policyResult UnitPolicyResult
 
 -- Unit Sharing Globals
 

commit 8e59791eddb9dfbf63b71b79d2d37154fd083f06
Author: Daniel Harvey <keithdanielharvey@gmail.com>
Date:   Sun Oct 19 13:47:29 2025 -0600

    feat(share-tax): add sender metal send threshold
    
    - Add modoption `player_metal_send_threshold` to defer metal tax until a sender’s cumulative sent metal exceeds the threshold; energy unchanged (taxed only by `tax_resource_sharing_amount`).
    - Track cumulative sent metal per sender and expose via team rules params: `metal_share_cumulative_sent`, `metal_share_threshold`, `resource_share_tax_rate`.
    - UI (AdvPlayersList): while dragging the share slider
      - Energy shows received/sent preview.
      - Metal shows amount_to_send/max_allowance and caps the slider by min(my metal, receiver free, remaining allowance).
      - Right-justified label with auto-sized grey background to fit two-number display.
      - Echo on send uses i18n: “Sent Xm[/Ym allowed by the player send threshold]” (optional bracket when threshold > 0).
    - Refactor: add `common/luaUtilities/resource_share_tax.lua` and use it from both gadget and UI to keep the math in one place.
    - Safety: clamps against receiver max share, handles 100% tax case, guards against negatives. Default threshold is 0 (immediate tax if base rate > 0). No changes to unit-sharing logic.
    - i18n: add `ui.playersList.chat.sentMetal` and `ui.playersList.chat.sentMetalThreshold` (en). translation keys try to match the policy keys.

diff --git a/.luarc.json b/.luarc.json
index 361d748a20..f8d9dd3df9 100644
--- a/.luarc.json
+++ b/.luarc.json
@@ -13,7 +13,9 @@
   },
   "workspace": {
     "library": [
-      "recoil-lua-library"
+      "recoil-lua-library",
+      "types",
+      "common/luaUtilities"
     ],
     "ignoreDir": [
       ".vscode",
diff --git a/common/luaUtilities/team_transfer/context_factory.lua b/common/luaUtilities/team_transfer/context_factory.lua
new file mode 100644
index 0000000000..2ea8b16d4e
--- /dev/null
+++ b/common/luaUtilities/team_transfer/context_factory.lua
@@ -0,0 +1,124 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+
+---@class ContextFactory
+---@field create fun(springRepo: ISpring): ContextFactory
+---@field policy fun(senderTeamID: number, receiverTeamID: number): PolicyContext
+---@field action fun(senderTeamId: number, receiverTeamId: number, transferCategory: string): PolicyActionContext
+---@field resourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: ResourceType, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
+---@field unitTransfer fun(senderTeamId: number, receiverTeamId: number, unitIds: number[], given: boolean, policyResult: UnitTransferPolicyResult): UnitTransferContext
+local ContextFactory = {}
+
+---@param springRepo ISpring
+---@param teamID number
+---@param resourceType string
+---@return ResourceData Complete resource data for the team
+local function getTeamResourcesUnpacked(springRepo, teamID, resourceType)
+  local current, storage, pull, income, expense, share, sent, received = springRepo.GetTeamResources(teamID,
+    resourceType)
+
+  return {
+    current = current,
+    storage = storage,
+    pull = pull,
+    income = income,
+    expense = expense,
+    shareSlider = share,
+    sent = sent,
+    received = received
+  }
+end
+
+---@param springRepo ISpring
+---@return table Context factory with closures
+function ContextFactory.create(springRepo)
+  ---Create context with optional extensions
+  ---@param senderTeamID number
+  ---@param receiverTeamID number
+  ---@param extensions? table Additional fields to merge
+  ---@return table Context
+  local function buildContext(senderTeamID, receiverTeamID, extensions)
+    local senderMetal = getTeamResourcesUnpacked(springRepo, senderTeamID, SharedEnums.ResourceType.METAL)
+    local senderEnergy = getTeamResourcesUnpacked(springRepo, senderTeamID, SharedEnums.ResourceType.ENERGY)
+    local receiverMetal = getTeamResourcesUnpacked(springRepo, receiverTeamID, SharedEnums.ResourceType.METAL)
+    local receiverEnergy = getTeamResourcesUnpacked(springRepo, receiverTeamID, SharedEnums.ResourceType.ENERGY)
+
+    ---@type TeamResources
+    local senderResources = {
+      metal = senderMetal,
+      energy = senderEnergy
+    }
+
+    ---@type TeamResources
+    local receiverResources = {
+      metal = receiverMetal,
+      energy = receiverEnergy
+    }
+
+    ---@type PolicyContext
+    local ctx = {
+      senderTeamId = senderTeamID,
+      receiverTeamId = receiverTeamID,
+      resultSoFar = {},
+      sender = senderResources,
+      receiver = receiverResources,
+      springRepo = springRepo,
+      areAlliedTeams = springRepo.AreTeamsAllied(senderTeamID, receiverTeamID),
+      isCheatingEnabled = springRepo.IsCheatingEnabled()
+    }
+
+    if extensions then
+      for k, v in pairs(extensions) do
+        ctx[k] = v
+      end
+    end
+
+    return ctx
+  end
+
+  ---Create policy context
+  ---@param senderTeamID number
+  ---@param receiverTeamID number
+  ---@param commandType? string
+  ---@return PolicyContext
+  local function policy(senderTeamID, receiverTeamID, commandType)
+    return buildContext(senderTeamID, receiverTeamID, {
+      commandType = commandType
+    })
+  end
+
+  ---Create action context
+  ---@param transferCategory string
+  ---@param senderTeamId number
+  ---@param receiverTeamId number
+  ---@return PolicyActionContext
+  local function policyAction(senderTeamId, receiverTeamId, transferCategory)
+    return buildContext(senderTeamId, receiverTeamId, {
+      transferCategory = transferCategory
+    })
+  end
+
+  ---Create resource transfer context for transfer actions
+  ---@param senderTeamId number
+  ---@param receiverTeamId number
+  ---@param resourceType ResourceType
+  ---@param desiredAmount number
+  ---@param policyResult ResourcePolicyResult
+  ---@return ResourceTransferContext
+  local function resourceTransfer(senderTeamId, receiverTeamId, resourceType, desiredAmount, policyResult)
+    local transferCategory = resourceType == SharedEnums.ResourceType.METAL and resourceType or
+        SharedEnums.TransferCategory.EnergyTransfer
+    return buildContext(senderTeamId, receiverTeamId, {
+      transferCategory = transferCategory,
+      resourceType = resourceType,
+      desiredAmount = desiredAmount,
+      policyResult = policyResult
+    })
+  end
+
+  return {
+    policy = policy,
+    action = policyAction,
+  }
+end
+
+return ContextFactory
diff --git a/common/luaUtilities/team_transfer/modoption_enums.lua b/common/luaUtilities/team_transfer/modoption_enums.lua
new file mode 100644
index 0000000000..a5fd69839c
--- /dev/null
+++ b/common/luaUtilities/team_transfer/modoption_enums.lua
@@ -0,0 +1,9 @@
+---@class TeamTransferModOptions
+local M = {}
+
+M.Options = {
+	TaxResourceSharingAmount = "tax_resource_sharing_amount",
+	PlayerMetalSendThreshold = "player_metal_send_threshold",
+}
+
+return M
diff --git a/common/luaUtilities/team_transfer/resource_transfer_comms.lua b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
new file mode 100644
index 0000000000..9a6feb24d0
--- /dev/null
+++ b/common/luaUtilities/team_transfer/resource_transfer_comms.lua
@@ -0,0 +1,112 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+
+local Comms = {}
+Comms.__index = Comms
+
+--- Determine communication case from parameters
+---@param senderTeamId number
+---@param receiverTeamId number
+---@param taxRate number
+---@param resourceShareThreshold number
+---@return integer
+function Comms.DecideCommunicationCaseFromParams(senderTeamId, receiverTeamId, taxRate, resourceShareThreshold)
+  if senderTeamId == receiverTeamId then
+    return SharedEnums.ResourceCommunicationCase.OnSelf
+  end
+  if taxRate <= 0 then
+    return SharedEnums.ResourceCommunicationCase.OnTaxFree
+  end
+  if resourceShareThreshold > 0 then
+    return SharedEnums.ResourceCommunicationCase.OnTaxedThreshold
+  end
+  return SharedEnums.ResourceCommunicationCase.OnTaxed
+end
+
+--- Determine communication case from policy result
+---@param policyResult ResourcePolicyResult
+---@return integer
+function Comms.DecideCommunicationCase(policyResult)
+  return Comms.DecideCommunicationCaseFromParams(
+    policyResult.senderTeamId,
+    policyResult.receiverTeamId,
+    policyResult.taxRate,
+    policyResult.resourceShareThreshold
+  )
+end
+
+---Format a number for UI display by flooring it to whole numbers, this mirrors behavior in ResourceTransfer, which rounds down to the nearest percentage when interpreting commands from the slider
+---@param value number
+---@return string
+function FormatNumberForUI(value)
+  if type(value) == "number" then
+      return tostring(math.floor(value))
+  else
+      return tostring(value)
+  end
+end
+Comms.FormatNumberForUI = FormatNumberForUI
+
+---@param policyResult ResourcePolicyResult
+function Comms.TooltipText(policyResult)
+  local pascalResourceType = policyResult.resourceType:gsub("^%l", string.upper)
+  local baseKey = 'ui.playersList'
+  local case = Comms.DecideCommunicationCase(policyResult)
+  if case == SharedEnums.ResourceCommunicationCase.OnSelf then
+      return Spring.I18N(baseKey .. '.request' .. pascalResourceType)
+  elseif case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
+      return Spring.I18N(baseKey .. '.share' .. pascalResourceType)
+  elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
+    local i18nData = {
+        amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
+        amountSendable = FormatNumberForUI(policyResult.amountSendable),
+        taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
+    }
+    return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'Taxed', i18nData)
+  elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
+      local i18nData = {
+          amountReceivable = FormatNumberForUI(policyResult.amountReceivable),
+          amountSendable = FormatNumberForUI(policyResult.amountSendable),
+          taxRatePercentage = FormatNumberForUI(policyResult.taxRate * 100),
+          resourceShareThreshold = FormatNumberForUI(policyResult.resourceShareThreshold),
+          sentAmountUntaxed = FormatNumberForUI(math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)),
+      }
+      return Spring.I18N(baseKey .. '.share' .. pascalResourceType .. 'TaxedThreshold', i18nData)
+  end
+end
+
+--- Send chat messages for completed resource transfers
+---@param transferResult ResourceTransferResult
+---@param policyResult ResourcePolicyResult
+function Comms.SendTransferChatMessages(transferResult, policyResult)
+  if transferResult.sent > 0 then
+    local resourceType = policyResult.resourceType
+    local pascalResourceType = resourceType == SharedEnums.ResourceType.METAL and "Metal" or "Energy"
+    local case = Comms.DecideCommunicationCase(policyResult)
+
+    if case == SharedEnums.ResourceCommunicationCase.OnTaxFree then
+      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
+        pascalResourceType .. ':receivedAmount=' .. math.floor(transferResult.received))
+    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxed then
+      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
+        pascalResourceType ..
+        'Taxed:receivedAmount=' ..
+        math.floor(transferResult.received) ..
+        ':sentAmount=' ..
+        math.floor(transferResult.sent) .. ':taxRatePercentage=' .. math.floor(policyResult.taxRate * 100 + 0.5))
+    elseif case == SharedEnums.ResourceCommunicationCase.OnTaxedThreshold then
+      local cumulativeUntaxed = math.min(policyResult.resourceShareThreshold, policyResult.cumulativeSent)
+      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sent' ..
+        pascalResourceType ..
+        'TaxedThreshold:receivedAmount=' ..
+        math.floor(transferResult.received) ..
+        ':sentAmount=' ..
+        math.floor(transferResult.sent) ..
+        ':taxRatePercentage=' ..
+        math.floor(policyResult.taxRate * 100 + 0.5) ..
+        ':sentAmountUntaxed=' ..
+        math.floor(cumulativeUntaxed) .. ':resourceShareThreshold=' .. math.floor(policyResult.resourceShareThreshold))
+    end
+  end
+end
+
+return Comms
\ No newline at end of file
diff --git a/common/luaUtilities/team_transfer/resource_transfer_shared.lua b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
new file mode 100644
index 0000000000..f922483c50
--- /dev/null
+++ b/common/luaUtilities/team_transfer/resource_transfer_shared.lua
@@ -0,0 +1,145 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local PolicyShared = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
+
+local Shared = {}
+
+local FieldTypes = PolicyShared.FieldTypes
+
+-- Field type definitions for serialization/deserialization
+Shared.ResourcePolicyFields = {
+  resourceType = FieldTypes.string,
+  canShare = FieldTypes.boolean,
+  amountSendable = FieldTypes.number,
+  amountReceivable = FieldTypes.number,
+  taxedPortion = FieldTypes.number,
+  untaxedPortion = FieldTypes.number,
+  taxRate = FieldTypes.number,
+  remainingTaxFreeAllowance = FieldTypes.number,
+  resourceShareThreshold = FieldTypes.number,
+  cumulativeSent = FieldTypes.number,
+}
+
+--- Core helper: compute sender cost for a desired received amount under policyResult
+---@param policyResult ResourcePolicyResult
+---@param desiredReceived number
+---@return number receivedAmount, number sentAmount, number untaxedPortion
+function Shared.CalculateSenderTaxedAmount(policyResult, desiredReceived)
+  local maxReceivable = policyResult.amountReceivable
+  local desired = math.min(desiredReceived, policyResult.amountSendable, maxReceivable)
+  if desired <= 0 then
+    return 0, 0, 0
+  end
+
+  local untaxed = math.min(desired, policyResult.untaxedPortion)
+  local taxed = desired - untaxed
+  local r = policyResult.taxRate
+
+  local received
+  local sent
+  if taxed > 0 then
+    if r >= 1.0 then
+      -- 100% tax means taxed portion cannot be sent (infinite cost)
+      sent = untaxed
+      received = untaxed       -- only untaxed portion reaches receiver
+    else
+      sent = untaxed + (taxed / (1 - r))
+      received = desired       -- all desired amount reaches receiver
+    end
+  else
+    sent = untaxed
+    received = untaxed
+  end
+
+  return received, sent, untaxed
+end
+
+---@param senderId number
+---@param receiverId number
+---@param resourceType ResourceType
+---@return ResourcePolicyResult
+function Shared.GetCachedPolicyResult(senderId, receiverId, resourceType)
+  local baseKey = Shared.MakeBaseKey(receiverId, resourceType)
+  local serialized = Spring.GetTeamRulesParam(senderId, baseKey)
+
+  if serialized == nil then
+    return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, 0)
+  end
+
+  if type(serialized) ~= "string" then
+    serialized = tostring(serialized)
+  end
+
+  local result = Shared.DeserializePolicyResult(serialized, senderId, receiverId)
+  return result
+end
+
+---@param resourceType ResourceType
+---@return string
+function Shared.GetCumulativeParam(resourceType)
+  if resourceType == SharedEnums.ResourceType.METAL then
+    return "metal_share_cumulative_sent"
+  else
+    return "energy_share_cumulative_sent"
+  end
+end
+
+---@param teamId number
+---@param resourceType ResourceType
+---@return number
+function Shared.GetCumulativeSent(teamId, resourceType)
+  local param = Shared.GetCumulativeParam(resourceType)
+  return tonumber(Spring.GetTeamRulesParam(teamId, param)) or 0
+end
+
+---Generate base key for policy caching
+---@param receiverId number
+---@param resourceType ResourceType
+---@return string
+function Shared.MakeBaseKey(receiverId, resourceType)
+  local transferCategory = resourceType == SharedEnums.ResourceType.METAL and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
+  return PolicyShared.MakeBaseKey(receiverId, transferCategory)
+end
+
+---Serialize ResourcePolicyResult to string for efficient storage
+---@param policyResult table
+---@return string
+function Shared.SerializeResourcePolicyResult(policyResult)
+  return PolicyShared.Serialize(Shared.ResourcePolicyFields, policyResult)
+end
+
+---Deserialize ResourcePolicyResult from string
+---@param serialized string
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return ResourcePolicyResult
+function Shared.DeserializePolicyResult(serialized, senderTeamId, receiverTeamId)
+  return PolicyShared.Deserialize(Shared.ResourcePolicyFields, serialized, {
+    senderTeamId = senderTeamId,
+    receiverTeamId = receiverTeamId,
+  })
+end
+
+---Create a default deny ResourcePolicyResult
+---@param senderTeamId number
+---@param receiverTeamId number
+---@param resourceType ResourceType
+---@param cumulativeSent number?
+---@return ResourcePolicyResult
+function Shared.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType, cumulativeSent)
+  return {
+    senderTeamId = senderTeamId,
+    receiverTeamId = receiverTeamId,
+    canShare = false,
+    amountSendable = 0,
+    amountReceivable = 0,
+    taxedPortion = 0,
+    untaxedPortion = 0,
+    taxRate = 0,
+    resourceType = resourceType,
+    remainingTaxFreeAllowance = 0,
+    resourceShareThreshold = 0,
+    cumulativeSent = cumulativeSent or 0,
+  }
+end
+
+return Shared
diff --git a/common/luaUtilities/team_transfer/resource_transfer_synced.lua b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
new file mode 100644
index 0000000000..e2478df768
--- /dev/null
+++ b/common/luaUtilities/team_transfer/resource_transfer_synced.lua
@@ -0,0 +1,188 @@
+local ModOptions = VFS.Include("common/luaUtilities/team_transfer/modoption_enums.lua")
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
+local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
+
+local Gadgets = {
+  SendTransferChatMessages = Comms.SendTransferChatMessages,
+}
+Gadgets.__index = Gadgets
+
+-- Determine if a team is a non-player team (Gaia or AI-controlled)
+local function isNonPlayerTeam(springRepo, teamId)
+  if teamId == springRepo.GetGaiaTeamID() then
+    return true
+  end
+  local _name, _active, _spec, isAiTeam = springRepo.GetTeamInfo(teamId, false)
+  if isAiTeam then
+    return true
+  end
+  local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
+  return luaAI ~= nil
+end
+
+-- Build a rejected policy result with zeroed capabilities
+---@param ctx PolicyContext
+---@param resourceType ResourceType
+---@return ResourcePolicyResult
+local function rejectPolicy(ctx, resourceType)
+  return Shared.CreateDenyPolicy(
+    ctx.senderTeamId,
+    ctx.receiverTeamId,
+    resourceType,
+    Shared.GetCumulativeSent(ctx.senderTeamId, resourceType)
+  )
+end
+
+-- Encapsulate legacy AllowResourceTransfer gate rules
+---@param ctx PolicyContext
+---@param resourceType ResourceType
+---@return ResourcePolicyResult|nil
+local function tryRejectPolicy(ctx, resourceType)
+  if ctx.isCheatingEnabled then
+    return nil
+  end
+  if not ctx.areAlliedTeams and not isNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
+    return rejectPolicy(ctx, resourceType)
+  end
+  local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
+  local activePlayers = numActivePlayers and
+      tonumber(ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")) or 0
+  if activePlayers == 0 then
+    return rejectPolicy(ctx, resourceType)
+  end
+  return nil
+end
+
+--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
+---@param ctx ResourceTransferContext
+---@return ResourceTransferResult
+function Gadgets.ResourceTransfer(ctx)
+  local policyResult = ctx.policyResult
+  local desiredAmount = ctx.desiredAmount
+
+  if (not policyResult or not policyResult.canShare) or (not desiredAmount or desiredAmount <= 0) then
+    ---@type ResourceTransferResult
+    return {
+      success = false,
+      sent = 0,
+      received = 0,
+      untaxed = 0,
+      senderTeamId = ctx.senderTeamId,
+      receiverTeamId = ctx.receiverTeamId,
+      policyResult = policyResult,
+    }
+  end
+
+  local received, sent, untaxed = Shared.CalculateSenderTaxedAmount(policyResult, desiredAmount)
+
+  local springRepo = ctx.springRepo
+  springRepo.AddTeamResource(ctx.senderTeamId, policyResult.resourceType, -sent)
+  springRepo.AddTeamResource(ctx.receiverTeamId, policyResult.resourceType, received)
+
+  ---@type ResourceTransferResult
+  local result = {
+    success = true,
+    sent = sent,
+    received = received,
+    untaxed = untaxed,
+    senderTeamId = ctx.senderTeamId,
+    receiverTeamId = ctx.receiverTeamId,
+    policyResult = policyResult
+  }
+
+  return result
+end
+
+---@param taxRate number
+---@param metalThreshold number
+---@param energyThreshold number
+---@return fun(ctx: PolicyContext, resourceType: ResourceType) : ResourcePolicyResult
+function Gadgets.BuildResultFactory(taxRate, metalThreshold, energyThreshold)
+  ---@param resourceType ResourceType
+  local function getThreshold(resourceType)
+    if resourceType == SharedEnums.ResourceType.METAL then
+      return metalThreshold
+    elseif resourceType == SharedEnums.ResourceType.ENERGY then
+      return energyThreshold
+    end
+  end
+
+  ---@param ctx PolicyContext
+  ---@param resourceType ResourceType
+  ---@return ResourcePolicyResult
+  local function calcResourcePolicyResult(ctx, resourceType)
+    local rejected = tryRejectPolicy(ctx, resourceType)
+    if rejected then return rejected end
+
+    local senderData
+    local receiverData
+    if resourceType == SharedEnums.ResourceType.METAL then
+      senderData = ctx.sender.metal
+      receiverData = ctx.receiver.metal
+    elseif resourceType == SharedEnums.ResourceType.ENERGY then
+      senderData = ctx.sender.energy
+      receiverData = ctx.receiver.energy
+    end
+
+    local receiverCapacity = receiverData.storage - receiverData.current
+
+    local cumulativeSent = Shared.GetCumulativeSent(ctx.senderTeamId, resourceType)
+    local threshold = getThreshold(resourceType)
+    local allowanceRemaining = math.max(0, threshold - cumulativeSent)
+    local senderBudget = math.max(0, senderData.current)
+
+    local untaxedPortion = math.min(allowanceRemaining, senderBudget)
+
+    local effectiveRate = (taxRate < 1) and taxRate or 1
+
+    -- Cap taxed receivable early by budget and receiver capacity
+    local taxedSendable = math.max(0, (senderBudget - untaxedPortion) * (1 - effectiveRate))
+    local maxReceivable = math.max(0, receiverCapacity - untaxedPortion)
+    local taxedPortion = math.min(taxedSendable, maxReceivable)
+
+    -- Example of sender cost inversion used by ResourceTransfer: untaxed + taxed/(1 - r)
+    -- local reversed = untaxedPortion + (taxedPortion > 0 and (taxedPortion / (1 - effectiveRate)) or 0)
+
+    -- note that amountSendable is in receivable units
+    local amountSendable = untaxedPortion + taxedPortion
+
+    ---@type ResourcePolicyResult
+    return {
+      senderTeamId = ctx.senderTeamId,
+      receiverTeamId = ctx.receiverTeamId,
+      canShare = amountSendable > 0,
+      amountSendable = amountSendable,
+      amountReceivable = receiverCapacity,
+      taxedPortion = taxedPortion,
+      untaxedPortion = untaxedPortion,
+      taxRate = effectiveRate,
+      resourceType = resourceType,
+      remainingTaxFreeAllowance = allowanceRemaining,
+      resourceShareThreshold = threshold,
+      cumulativeSent = cumulativeSent,
+    }
+  end
+  return calcResourcePolicyResult
+end
+
+---@param ctx ResourceTransferContext
+---@param transferResult ResourceTransferResult
+function Gadgets.RegisterPostTransfer(ctx, transferResult)
+  local cumulativeParam = Shared.GetCumulativeParam(ctx.resourceType)
+  local cumulativeSent = tonumber(ctx.springRepo.GetTeamRulesParam(transferResult.senderTeamId, cumulativeParam))
+  ctx.springRepo.SetTeamRulesParam(ctx.senderTeamId, cumulativeParam, cumulativeSent + transferResult.sent)
+end
+
+---@param springRepo ISpring
+---@param senderId number
+---@param receiverId number
+---@param resourceType ResourceType
+---@param policyResult ResourcePolicyResult
+function Gadgets.CachePolicyResult(springRepo, senderId, receiverId, resourceType, policyResult)
+  local baseKey = Shared.MakeBaseKey(receiverId, resourceType)
+  local serialized = Shared.SerializeResourcePolicyResult(policyResult)
+  springRepo.SetTeamRulesParam(senderId, baseKey, serialized)
+end
+
+return Gadgets
diff --git a/common/luaUtilities/team_transfer/shared_enums.lua b/common/luaUtilities/team_transfer/shared_enums.lua
new file mode 100644
index 0000000000..9930c4ec1e
--- /dev/null
+++ b/common/luaUtilities/team_transfer/shared_enums.lua
@@ -0,0 +1,23 @@
+local M = {}
+M.__index = M
+
+M.TransferCategory = {
+	MetalTransfer = "metal_transfer",
+	EnergyTransfer = "energy_transfer",
+}
+
+M.ResourceType = {
+	METAL = "metal",
+	ENERGY = "energy",
+}
+
+M.ResourceTypes = { M.ResourceType.METAL, M.ResourceType.ENERGY }
+
+M.ResourceCommunicationCase = {
+	OnSelf = 1,
+	OnTaxFree = 2,
+	OnTaxedThreshold = 3,
+	OnTaxed = 4,
+}
+
+return M
diff --git a/common/luaUtilities/team_transfer/team_transfer_cache.lua b/common/luaUtilities/team_transfer/team_transfer_cache.lua
new file mode 100644
index 0000000000..06e02bd133
--- /dev/null
+++ b/common/luaUtilities/team_transfer/team_transfer_cache.lua
@@ -0,0 +1,82 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+
+local M = {}
+
+-- Simple field type markers used by serializer
+M.FieldTypes = {
+  string = "string",
+  boolean = "boolean",
+  number = "number",
+}
+
+---Generate base key for policy caching using TransferCategory
+---@param receiverId number
+---@param transferCategory string SharedEnums.TransferCategory enum value
+---@return string
+function M.MakeBaseKey(receiverId, transferCategory)
+  local baseKeyPrefix = transferCategory
+  return string.format("%s_policy_%d_", baseKeyPrefix, receiverId)
+end
+
+--- Serialize an object using a fields schema into a colon-delimited string
+--- @param fields table<string,string> fieldName -> FieldTypes
+--- @param obj table
+--- @return string
+function M.Serialize(fields, obj)
+  local parts = {}
+  for fieldName, fieldType in pairs(fields) do
+    local v = obj[fieldName]
+    if v ~= nil then
+      if fieldType == M.FieldTypes.boolean then
+        v = v and "1" or "0"
+      elseif fieldType == M.FieldTypes.string then
+        v = tostring(v)
+      else
+        v = tostring(v)
+      end
+      parts[#parts+1] = fieldName
+      parts[#parts+1] = v
+    end
+  end
+  return table.concat(parts, ":")
+end
+
+--- Deserialize a colon-delimited string into a table using a fields schema
+--- @param fields table<string,string> fieldName -> FieldTypes
+--- @param serialized string
+--- @param extras table? optional table of extra kv pairs to merge into result
+--- @return table
+function M.Deserialize(fields, serialized, extras)
+  local result = {}
+  if type(serialized) ~= "string" then
+    serialized = tostring(serialized or "")
+  end
+  local parts = {}
+  for part in string.gmatch(serialized, "([^:]+)") do
+    parts[#parts+1] = part
+  end
+  for i = 1, #parts, 2 do
+    local key = parts[i]
+    local value = parts[i + 1]
+    if key and value then
+      local fieldType = fields[key]
+      if fieldType == M.FieldTypes.boolean then
+        result[key] = value == "1"
+      elseif fieldType == M.FieldTypes.number then
+        result[key] = tonumber(value) or 0
+      else
+        result[key] = value
+      end
+    end
+  end
+  if extras then
+    for k, v in pairs(extras) do
+      result[k] = v
+    end
+  end
+  return result
+end
+
+return M
+
+
diff --git a/common/luaUtilities/team_transfer/team_transfer_unsynced.lua b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
new file mode 100644
index 0000000000..e26564dc24
--- /dev/null
+++ b/common/luaUtilities/team_transfer/team_transfer_unsynced.lua
@@ -0,0 +1,181 @@
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
+local TeamTransferCache = VFS.Include("common/luaUtilities/team_transfer/team_transfer_cache.lua")
+
+local ResourceComms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
+local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
+
+local metalPolicyScratch = {}
+local energyPolicyScratch = {}
+
+local METAL_POLICY_PREFIX = "metalPolicy_"
+local ENERGY_POLICY_PREFIX = "energyPolicy_"
+
+local ResourceWidgets = {
+  CalculateSenderTaxedAmount = ResourceShared.CalculateSenderTaxedAmount,
+  CommunicationCase = SharedEnums.ResourceCommunicationCase,
+  DecideCommunicationCase = ResourceShared.DecideCommunicationCase,
+  GetCachedPolicyResult = ResourceShared.GetCachedPolicyResult,
+  ResourceTypes = SharedEnums.ResourceTypes,
+  TooltipText = ResourceComms.TooltipText,
+  SendTransferChatMessages = ResourceComms.SendTransferChatMessages,
+}
+ResourceWidgets.__index = ResourceWidgets
+
+--------------------------------------------------------
+--- Resource Transfer
+--------------------------------------------------------
+
+--- Get policy result and pascal resource type for a player
+---@param player table
+---@param resourceType string
+---@param senderTeamId number
+---@return ResourcePolicyResult policyResult, string pascalResourceType
+function ResourceWidgets.GetPlayerPolicy(player, resourceType, senderTeamId)
+  local pascalResourceType = resourceType:gsub("^%l", string.upper)
+  local prefix = resourceType == "metal" and METAL_POLICY_PREFIX or ENERGY_POLICY_PREFIX
+  local policyResult = ResourceWidgets.UnpackPolicyResult(player, prefix, senderTeamId, player.team)
+  return policyResult, pascalResourceType
+end
+
+--- Handle resource transfer logic
+---@param targetPlayer table
+---@param resourceType string
+---@param shareAmount number
+---@param senderTeamId number
+function ResourceWidgets.HandleResourceTransfer(targetPlayer, resourceType, shareAmount, senderTeamId)
+  local policyResult, pascalResourceType = ResourceWidgets.GetPlayerPolicy(targetPlayer, resourceType, senderTeamId)
+
+  local case = ResourceWidgets.DecideCommunicationCase(policyResult)
+
+  if case == ResourceWidgets.CommunicationCase.OnSelf then
+    if shareAmount > 0 then
+      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount=' .. shareAmount)
+    else
+      Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
+    end
+  end
+
+  if shareAmount and shareAmount > 0 then
+    Spring.ShareResources(targetPlayer.team, resourceType, shareAmount)
+  end
+end
+
+--------------------------------------------------------
+--- gui_advplayerlist.lua helper functions
+--------------------------------------------------------
+
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return ResourcePolicyResult? metalPolicy, ResourcePolicyResult? energyPolicy, UnitTransferPolicyResult? unitPolicy
+function TeamTransfer.UnpackAllPolicies(playerData, senderTeamId, receiverTeamId)
+  local hasPackedData = playerData[METAL_POLICY_PREFIX .. "canShare"] ~= nil
+  if not hasPackedData then return nil, nil, nil end
+
+  local metalPolicy = TeamTransfer.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
+  local energyPolicy = TeamTransfer.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
+
+  return metalPolicy, energyPolicy
+end
+
+
+---This and its sibling hydrate existing tables with a policyResult so we don't thrash GC
+---@param transferCategory string SharedEnums.TransferCategory
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+function TeamTransfer.UnpackPolicyResult(transferCategory, playerData, senderTeamId, receiverTeamId)
+  local scratch, fields, prefix
+  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
+    scratch = metalPolicyScratch
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = METAL_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
+    scratch = energyPolicyScratch
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = ENERGY_POLICY_PREFIX
+  end
+  scratch.senderTeamId = senderTeamId
+  scratch.receiverTeamId = receiverTeamId
+  for field, _ in pairs(fields) do
+    scratch[field] = playerData[prefix .. field]
+  end
+  return scratch
+end
+
+---Unpack metal policy result from player data
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return ResourcePolicyResult
+function ResourceWidgets.UnpackMetalPolicyResult(playerData, senderTeamId, receiverTeamId)
+  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, playerData, senderTeamId,
+    receiverTeamId)
+end
+
+---Unpack energy policy result from player data
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return ResourcePolicyResult
+function ResourceWidgets.UnpackEnergyPolicyResult(playerData, senderTeamId, receiverTeamId)
+  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, playerData, senderTeamId,
+    receiverTeamId)
+end
+
+---Unpack unit policy result from player data
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+---@return UnitTransferPolicyResult
+function UnitWidgets.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
+  return TeamTransfer.UnpackPolicyResult(SharedEnums.TransferCategory.UnitTransfer, playerData, senderTeamId,
+    receiverTeamId)
+end
+
+---Pack policy result for a given transfer category
+---@param transferCategory string SharedEnums.TransferCategory
+---@param policy table
+---@param playerData table
+function TeamTransfer.PackPolicyResult(transferCategory, policy, playerData)
+  local fields, prefix
+  if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = METAL_POLICY_PREFIX
+  elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
+    fields = ResourceShared.ResourcePolicyFields
+    prefix = ENERGY_POLICY_PREFIX
+  end
+  for field, _ in pairs(fields) do
+    playerData[prefix .. field] = policy[field]
+  end
+end
+
+---Pack metal policy result into player data
+---@param senderTeamId number
+---@param receiverTeamId number
+---@param playerData table
+function TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
+  local policy = ResourceWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId, "metal")
+  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.MetalTransfer, policy, playerData)
+end
+
+---Pack energy policy result into player data
+---@param senderTeamId number
+---@param receiverTeamId number
+---@param playerData table
+function TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
+  local policy = ResourceWidgets.GetCachedPolicyResult(senderTeamId, receiverTeamId, "energy")
+  TeamTransfer.PackPolicyResult(SharedEnums.TransferCategory.EnergyTransfer, policy, playerData)
+end
+
+--- Pack all policies for a given player
+---@param playerData table
+---@param senderTeamId number
+---@param receiverTeamId number
+function TeamTransfer.PackAllPoliciesForPlayer(playerData, senderTeamId, receiverTeamId)
+  TeamTransfer.PackMetalPolicyResult(senderTeamId, receiverTeamId, playerData)
+  TeamTransfer.PackEnergyPolicyResult(senderTeamId, receiverTeamId, playerData)
+end
+
+return TeamTransfer
diff --git a/language/en/interface.json b/language/en/interface.json
index c498da8d1d..1ea02dffed 100644
--- a/language/en/interface.json
+++ b/language/en/interface.json
@@ -86,7 +86,11 @@
 			"requestEnergy": "Click-and-drag to ask for energy",
 			"shareUnits": "Double-click to share units",
 			"shareMetal": "Click-and-drag to share metal",
+			"shareMetalTaxed": "Click-and-drag to share metal, receivable: %{amountReceivable}m, spendable: %{amountSendable}m at %{taxRatePercentage}%%",
+			"shareMetalTaxedThreshold": "Click-and-drag to share metal, receivable: %{amountReceivable}m, spendable: %{amountSendable}m at %{taxRatePercentage}%% (free used %{sentAmountUntaxed}/%{resourceShareThreshold}m)",
 			"shareEnergy": "Click-and-drag to share energy",
+			"shareEnergyTaxed": "Click-and-drag to share energy, receivable: %{amountReceivable}e, spendable: %{amountSendable}e at %{taxRatePercentage}%%",
+			"shareEnergyTaxedThreshold": "Click-and-drag to share energy, receivable: %{amountReceivable}e, spendable: %{amountSendable}e at %{taxRatePercentage}%% (free used %{sentAmountUntaxed}/%{resourceShareThreshold}e)",
 			"becomeEnemy": "Click to become enemy",
 			"becomeAlly": "Click to become ally",
 			"thousands": "%{number}k",
@@ -109,6 +113,12 @@
 				"needEnergyAmount": "I need %{amount} energy!",
 				"giveMetal": "I sent %{amount} metal to %{name}",
 				"giveEnergy": "I sent %{amount} energy to %{name}",
+				"sentMetal": "Sent %{receivedAmount}m",
+				"sentMetalTaxed": "Sent %{receivedAmount}m, spent %{sentAmount}m at %{taxRatePercentage}% overhead",
+				"sentMetalTaxedThreshold": "Sent %{receivedAmount}m, spent %{sentAmount}m at %{taxRatePercentage}% overhead (free used %{sentAmountUntaxed}/%{resourceShareThreshold}m)",
+				"sentEnergy": "Sent %{receivedAmount}e",
+				"sentEnergyTaxed": "Sent %{receivedAmount}e, spent %{sentAmount}e at %{taxRatePercentage}% overhead",
+				"sentEnergyTaxedThreshold": "Sent %{receivedAmount}e, spent %{sentAmount}e at %{taxRatePercentage}% overhead (free used %{sentAmountUntaxed}/%{resourceShareThreshold}e)",
 				"takeTeam": "I took %{name}.",
 				"takeTeamAmount": "I took %{name}: %{units} units, %{energy} energy and %{metal} metal."
 			}
diff --git a/luarules/gadgets/game_no_share_to_enemy.lua b/luarules/gadgets/game_no_share_to_enemy.lua
deleted file mode 100644
index d18cbcdd2a..0000000000
--- a/luarules/gadgets/game_no_share_to_enemy.lua
+++ /dev/null
@@ -1,49 +0,0 @@
-local gadget = gadget ---@type Gadget
-
-function gadget:GetInfo()
-    return {
-        name      = "game_no_share_to_enemy",
-        desc      = "Disallows sharing to enemies",
-        author    = "TheFatController",
-        date      = "19 Jan 2008",
-        license   = "GNU GPL, v2 or later",
-        layer     = 0,
-        enabled   = true
-    }
-end
-
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
-
-if not gadgetHandler:IsSyncedCode() then
-    return
-end
-
-local AreTeamsAllied = Spring.AreTeamsAllied
-local IsCheatingEnabled = Spring.IsCheatingEnabled
-
-local isNonPlayerTeam = { [Spring.GetGaiaTeamID()] = true }
-local teams = Spring.GetTeamList()
-for i=1,#teams do
-    local _,_,_,isAiTeam = Spring.GetTeamInfo(teams[i],false)
-    local isLuaAI = (Spring.GetTeamLuaAI(teams[i]) ~= nil)
-    if isAiTeam or isLuaAI then
-        isNonPlayerTeam[teams[i]] = true
-    end
-end
-
-function gadget:AllowResourceTransfer(oldTeam, newTeam, type, amount)
-    if isNonPlayerTeam[oldTeam] or AreTeamsAllied(newTeam, oldTeam) or IsCheatingEnabled() then
-        return true
-    end
-
-    return false
-end
-
-function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
-    if isNonPlayerTeam[oldTeam] or AreTeamsAllied(newTeam, oldTeam) or capture or IsCheatingEnabled() then
-        return true
-    end
-
-    return false
-end
\ No newline at end of file
diff --git a/luarules/gadgets/game_prevent_excessive_share.lua b/luarules/gadgets/game_prevent_excessive_share.lua
deleted file mode 100644
index 2b8a588558..0000000000
--- a/luarules/gadgets/game_prevent_excessive_share.lua
+++ /dev/null
@@ -1,63 +0,0 @@
-local gadget = gadget ---@type Gadget
-
-function gadget:GetInfo()
-	return {
-		name    = 'Prevent Excessive Share',
-		desc    = 'Prevents sharing more resources or units than the receiver can hold',
-		author  = 'Niobium',
-		date    = 'April 2012',
-		license = 'GNU GPL, v2 or later',
-		layer   = 2, -- after 'Tax Resource Sharing'
-		enabled = true
-	}
-end
-
-----------------------------------------------------------------
--- Synced only
-----------------------------------------------------------------
-if not gadgetHandler:IsSyncedCode() then
-	return false
-end
-
-local spIsCheatingEnabled = Spring.IsCheatingEnabled
-local spGetTeamUnitCount = Spring.GetTeamUnitCount
-
-----------------------------------------------------------------
--- Callins
-----------------------------------------------------------------
-function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
-	-- Spring uses 'm' and 'e' instead of the full names that we need, so we need to convert the resourceType
-	-- We also check for 'metal' or 'energy' incase Spring decides to use those in a later version
-	local resourceName
-	if (resourceType == 'm') or (resourceType == 'metal') then
-		resourceName = 'metal'
-	elseif (resourceType == 'e') or (resourceType == 'energy') then
-		resourceName = 'energy'
-	else
-		-- We don't handle whatever this resource is, allow it
-		return true
-	end
-
-	-- Calculate the maximum amount the receiver can receive
-	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
-	local maxShare = rStor * rShare - rCur
-
-	-- Is the sender trying to send more than the maximum? Block it, possibly sending a reduced amount instead
-	if amount > maxShare then
-		if maxShare > 0 then
-			Spring.ShareTeamResource(senderTeamId, receiverTeamId, resourceName, maxShare)
-		end
-		return false
-	end
-
-	-- Allow anything we don't explictly block
-	return true
-end
-
-function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
-	local unitCount = spGetTeamUnitCount(newTeam)
-	if capture or spIsCheatingEnabled() or unitCount < Spring.GetTeamMaxUnits(newTeam) then
-		return true
-	end
-	return false
-end
diff --git a/luarules/gadgets/game_tax_resource_sharing.lua b/luarules/gadgets/game_tax_resource_sharing.lua
index d5f41c4dde..d369f3b1cf 100644
--- a/luarules/gadgets/game_tax_resource_sharing.lua
+++ b/luarules/gadgets/game_tax_resource_sharing.lua
@@ -1,106 +1,164 @@
 local gadget = gadget ---@type Gadget
 
 function gadget:GetInfo()
-	return {
-		name    = 'Tax Resource Sharing',
-		desc    = 'Tax Resource Sharing when modoption enabled. Modified from "Prevent Excessive Share" by Niobium', -- taxing overflow needs to be handled by the engine 
-		author  = 'Rimilel',
-		date    = 'April 2024',
-		license = 'GNU GPL, v2 or later',
-		layer   = 1, -- Needs to occur before "Prevent Excessive Share" since their restriction on AllowResourceTransfer is not compatible
-		enabled = true
-	}
+  return {
+    name    = 'Tax Resource Sharing',
+    desc    = 'Tax Resource Sharing when modoption enabled. Modified from "Prevent Excessive Share" by Niobium', -- taxing overflow needs to be handled by the engine
+    author  = 'Rimilel, Attean',
+    date    = 'April 2024',
+    license = 'GNU GPL, v2 or later',
+    layer   = 1, -- Needs to occur before "Prevent Excessive Share" since their restriction on AllowResourceTransfer is not compatible
+    enabled = true
+  }
 end
 
+local POLICY_CACHE_TAINT_FRAME_RATE = 30 -- every 1 second to keep up with overflow detection
+
 ----------------------------------------------------------------
 -- Synced only
 ----------------------------------------------------------------
 if not gadgetHandler:IsSyncedCode() then
-	return false
-end
-if Spring.GetModOptions().tax_resource_sharing_amount == 0 then
-	return false
+  return false
 end
 
-local spIsCheatingEnabled = Spring.IsCheatingEnabled
-local spGetTeamUnitCount = Spring.GetTeamUnitCount
+local sharingTax = tonumber(Spring.GetModOptions().tax_resource_sharing_amount) or 0
+local energyTaxThreshold = tonumber(Spring.GetModOptions().player_energy_send_threshold) or 0
+local metalTaxThreshold = tonumber(Spring.GetModOptions().player_metal_send_threshold) or 0
 
-local gameMaxUnits = math.min(Spring.GetModOptions().maxunits, math.floor(32000 / #Spring.GetTeamList()))
+local ResourceTransfer = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_synced.lua")
+local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
+local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
+local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
+local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
 
-local sharingTax = Spring.GetModOptions().tax_resource_sharing_amount
+local RESOURCE_TYPES = SharedEnums.ResourceTypes
+local contextFactory = ContextFactoryModule.create(Spring)
+local policyResultFactory = ResourceTransfer.BuildResultFactory(sharingTax, metalTaxThreshold, energyTaxThreshold)
+
+local lastGameFrameCacheUpdate = 0
 
 ----------------------------------------------------------------
--- Callins
+-- Initialization
 ----------------------------------------------------------------
 
+---@param policyContext PolicyContext
+---@param resourceType ResourceType
+---@return ResourcePolicyResult
+function BuildPolicyCache(policyContext, resourceType)
+  local policyResult = policyResultFactory(policyContext, resourceType)
+  ResourceTransfer.CachePolicyResult(
+    Spring,
+    policyContext.senderTeamId,
+    policyContext.receiverTeamId,
+    resourceType,
+    policyResult
+  )
+  return policyResult
+end
+
+local function InitializeNewTeam(senderTeamId, receiverTeamId)
+  local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
+  for _, resourceType in ipairs(RESOURCE_TYPES) do
+    local param = Shared.GetCumulativeParam(resourceType)
+    Spring.SetTeamRulesParam(senderTeamId, param, 0)
+    BuildPolicyCache(ctx, resourceType)
+  end
+end
 
+function gadget:Initialize()
+  local teamList = Spring.GetTeamList() or {}
+
+  for _, senderTeamId in ipairs(teamList) do
+    for _, receiverTeamId in ipairs(teamList) do
+      InitializeNewTeam(senderTeamId, receiverTeamId)
+    end
+  end
+  lastGameFrameCacheUpdate = Spring.GetGameFrame()
+end
+
+--------------------------------------------------------------
+-- Callins
+--------------------------------------------------------------
 
 function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
+  local resType = (resourceType == 'm' or resourceType == 'metal') and SharedEnums.ResourceType.METAL or
+      SharedEnums.ResourceType.ENERGY
+  local policyResult = Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId, resType)
+  local ctx = contextFactory.resourceTransfer(senderTeamId, receiverTeamId, resType, amount, policyResult)
+
+  local transferResult = ResourceTransfer.ResourceTransfer(ctx)
+  ResourceTransfer.RegisterPostTransfer(ctx, transferResult)
 
-	-- Spring uses 'm' and 'e' instead of the full names that we need, so we need to convert the resourceType
-	-- We also check for 'metal' or 'energy' incase Spring decides to use those in a later version
-	local resourceName
-	if (resourceType == 'm') or (resourceType == 'metal') then
-		resourceName = 'metal'
-	elseif (resourceType == 'e') or (resourceType == 'energy') then
-		resourceName = 'energy'
-	else
-		-- We don't handle whatever this resource is, allow it
-		return true
-	end
-
-	-- Calculate the maximum amount the receiver can receive
-	--Current, Storage, Pull, Income, Expense
-	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
-
-	-- rShare is the share slider setting, don't exceed their share slider max when sharing
-	local maxShare = rStor * rShare - rCur
-
-	local taxedAmount = math.min((1-sharingTax)*amount, maxShare)
-	local totalAmount = taxedAmount / (1-sharingTax)
-	local transferTax = totalAmount * sharingTax
-
-	Spring.SetTeamResource(receiverTeamId, resourceName, rCur+taxedAmount)
-	local sCur, _, _, _, _, _ = Spring.GetTeamResources(senderTeamId, resourceName)
-	Spring.SetTeamResource(senderTeamId, resourceName, sCur-totalAmount)
-
-	-- Block the original transfer
-	return false
+  -- immediately rebuild the cache for this resource
+  local policyCtx = contextFactory.policy(senderTeamId, receiverTeamId)
+  local frame = Spring.GetGameFrame()
+  local updatedPolicyResult = BuildPolicyCache(policyCtx, resType)
+  Comms.SendTransferChatMessages(transferResult, updatedPolicyResult)
+
+  return false
 end
 
-function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
-	local unitCount = spGetTeamUnitCount(newTeam)
-	if capture or spIsCheatingEnabled() or unitCount < gameMaxUnits then
-		return true
-	end
-	return false
+function gadget:GameFrame(frame)
+  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
+  if frame < nextSchedHeavy then
+    return
+  end
+  local teamList = Spring.GetTeamList() or {}
+  lastGameFrameCacheUpdate = frame
+  for _, senderTeamId in ipairs(teamList) do
+    -- we also calculate me -> me for standardized resource request limits
+    for _, receiverTeamId in ipairs(teamList) do
+      local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
+      for _, resourceType in ipairs(RESOURCE_TYPES) do
+        BuildPolicyCache(ctx, resourceType)
+      end
+    end
+  end
 end
 
+-- Keep cache in sync with roster changes
+function gadget:PlayerAdded(playerID)
+  local frame = Spring.GetGameFrame()
+  local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
+  if teamID then
+    for _, receiverTeamId in ipairs(Spring.GetTeamList() or {}) do
+      InitializeNewTeam(teamID, receiverTeamId)
+    end
+  end
+end
 
 function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
-	-- Disallow reclaiming allied units for metal
-	if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
-		local targetID = cmdParams[1]
-		local targetTeam
-		if(targetID >= Game.maxUnits) then
-			return true
-		end
-		targetTeam = Spring.GetUnitTeam(targetID)
-		if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
-			return false
-		end
-	-- Also block guarding allied units that can reclaim
-	elseif (cmdID == CMD.GUARD) then
-		local targetID = cmdParams[1]
-		local targetTeam = Spring.GetUnitTeam(targetID)
-		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
-
-		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
-			-- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
-			if targetUnitDef.canReclaim then
-				return false
-			end
-		end
-	end
-	return true
-end
\ No newline at end of file
+  -- Disallow reclaiming allied units for metal
+  if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
+    local targetID = cmdParams[1]
+    local targetTeam
+    if (targetID >= Game.maxUnits) then
+      return true
+    end
+
+    targetTeam = Spring.GetUnitTeam(targetID)
+    if targetTeam == nil then
+      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
+    end
+
+    if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
+      return false
+    end
+  elseif (cmdID == CMD.GUARD) then -- Also block guarding allied units that can reclaim
+    local targetID = cmdParams[1]
+    local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
+
+    local targetTeam = Spring.GetUnitTeam(targetID)
+    if targetTeam == nil then
+      return true -- because what is going on this shouldn't happen+it being nullable was breaking the linter
+    end
+
+    if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
+      -- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
+      if targetUnitDef.canReclaim then
+        return false
+      end
+    end
+  end
+  return true
+end
diff --git a/luarules/gadgets/unit_prevent_share_load.lua b/luarules/gadgets/unit_prevent_share_load.lua
index dbab2f0ecb..1da385e860 100644
--- a/luarules/gadgets/unit_prevent_share_load.lua
+++ b/luarules/gadgets/unit_prevent_share_load.lua
@@ -18,6 +18,6 @@ if not gadgetHandler:IsSyncedCode() then
 end
 
 function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
-	Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.LOAD_UNITS }, { "alt" })
-	return true
+  Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.LOAD_UNITS }, { "alt" })
+  return true
 end
diff --git a/luaui/Widgets/cmd_share_unit.lua b/luaui/Widgets/cmd_share_unit.lua
index 932b5c0454..73bb2396d5 100644
--- a/luaui/Widgets/cmd_share_unit.lua
+++ b/luaui/Widgets/cmd_share_unit.lua
@@ -14,6 +14,8 @@ function widget:GetInfo()
 	}
 end
 
+local TeamTransfer = VFS.Include("common/luaUtilities/team_transfer/team_transfer_unsynced.lua")
+
 --------------------------------------------------------------------------------
 --vars
 --------------------------------------------------------------------------------
@@ -336,8 +338,8 @@ function widget:CommandNotify(cmdID, cmdParams, _)
 			targetTeamID = findTeamInArea(mouseX, mouseY)
 		end
 
-		if targetTeamID == nil or targetTeamID == myTeamID or GetTeamAllyTeamID(targetTeamID) ~= myAllyTeamID then
-			-- invalid target, don't do anything
+		local policyResult = TeamTransfer.Units.GetCachedPolicyResult(myTeamID, targetTeamID)
+		if not policyResult or not policyResult.canShare then
 			return true
 		end
 
diff --git a/luaui/Widgets/gui_advplayerslist.lua b/luaui/Widgets/gui_advplayerslist.lua
index d869d339b7..ddd01852cd 100644
--- a/luaui/Widgets/gui_advplayerslist.lua
+++ b/luaui/Widgets/gui_advplayerslist.lua
@@ -57,8 +57,13 @@ end
 	v44   (Floris): added rendertotexture draw method
 	v45   (Floris): support PvE team ranking leaderboard style
 	v46   (Floris): support alternative (historic) playernames based on accountID's
+    v47   (Attean): introduce a policy cache and TeamTransfer module, removing a lot of economic and unit specific code from this file and enabling unit_sharing_mode and player_[resource]_send_threshold modoptions
 ]]--
 
+local SharedEnums = VFS.Include('common/luaUtilities/team_transfer/shared_enums.lua')
+local TeamTransfer = VFS.Include('common/luaUtilities/team_transfer/team_transfer_unsynced.lua')
+local ResourceTransfer = TeamTransfer.Resources
+
 --------------------------------------------------------------------------------
 -- Config
 --------------------------------------------------------------------------------
@@ -287,7 +292,6 @@ end
 local energyPlayer    -- player to share energy with (nil when no energy sharing)
 local metalPlayer    -- player to share metal with(nil when no metal sharing)
 local shareAmount = 0      -- amount of metal/energy to share/ask
-local maxShareAmount    -- max amount of metal/energy to share/ask
 local sliderPosition      -- slider position in metal and energy sharing
 local shareSliderHeight = 80
 local sliderOrigin   -- position of the cursor before dragging the widget
@@ -1319,7 +1323,7 @@ function CreatePlayerFromTeam(teamID)
         metal = metal,
         metalStorage = metalStorage,
         metalShare = metalShare,
-        incomeMultiplier = tincomeMultiplier,
+        incomeMultiplier = tincomeMultiplier
     }
 end
 
@@ -1371,6 +1375,9 @@ function UpdatePlayerResources()
 				end
 			end
         end
+        if player[playerID].team then
+            TeamTransfer.PackAllPoliciesForPlayer(player[playerID], myTeamID, player[playerID].team)
+        end
     end
 
     updateRateMult = math.clamp(displayedPlayers*0.05, 1, 2)
@@ -1874,37 +1881,25 @@ end
 --  Main (player) gllist
 ---------------------------------------------------------------------------------------------------
 
+local function updateShareAmount(player, resourceType)
+    local policyResult = ResourceTransfer.GetPlayerPolicy(player, resourceType, myTeamID)
+    if not policyResult.amountSendable then
+        shareAmount = 0
+        return
+    end
+    shareAmount = policyResult.amountSendable * sliderPosition / shareSliderHeight
+    shareAmount = shareAmount - (shareAmount % 1)
+end
+
 function UpdateResources()
     if sliderPosition then
         if energyPlayer ~= nil then
-			if energyPlayer.team == myTeamID then
-				local current, storage = Spring_GetTeamResources(myTeamID, "energy")
-				maxShareAmount = storage - current
-				shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
-				shareAmount = shareAmount - (shareAmount % 1)
-			else
-				maxShareAmount = Spring_GetTeamResources(myTeamID, "energy")
-				local energy, energyStorage, _, _, _, shareSliderPos = Spring_GetTeamResources(energyPlayer.team, "energy")
-				maxShareAmount = math.min(maxShareAmount, ((energyStorage*shareSliderPos) - energy))
-                shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
-                shareAmount = shareAmount - (shareAmount % 1)
-            end
+            updateShareAmount(energyPlayer, "energy")
         end
 
-        if metalPlayer ~= nil then
-            if metalPlayer.team == myTeamID then
-                local current, storage = Spring_GetTeamResources(myTeamID, "metal")
-                maxShareAmount = storage - current
-                shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
-                shareAmount = shareAmount - (shareAmount % 1)
-            else
-                maxShareAmount = Spring_GetTeamResources(myTeamID, "metal")
-				local metal, metalStorage, _, _, _, shareSliderPos = Spring_GetTeamResources(metalPlayer.team, "metal")
-				maxShareAmount = math.min(maxShareAmount, ((metalStorage*shareSliderPos) - metal))
-                shareAmount = maxShareAmount * sliderPosition / shareSliderHeight
-                shareAmount = shareAmount - (shareAmount % 1)
-            end
-        end
+		if metalPlayer ~= nil then
+            updateShareAmount(metalPlayer, "metal")
+		end
     end
 end
 
@@ -2212,11 +2207,13 @@ function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY, onlyMainList, onl
     local cpu = player[playerID].cpu
     local spec = player[playerID].spec
     local totake = player[playerID].totake
-    local needm = player[playerID].needm
-    local neede = player[playerID].neede
     local dead = player[playerID].dead
     local ai = player[playerID].ai
     local alliances = player[playerID].alliances
+    local metalPolicy, energyPolicy
+    if not spec then
+        metalPolicy, energyPolicy = ResourceTransfer.GetAllPolicies(player[playerID], myTeamID, team)
+    end
     local posY = widgetPosY + widgetHeight - vOffset
     local tipPosY = widgetPosY + ((widgetHeight - vOffset) * widgetScale)
 	local desynced = player[playerID].desynced
@@ -2276,10 +2273,10 @@ function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY, onlyMainList, onl
                                 end
                             end
                         end
-                        if m_share.active and not dead and not hideShareIcons then
-                            DrawShareButtons(posY, needm, neede)
+                        if m_share.active and not dead and not hideShareIcons and (metalPolicy and energyPolicy) then
+                            DrawShareButtons(posY, metalPolicy, energyPolicy)
                             if tipY then
-                                ShareTip(mouseX, playerID)
+                                ShareTip(mouseX, metalPolicy, energyPolicy)
                             end
                         end
                     end
@@ -2414,7 +2411,25 @@ function DrawTakeSignal(posY)
     end
 end
 
-function DrawShareButtons(posY, needm, neede)
+local function DrawSharingIconOverlay(posY, enabled, offsetX)
+    -- Subtle highlight when sharing is possible (replaces red lowPic overlay)
+    if enabled then
+        gl_Texture(false)
+        gl_Color(1, 1, 1, 0.12)
+        DrawRect(m_share.posX + widgetPosX + offsetX, posY, m_share.posX + widgetPosX + offsetX + (16*playerScale), posY + (16*playerScale))
+        gl_Color(1, 1, 1, 1)
+    end
+
+    -- Grey-out when sharing is not allowed
+    if not enabled then
+        gl_Texture(false)
+        gl_Color(0, 0, 0, 0.45)
+        DrawRect(m_share.posX + widgetPosX + offsetX, posY, m_share.posX + widgetPosX + offsetX + (16*playerScale), posY + (16*playerScale))
+        gl_Color(1, 1, 1, 1)
+    end
+end
+
+function DrawShareButtons(posY, unitPolicy, metalPolicy, energyPolicy)
     gl_Color(1, 1, 1, 1)
     gl_Texture(pics["unitsPic"])
     DrawRect(m_share.posX + widgetPosX + (1*playerScale), posY, m_share.posX + widgetPosX + (17*playerScale), posY + (16*playerScale))
@@ -2422,15 +2437,9 @@ function DrawShareButtons(posY, needm, neede)
     DrawRect(m_share.posX + widgetPosX + (17*playerScale), posY, m_share.posX + widgetPosX + (33*playerScale), posY + (16*playerScale))
     gl_Texture(pics["metalPic"])
     DrawRect(m_share.posX + widgetPosX + (33*playerScale), posY, m_share.posX + widgetPosX + (49*playerScale), posY + (16*playerScale))
-    gl_Texture(pics["lowPic"])
 
-    if needm then
-        DrawRect(m_share.posX + widgetPosX + (33*playerScale), posY, m_share.posX + widgetPosX + (49*playerScale), posY + (16*playerScale))
-    end
-
-    if neede then
-        DrawRect(m_share.posX + widgetPosX + (17*playerScale), posY, m_share.posX + widgetPosX + (33*playerScale), posY + (16*playerScale))
-    end
+    DrawSharingIconOverlay(posY, energyPolicy, 17 * playerScale)
+    DrawSharingIconOverlay(posY, metalPolicy, 33 * playerScale)
 
     gl_Texture(false)
 end
@@ -3037,30 +3046,19 @@ function NameTip(mouseX, playerID, accountID, nameIsAlias)
 	end
 end
 
-function ShareTip(mouseX, playerID)
-    if playerID == myPlayerID then
-        if mouseX >= widgetPosX + (m_share.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (17*playerScale)) * widgetScale then
-            tipText = Spring.I18N('ui.playersList.requestSupport')
-            tipTextTime = os.clock()
-        elseif mouseX >= widgetPosX + (m_share.posX + (19*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (35*playerScale)) * widgetScale then
-            tipText = Spring.I18N('ui.playersList.requestEnergy')
-            tipTextTime = os.clock()
-        elseif mouseX >= widgetPosX + (m_share.posX + (37*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (53*playerScale)) * widgetScale then
-            tipText = Spring.I18N('ui.playersList.requestMetal')
-            tipTextTime = os.clock()
-        end
-    else
-        if mouseX >= widgetPosX + (m_share.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (17*playerScale)) * widgetScale then
+function ShareTip(mouseX, metalPolicy, energyPolicy)
+    if mouseX >= widgetPosX + (m_share.posX + (1*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (17*playerScale)) * widgetScale then
+        if myPlayerID == metalPolicy.receiverTeamId then
+            tipText = Spring.I18N('ui.playersList.shareUnits')
+        else
             tipText = Spring.I18N('ui.playersList.shareUnits')
-            tipTextTime = os.clock()
-        elseif mouseX >= widgetPosX + (m_share.posX + (19*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (35*playerScale)) * widgetScale then
-            tipText = Spring.I18N('ui.playersList.shareEnergy')
-            tipTextTime = os.clock()
-        elseif mouseX >= widgetPosX + (m_share.posX + (37*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (53*playerScale)) * widgetScale then
-            tipText = Spring.I18N('ui.playersList.shareMetal')
-            tipTextTime = os.clock()
         end
+    elseif mouseX >= widgetPosX + (m_share.posX + (19*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (35*playerScale)) * widgetScale then
+        tipText = ResourceTransfer.TooltipText(energyPolicy)
+    elseif mouseX >= widgetPosX + (m_share.posX + (37*playerScale)) * widgetScale and mouseX <= widgetPosX + (m_share.posX + (53*playerScale)) * widgetScale then
+        tipText = ResourceTransfer.TooltipText(metalPolicy)
     end
+    tipTextTime = os.clock()
 end
 
 function AllyTip(mouseX, playerID)
@@ -3188,16 +3186,49 @@ end
 --  Share slider gllist
 ---------------------------------------------------------------------------------------------------
 
+local function RenderShareSliderText(posY, player, resourceType, baseOffset)
+    local policyResult = ResourceTransfer.GetPlayerPolicy(player, resourceType, myTeamID)
+    local case = ResourceTransfer.DecideCommunicationCase(policyResult)
+    local label
+    if case == ResourceTransfer.CommunicationCase.OnTaxFree then
+        -- For tax-free sharing, just show the amount being shared
+        label = ResourceTransfer.FormatNumberForUI(shareAmount)
+    else
+        -- For taxed cases, show explicit sent -> received breakdown
+        local received, sent = ResourceTransfer.CalculateSenderTaxedAmount(policyResult, shareAmount)
+        label = "S:" .. ResourceTransfer.FormatNumberForUI(sent) .. "→R:" .. ResourceTransfer.FormatNumberForUI(received)
+    end
+    local textXRight = m_share.posX + widgetPosX + (baseOffset * playerScale) - (4 * playerScale)
+    local fontSize = 14
+    local pad = 4 * playerScale
+    local textWidth = font:GetTextWidth(label) * fontSize
+    local bgLeft = math.floor(textXRight - textWidth - pad)
+    local bgRight = math.floor(textXRight + pad)
+    local bgBottom = math.floor(posY - 1 + sliderPosition)
+    local bgTop = math.floor(posY + (17*playerScale) + sliderPosition)
+    gl_Color(0.45,0.45,0.45,1)
+    RectRound(bgLeft, bgBottom, bgRight, bgTop, 2.5*playerScale)
+    font:Print("\255\255\255\255"..label, textXRight, posY + (3 * playerScale) + sliderPosition, fontSize, "or")
+end
+
 function CreateShareSlider()
     if ShareSlider then
         gl_DeleteList(ShareSlider)
     end
 
+    -- Refresh policy data for focused players before drawing
+    if energyPlayer then
+        TeamTransfer.PackMetalPolicyResult(energyPlayer.team, myTeamID, energyPlayer)
+    elseif metalPlayer then
+        TeamTransfer.PackEnergyPolicyResult(metalPlayer.team, myTeamID, metalPlayer)
+    end
+
     ShareSlider = gl_CreateList(function()
 		gl_Color(1,1,1,1)
         if sliderPosition then
             font:Begin(useRenderToTexture)
             local posY
+
             if energyPlayer ~= nil then
                 posY = widgetPosY + widgetHeight - energyPlayer.posY
                 gl_Texture(pics["barPic"])
@@ -3205,9 +3236,7 @@ function CreateShareSlider()
                 gl_Texture(pics["energyPic"])
                 DrawRect(m_share.posX + widgetPosX + (17*playerScale), posY + sliderPosition, m_share.posX + widgetPosX + (33*playerScale), posY + (16*playerScale) + sliderPosition)
                 gl_Texture(false)
-				gl_Color(0.45,0.45,0.45,1)
-				RectRound(math.floor(m_share.posX + widgetPosX - (28*playerScale)), math.floor(posY - 1 + sliderPosition), math.floor(m_share.posX + widgetPosX + (19*playerScale)), math.floor(posY + (17*playerScale) + sliderPosition), 2.5*playerScale)
-				font:Print("\255\255\255\255"..shareAmount, m_share.posX + widgetPosX - (5*playerScale), posY + (3*playerScale) + sliderPosition, 14, "ocn")
+                RenderShareSliderText(posY, energyPlayer, "energy", 16)
             elseif metalPlayer ~= nil then
                 posY = widgetPosY + widgetHeight - metalPlayer.posY
                 gl_Texture(pics["barPic"])
@@ -3215,9 +3244,7 @@ function CreateShareSlider()
                 gl_Texture(pics["metalPic"])
                 DrawRect(m_share.posX + widgetPosX + (33*playerScale), posY + sliderPosition, m_share.posX + widgetPosX + (49*playerScale), posY + (16*playerScale) + sliderPosition)
                 gl_Texture(false)
-				gl_Color(0.45,0.45,0.45,1)
-				RectRound(math.floor(m_share.posX + widgetPosX - (12*playerScale)), math.floor(posY - 1 + sliderPosition), math.floor(m_share.posX + widgetPosX + (35*playerScale)), math.floor(posY + (17*playerScale) + sliderPosition), 2.5*playerScale)
-				font:Print("\255\255\255\255"..shareAmount, m_share.posX + widgetPosX + (11*playerScale), posY + (3*playerScale) + sliderPosition, 14, "ocn")
+                RenderShareSliderText(posY, metalPlayer, "metal", 32)
             end
             font:End()
         end
@@ -3455,6 +3482,34 @@ function widget:MouseMove(x, y, dx, dy, button)
     end
 end
 
+---@param receiverTeamId number
+---@param resourceType ResourceType
+local function handleResourceTransfer(receiverTeamId, resourceType)
+    local targetPlayer = (resourceType == "metal" and metalPlayer) or energyPlayer
+    local policyResult, pascalResourceType = ResourceTransfer.GetPlayerPolicy(targetPlayer, resourceType, myTeamID)
+
+    local case = ResourceTransfer.DecideCommunicationCase(policyResult)
+
+    if case == ResourceTransfer.CommunicationCase.OnSelf then
+      if shareAmount > 0 then
+          Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType .. 'Amount:amount='..shareAmount)
+        else
+          Spring.SendLuaRulesMsg('msg:ui.playersList.chat.need' .. pascalResourceType)
+        end
+    end
+
+    if shareAmount and shareAmount > 0 then
+        Spring_ShareResources(receiverTeamId, resourceType, shareAmount)
+        -- post-transfer messaging now handled by game_tax_resource_sharing.lua
+    end
+    
+    sliderOrigin = nil
+    sliderPosition = nil
+    shareAmount = 0
+    energyPlayer = nil
+    metalPlayer = nil
+end
+
 function widget:MouseRelease(x, y, button)
     if button == 1 then
         if firstclick ~= nil then
@@ -3464,49 +3519,13 @@ function widget:MouseRelease(x, y, button)
         else
             release = nil
         end
-        if energyPlayer ~= nil then
-            -- share energy/metal mouse release
-            if energyPlayer.team == myTeamID then
-                if shareAmount == 0 then
-                    --Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needEnergy'))
-					Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needEnergy')
-                else
-                    --Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needEnergyAmount', { amount = shareAmount }))
-					Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needEnergyAmount:amount='..shareAmount)
-                end
-            elseif shareAmount > 0 then
-                Spring_ShareResources(energyPlayer.team, "energy", shareAmount)
-                --Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveEnergy', { amount = shareAmount, name = energyPlayer.name }))
-				Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveEnergy:amount='..shareAmount..':name='..(energyPlayer.orgname or energyPlayer.name))
-                WG.sharedEnergyFrame = Spring.GetGameFrame()
-            end
-            sliderOrigin = nil
-            maxShareAmount = nil
-            sliderPosition = nil
-            shareAmount = nil
-            energyPlayer = nil
+
+        if energyPlayer ~= nil and shareAmount then
+            handleResourceTransfer(energyPlayer.team, "energy")
         end
 
         if metalPlayer ~= nil and shareAmount then
-            if metalPlayer.team == myTeamID then
-                if shareAmount == 0 then
-                    --Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needMetal'))
-					Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needMetal')
-                else
-                    --Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.needMetalAmount', { amount = shareAmount }))
-					Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needMetalAmount:amount='..shareAmount)
-                end
-            elseif shareAmount > 0 then
-                Spring_ShareResources(metalPlayer.team, "metal", shareAmount)
-                --Spring_SendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveMetal', { amount = shareAmount, name = metalPlayer.name }))
-				Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveMetal:amount='..shareAmount..':name='..(metalPlayer.orgname or metalPlayer.name))
-                WG.sharedMetalFrame = Spring.GetGameFrame()
-            end
-            sliderOrigin = nil
-            maxShareAmount = nil
-            sliderPosition = nil
-            shareAmount = nil
-            metalPlayer = nil
+            handleResourceTransfer(metalPlayer.team, "metal")
         end
     end
 end
@@ -3740,12 +3759,7 @@ function CheckPlayersChange()
             end
             -- Update stall / cpu / ping info for each player
             if player[i].spec == false then
-                player[i].needm = GetNeed("metal", player[i].team)
-                player[i].neede = GetNeed("energy", player[i].team)
                 player[i].rank = rank
-            else
-                player[i].needm = false
-                player[i].neede = false
             end
 
             player[i].pingLvl = GetPingLvl(pingTime)
@@ -3774,18 +3788,6 @@ function CheckPlayersChange()
     end
 end
 
-function GetNeed(resType, teamID)
-    local current, _, pull, income = Spring_GetTeamResources(teamID, resType)
-    if current == nil then
-        return false
-    end
-    local loss = pull - income
-    if loss > 0 and loss * 5 > current then
-        return true
-    end
-    return false
-end
-
 function updateTake(allyTeamID)
     for i = 0, teamN - 1 do
         if player[i + specOffset].allyTeam == allyTeamID then
diff --git a/modoptions.lua b/modoptions.lua
index 1b3c3103ca..d1bc77a49c 100644
--- a/modoptions.lua
+++ b/modoptions.lua
@@ -281,10 +281,31 @@ local options = {
 		column	= 1,
 	},
 	{
-		key		= "disable_unit_sharing",
-		name	= "Disable Unit Sharing",
-		desc	= "Disable sharing units and structures to allies",
-		type	= "bool",
+		key     = "player_metal_send_threshold",
+		name    = "Player Metal Send Threshold",
+		desc    = "Max total metal a player can send tax-free cumulatively. Tax applies to amounts sent *after* this limit is reached. Set to 0 for immediate tax (if rate > 0).",
+		type    = "number",
+		def     = 0,
+		min     = 0,
+		max     = 100000,
+		step    = 10,
+		section = "options_main",
+		column  = 1,
+		disabled= { key="tax_resource_sharing_amount", value = 0},
+	},
+	{
+		key     = "player_energy_send_threshold",
+		name    = "Player Energy Send Threshold",
+		desc    = "Max total energy a player can send tax-free cumulatively. Tax applies to amounts sent *after* this limit is reached. Set to 0 for immediate tax (if rate > 0).",
+		type    = "number",
+		def     = 0,
+		min     = 0,
+		max     = 100000,
+		step    = 10,
+		section = "options_main",
+		column  = 2,
+		disabled= { key="tax_resource_sharing_amount", value = 0},
+	},
 		section	= "options_main",
 		def		= false,
 	},
@@ -295,7 +316,7 @@ local options = {
 		type	= "bool",
 		section	= "options_main",
 		def		=  false,
-		column	= 1.76,
+		column	= 1,
 	},
     {
         key     = "sub_header",
diff --git a/types/spring.lua b/types/spring.lua
new file mode 100644
index 0000000000..1ffa03d16c
--- /dev/null
+++ b/types/spring.lua
@@ -0,0 +1,20 @@
+-- It would be better if LuaSyncedCtrl published this interface for us, until then we cope
+---@class ISpring
+---@field CMD table Spring command constants
+---@field GetModOptions fun(): table
+---@field GetGameFrame fun(): number, any
+---@field IsCheatingEnabled fun(): boolean
+---@field Log fun(tag: string, level: string, msg: string)
+---@field GetTeamRulesParam fun(teamID: number, key: string): any
+---@field SetTeamRulesParam fun(teamID: number, key: string, value: any, losAccess: boolean?)
+---@field GetTeamResources fun(teamID: number, resourceType: string): number?, number?, number?, number?, number?, number?, number?, number?, number?
+---@field GetTeamList fun(): TeamInfo[]?
+---@field GetPlayerList fun(): number[]
+---@field GetPlayerListUnpacked fun(): TeamInfo[]?
+---@field GetPlayerIdsList fun(): number[]?
+---@field AreTeamsAllied fun(team1ID: number, team2ID: number): boolean
+---@field GetTeamUnits fun(teamID: number): number[]?
+---@field GetUnitTeam fun(unitID: number): number?
+---@field GetUnitDefID fun(unitID: number): number?
+---@field GiveOrderToUnit fun(unitID: number, commandID: number, params: table, options: table)
+---@field AddTeamResource fun(teamID: number, resourceType: string, amount: number)
diff --git a/types/team_transfer.lua b/types/team_transfer.lua
new file mode 100644
index 0000000000..7dc4c19f6a
--- /dev/null
+++ b/types/team_transfer.lua
@@ -0,0 +1,133 @@
+-- Team Transfer Type Definitions
+-- Minimal types focused on IntelliSense support and keeping the linter honest
+
+---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "guard_transfer" | "repair_transfer" | "reclaim_transfer"
+---@alias ResourceType "metal" | "energy"
+---@alias UnitValidationOutcome "success" | "disabled" | "partial_success"
+
+---@class ValidationResult
+---@field ok boolean
+---@field reason string?
+---@field translationTokens table?
+
+---@class PolicyResult
+---@field senderTeamId number
+---@field receiverTeamId number
+
+-- Unit Transfer Action
+
+---@class UnitTransferPolicyResult : PolicyResult
+---@field canShare boolean
+---@field sharingMode string
+---@field allowTakeBypass boolean
+
+---@class UnitTransferContext : PolicyActionContext
+---@field unitIds number[]
+---@field given boolean?
+---@field validationResult UnitValidationResult
+---@field policyResult UnitTransferPolicyResult
+
+---@class UnitDefValidationSummary
+---@field ok boolean
+---@field name string
+---@field unitDefID number
+---@field unitCount number
+
+---@class UnitValidationResult
+---@field status string SharedEnums.UnitValidationOutcome
+---@field invalidUnitCount number
+---@field invalidUnitCategoryCount number
+---@field invalidUnitNames string[]
+---@field validUnitCount number
+---@field validUnitCategoryCount number
+---@field validUnitNames string[]
+
+---@class UnitTransferResult
+---@field outcome string SharedEnums.UnitValidationOutcome
+---@field senderTeamId number
+---@field receiverTeamId number
+---@field validationResult UnitValidationResult
+---@field policyResult UnitTransferPolicyResult
+
+-- Unit Sharing Globals
+
+---@class UnitSharingPolicyGlobals
+---@field unitSharingMode string
+---@field allowedList table<number, boolean>
+
+-- Resource Transfer Action
+
+---@class ResourcePolicyResult : PolicyResult
+---@field canShare boolean
+---@field amountSendable number
+---@field amountReceivable number
+---@field taxedPortion number
+---@field untaxedPortion number
+---@field taxRate number
+---@field resourceType ResourceType
+---@field remainingTaxFreeAllowance number
+---@field resourceShareThreshold number
+---@field cumulativeSent number
+
+---@class ResourceTransferContext : PolicyActionContext
+---@field resourceType ResourceType
+---@field desiredAmount number
+---@field policyResult ResourcePolicyResult
+
+---@class ResourceTransferResult
+---@field success boolean
+---@field sent number
+---@field received number
+---@field untaxed number
+---@field senderTeamId number
+---@field receiverTeamId number
+---@field policyResult ResourcePolicyResult
+
+--- Policy Context
+
+---@class TeamInfo
+---@field id number
+---@field name string
+---@field leader number
+---@field isDead boolean
+---@field isAI boolean
+---@field side string
+---@field allyTeam number
+
+---@class RegisterInitializePolicyContext
+---@field playerIds number[]
+---@field springRepo ISpring
+
+---@class TeamData
+---@field id number
+---@field isHuman boolean
+---@field name string
+---@field metal ResourceData
+---@field energy ResourceData
+
+---@class ResourceData
+---@field current number
+---@field storage number
+---@field pull number
+---@field income number
+---@field expense number
+---@field shareSlider number
+---@field sent number
+---@field received number
+
+---@class TeamResources
+---@field metal ResourceData
+---@field energy ResourceData
+
+---@class PolicyContext
+---@field senderTeamId number
+---@field receiverTeamId number
+---@field resultSoFar table<TransferCategory, table>
+---@field sender TeamResources
+---@field receiver TeamResources
+---@field springRepo ISpring
+---@field areAlliedTeams boolean
+---@field isCheatingEnabled boolean
+
+---@class PolicyActionContext : PolicyContext
+---@field transferCategory string SharedEnums.TransferCategory
