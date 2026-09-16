-- tf_startpos.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then
		ctx.attachTBMirrorControls(doc, "st")
	end
	local trackSliderDrag = ctx.trackSliderDrag

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	for _, sid in ipairs({ "sp-allyteams", "sp-teams-per-ally", "sp-count", "sp-size", "sp-rotation" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then
			trackSliderDrag(sl, sid)
		end
	end
	-- All data-event-click/change handlers (onSpXxx) are defined in initialModel
	-- in gui_terraform_brush.lua — Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

function M.sync(doc, ctx, stpState, setSummary)
	local WG = ctx.WG
	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "st")
	end
	local widgetState = ctx.widgetState
	-- btn-startpos active state driven by data-class-active="activeTool == 'stp'" in RML.

	-- Sub-mode and shape buttons driven by dm fields via data-class-active
	-- (stpSubMode is set below at widgetState.dmHandle.stpSubMode)

	-- Startpos shape (stpShapeMode dm field)
	if widgetState.dmHandle then
		local shp = stpState.shapeType or "circle"
		if widgetState.dmHandle.stpShapeMode ~= shp then
			widgetState.dmHandle.stpShapeMode = shp
		end
	end

	-- Startbox placement-mode buttons (box / polygon / freedraw)
	if doc then
		local sbxMode = stpState.startboxMode or "polygon"
		-- Sync data-model flags driving data-if visibility
		if widgetState.dmHandle then
			local sm = stpState.subMode or ""
			if widgetState.dmHandle.stpSubMode ~= sm then
				widgetState.dmHandle.stpSubMode = sm
			end
			if widgetState.dmHandle.stpStartboxMode ~= sbxMode then
				widgetState.dmHandle.stpStartboxMode = sbxMode
			end
		end
		-- Contextual hint visibility now driven by data-if on the elements.
	end

	-- Visibility for sp-shape-options, sp-shape-row, sp-express-hint, sp-startbox-hint
	-- is driven by data-if="stpSubMode == ..." against widgetState.dmHandle.stpSubMode
	-- (synced above). No imperative SetClass needed here.

	if doc and widgetState.wireTextInput then
		widgetState.stpWiredInputs = widgetState.stpWiredInputs or setmetatable({}, { __mode = "k" })
		for _, id in ipairs({
			"sp-region-name",
			"sp-region-group",
			"sp-detail-name",
			"sp-detail-group",
			"sp-detail-label",
			"sp-tag-input",
		}) do
			local el = doc:GetElementById(id)
			if el and not widgetState.stpWiredInputs[el] then
				widgetState.stpWiredInputs[el] = true
				widgetState.wireTextInput(el)
			end
		end
	end

	if widgetState.dmHandle then
		local dm = widgetState.dmHandle
		local function setRg(f, v)
			if dm[f] ~= v then
				dm[f] = v
			end
		end
		local labels = stpState.regionTypeLabels or {}
		local typeLabel = labels[stpState.regionType] and labels[stpState.regionType].label or "Region"
		setRg("stpRegionType", stpState.regionType or "start")
		setRg("stpCategory", stpState.category or "start")
		setRg("stpDrawingArea", stpState.drawForTeam ~= nil)
		setRg("stpSelectedHasBox", (stpState.selected and stpState.selected.hasBox) == true)
		setRg("stpStrategy", stpState.strategy or "express")
		setRg("stpPlacing", stpState.placing or "points")
		local polygonMode = stpState.regionType == "mex_region" or stpState.placing == "area"
		setRg("stpPolygonMode", polygonMode)
		setRg("stpShowShapeOptions", (not polygonMode) and stpState.strategy == "shape")
		setRg("stpGeometry", stpState.geometry or "point")
		setRg("stpEditMode", stpState.editMode or "select")
		setRg("stpGatheredSpots", tostring(stpState.gatheredSpots or 0))
		setRg("stpAreaTarget", tostring(stpState.areaTarget or ""))
		local hint
		if stpState.editMode == "select" then
			hint = "select"
		elseif stpState.geometry == "point" then
			hint = "points"
		elseif stpState.geometry == "square" then
			hint = "square"
		elseif stpState.geometry == "mexes" then
			hint = "mexes"
		else
			hint = "polygon"
		end
		setRg("stpHint", hint)

		local geoChips = doc and doc:GetElementById("sp-geometry-chips")
		if geoChips then
			local geoKey = table.concat(stpState.geometries or {}, ",") .. "|" .. tostring(stpState.geometry)
			if widgetState.stpGeometryKey ~= geoKey then
				widgetState.stpGeometryKey = geoKey
				local labels = { point = "Point", square = "Square", polygon = "Polygon", mexes = "Mexes" }
				local html = {}
				for i, g in ipairs(stpState.geometries or {}) do
					local active = (g == stpState.geometry) and " active" or ""
					html[#html + 1] = '<div id="sp-geometry-'
						.. i
						.. '" class="tf-overlay-chip'
						.. active
						.. '"><div class="tf-overlay-chip-label">'
						.. (labels[g] or g)
						.. "</div></div>"
				end
				geoChips.inner_rml = table.concat(html)
				for i, g in ipairs(stpState.geometries or {}) do
					local chip = doc:GetElementById("sp-geometry-" .. i)
					if chip then
						chip:AddEventListener("click", function(event)
							if WG.StartPosTool and WG.StartPosTool.setGeometry then
								WG.StartPosTool.setGeometry(g)
							end
							event:StopPropagation()
						end, false)
					end
				end
			end
		end
		setRg("stpSelected", stpState.selected ~= nil)
		setRg("stpSelectedAllyTeam", tostring(stpState.selected and stpState.selected.allyTeam or ""))
		setRg("stpSelectedVertices", tostring(stpState.selected and stpState.selected.vertexCount or 0))
		setRg("stpRegionError", stpState.regionError or "")
		setRg("stpRegionListTitle", (stpState.regionType == "start") and "STARTS" or (typeLabel:upper() .. "S"))
		local detailsMode = "prompt"
		if stpState.selected then
			detailsMode = "details"
		elseif stpState.editMode == "create" and stpState.regionType == "mex_region" then
			detailsMode = "new"
		end
		setRg("stpDetailsMode", detailsMode)
		setRg("stpDetailsTitle", (detailsMode == "new") and ("NEW " .. typeLabel:upper()) or "DETAILS")
		setRg(
			"stpClearLabel",
			(stpState.regionType == "start") and "CLEAR ALL" or ("CLEAR " .. typeLabel:upper() .. "S")
		)

		local chips = doc and doc:GetElementById("sp-category-chips")
		if chips then
			local catKey = table.concat(stpState.categories or {}, ",") .. "|" .. tostring(stpState.category)
			if widgetState.stpCategoryKey ~= catKey then
				widgetState.stpCategoryKey = catKey
				local catLabels = stpState.categoryLabels or {}
				local html = {}
				for i, key in ipairs(stpState.categories or {}) do
					local label = catLabels[key] and catLabels[key].label or key
					local active = (key == stpState.category) and " active" or ""
					html[#html + 1] = '<div id="sp-category-'
						.. i
						.. '" class="tf-overlay-chip'
						.. active
						.. '"><div class="tf-overlay-chip-label">'
						.. label
						.. "</div></div>"
				end
				chips.inner_rml = table.concat(html)
				for i, key in ipairs(stpState.categories or {}) do
					local chip = doc:GetElementById("sp-category-" .. i)
					if chip then
						chip:AddEventListener("click", function(event)
							if WG.StartPosTool and WG.StartPosTool.setCategory then
								WG.StartPosTool.setCategory(key)
							end
							event:StopPropagation()
						end, false)
					end
				end
			end
		end

		local selKey = tostring(stpState.regionType)
			.. ":"
			.. tostring(stpState.selectedIdx)
			.. ":"
			.. tostring(stpState.selectedStart)
		if doc and (widgetState.stpRegionRevision ~= stpState.regionRevision or widgetState.stpSelKey ~= selKey) then
			widgetState.stpRegionRevision = stpState.regionRevision
			local selectionChanged = widgetState.stpSelKey ~= selKey
			widgetState.stpSelKey = selKey
			local st = WG.StartPosTool

			if selectionChanged and stpState.selected then
				local labelEl = doc:GetElementById("sp-detail-label")
				if labelEl then
					labelEl:SetAttribute("value", stpState.selected.name or "")
				end
				local nameEl = doc:GetElementById("sp-detail-name")
				local groupEl = doc:GetElementById("sp-detail-group")
				if nameEl then
					nameEl:SetAttribute("value", stpState.selected.name or "")
				end
				if groupEl then
					groupEl:SetAttribute("value", stpState.selected.group or "")
				end
			end

			local factsEl = doc:GetElementById("sp-detail-facts")
			if factsEl then
				local facts = stpState.selected and stpState.selected.facts or {}
				local html = {}
				for _, fact in ipairs(facts) do
					html[#html + 1] = '<div class="text-sm text-light">'
						.. fact[1]
						.. ': <span class="text-keybind">'
						.. fact[2]
						.. "</span></div>"
				end
				factsEl.inner_rml = table.concat(html)
			end

			local tagList = doc:GetElementById("sp-tag-list")
			if tagList then
				local tags = stpState.selected and stpState.selected.tags or {}
				local html = {}
				for i, tag in ipairs(tags) do
					html[#html + 1] = '<div id="sp-tag-'
						.. i
						.. '" class="tf-overlay-chip"><div class="tf-overlay-chip-label">'
						.. tag
						.. " ×</div></div>"
				end
				tagList.inner_rml = table.concat(html)
				for i = 1, #tags do
					local chip = doc:GetElementById("sp-tag-" .. i)
					if chip then
						chip:AddEventListener("click", function(event)
							if st and st.removeTag then
								st.removeTag(i)
							end
							event:StopPropagation()
						end, false)
					end
				end
			end

			local picker = doc:GetElementById("sp-group-picker")
			if picker then
				local groups = stpState.mexGroups or {}
				local html = {}
				for i, group in ipairs(groups) do
					html[#html + 1] = '<div id="sp-group-'
						.. i
						.. '" class="tf-overlay-chip"><div class="tf-overlay-chip-label">'
						.. group
						.. "</div></div>"
				end
				picker.inner_rml = table.concat(html)
				for i, group in ipairs(groups) do
					local chip = doc:GetElementById("sp-group-" .. i)
					if chip then
						chip:AddEventListener("click", function(event)
							local groupEl = doc:GetElementById("sp-region-group")
							if groupEl then
								groupEl:SetAttribute("value", group)
							end
							if st and st.setPendingField then
								st.setPendingField("group", group)
							end
							event:StopPropagation()
						end, false)
					end
				end
			end

			local listEl = doc:GetElementById("sp-region-list")
			if listEl then
				local html, count, onClick = {}, 0, nil
				if stpState.regionType == "start" then
					local starts = stpState.starts or {}
					count = #starts
					for i, start in ipairs(starts) do
						local selected = (start.allyTeam == stpState.selectedStart) and " selected" or ""
						local desc = start.positions
							.. " position"
							.. (start.positions == 1 and "" or "s")
							.. " · "
							.. (start.hasBox and "area drawn" or "no area")
						html[#html + 1] = '<div id="sp-region-item-'
							.. i
							.. '" class="ll-preset-item'
							.. selected
							.. '"><div class="ll-preset-name">Start '
							.. start.allyTeam
							.. (start.name and (" · " .. start.name) or "")
							.. '</div><div class="ll-preset-desc">'
							.. desc
							.. "</div></div>"
					end
					onClick = function(i)
						if st and st.selectStart then
							st.selectStart(i)
						end
					end
				else
					local regions = stpState.regions or {}
					count = #regions
					for i, region in ipairs(regions) do
						local label = (region.name or "?") .. (region.group and (" (" .. region.group .. ")") or "")
						local selected = (i == stpState.selectedIdx) and " selected" or ""
						html[#html + 1] = '<div id="sp-region-item-'
							.. i
							.. '" class="ll-preset-item'
							.. selected
							.. '"><div class="ll-preset-name">'
							.. label
							.. '</div><div class="ll-preset-desc">'
							.. #(region.vertices or {})
							.. " pts"
							.. ((region.tags and #region.tags > 0) and (" · " .. #region.tags .. " tags") or "")
							.. "</div></div>"
					end
					onClick = function(i)
						if st and st.selectRegion then
							st.selectRegion(i)
						end
					end
				end
				if count == 0 then
					listEl.inner_rml =
						'<div class="text-xs text-keybind" style="padding: 4dp;">Nothing on this layer yet.</div>'
				else
					listEl.inner_rml = table.concat(html)
					for i = 1, count do
						local item = doc:GetElementById("sp-region-item-" .. i)
						if item then
							item:AddEventListener("click", function(event)
								onClick(i)
								event:StopPropagation()
							end, false)
						end
					end
				end
			end
		end
	end

	-- Update labels via dm interpolation (Phase 2 step 4)
	local dm = widgetState.dmHandle
	if dm then
		local function setDm(f, v)
			if dm[f] ~= v then
				dm[f] = v
			end
		end
		setDm("stpAllyTeamsStr", tostring(stpState.numAllyTeams))
		setDm("stpCountStr", tostring(stpState.shapeCount))
		setDm("stpSizeStr", tostring(math.floor(stpState.shapeRadius)))
		setDm("stpRotationStr", tostring(math.floor(stpState.shapeRotation)) .. "\194\176")
		setDm("stpTeamsPerAllyStr", tostring(stpState.numTeamsPerAlly or 1))
		setDm("stpPlacementModeStr", (stpState.placementMode or "roundrobin"):upper():gsub("ROUNDROBIN", "ROUND-ROBIN"))
	end

	-- Sync sliders
	local getCachedEl = ctx.getCachedEl
	local allySlider = doc and getCachedEl(doc, "slider-sp-allyteams")
	if allySlider then
		allySlider:SetAttribute("value", tostring(stpState.numAllyTeams))
	end
	local tpaSlider = doc and getCachedEl(doc, "slider-sp-teams-per-ally")
	if tpaSlider then
		tpaSlider:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1))
	end
	local tpaNumbox = doc and getCachedEl(doc, "slider-sp-teams-per-ally-numbox")
	if tpaNumbox then
		tpaNumbox:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1))
	end
	local countSlider = doc and getCachedEl(doc, "slider-sp-count")
	if countSlider then
		countSlider:SetAttribute("value", tostring(stpState.shapeCount))
	end
	local sizeSlider = doc and getCachedEl(doc, "slider-sp-size")
	if sizeSlider then
		sizeSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRadius)))
	end
	local rotSlider = doc and getCachedEl(doc, "slider-sp-rotation")
	if rotSlider then
		rotSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRotation)))
	end

	setSummary(
		"REGIONS",
		"#fdc04c",
		"",
		(
			(
				stpState.regionTypeLabels
				and stpState.regionTypeLabels[stpState.regionType]
				and stpState.regionTypeLabels[stpState.regionType].label
			) or "start"
		):upper(),
		"Players ",
		tostring(stpState.totalPlayers or (stpState.numAllyTeams or 2))
			.. " ("
			.. tostring(stpState.numAllyTeams or 2)
			.. "x"
			.. tostring(stpState.numTeamsPerAlly or 1)
			.. ")"
	)

	-- P3.2 StartPos grayouts (per Phase 3 relevance matrix)
	if doc and ctx.setDisabledIds then
		local sm = stpState.subMode or "express"
		-- Both counts drive start-position placement only. Startbox submode takes its ally team
		-- count from the boxes drawn, and teams-per-ally has no bearing on a box, so leaving it
		-- live invites changing a number that does nothing.
		ctx.setDisabledIds(doc, {
			"slider-sp-allyteams",
			"slider-sp-allyteams-numbox",
			"btn-sp-teams-up",
			"btn-sp-teams-down",
			"slider-sp-teams-per-ally",
			"slider-sp-teams-per-ally-numbox",
			"btn-sp-teams-per-ally-up",
			"btn-sp-teams-per-ally-down",
		}, stpState.placing == "area" or stpState.regionType == "mex_region")
		-- Rotation: shape-mode only AND non-circular shape type
		local rotOff = (stpState.strategy ~= "shape")
			or (stpState.shapeType == "circle")
			or stpState.placing == "area"
			or stpState.regionType == "mex_region"
		ctx.setDisabledIds(doc, {
			"slider-sp-rotation",
			"slider-sp-rotation-numbox",
			"btn-sp-rot-ccw",
			"btn-sp-rot-cw",
		}, rotOff)
	end
end

return M
