local _, HTF = ...

local Stats = {}
HTF.Stats = Stats

Stats.MIN_FONT_SIZE = 10
Stats.MAX_FONT_SIZE = 24
Stats.STAT_DEFINITIONS = {
	{ key = "strength", primaryIndex = 1, fallbackKey = "STAT_STRENGTH" },
	{ key = "agility", primaryIndex = 2, fallbackKey = "STAT_AGILITY" },
	{ key = "stamina", primaryIndex = 3, fallbackKey = "STAT_STAMINA" },
	{ key = "intellect", primaryIndex = 4, fallbackKey = "STAT_INTELLECT" },
	{ key = "armor", globalLabel = "STAT_ARMOR", fallbackKey = "STAT_ARMOR" },
	{ key = "criticalStrike", globalLabel = "STAT_CRITICAL_STRIKE", fallbackKey = "STAT_CRITICAL_STRIKE" },
	{ key = "haste", globalLabel = "STAT_HASTE", fallbackKey = "STAT_HASTE" },
	{ key = "mastery", globalLabel = "STAT_MASTERY", fallbackKey = "STAT_MASTERY" },
	{ key = "versatility", globalLabel = "STAT_VERSATILITY", fallbackKey = "STAT_VERSATILITY" },
	{ key = "lifesteal", globalLabel = "STAT_LIFESTEAL", fallbackKey = "STAT_LIFESTEAL" },
	{ key = "avoidance", globalLabel = "STAT_AVOIDANCE", fallbackKey = "STAT_AVOIDANCE" },
	{ key = "speed", globalLabel = "STAT_SPEED", fallbackKey = "STAT_SPEED" },
	{ key = "dodge", globalLabel = "DODGE", fallbackKey = "STAT_DODGE" },
	{ key = "parry", globalLabel = "PARRY", fallbackKey = "STAT_PARRY" },
}

local definitionByKey = {}
for _, definition in ipairs(Stats.STAT_DEFINITIONS) do
	definitionByKey[definition.key] = definition
end

local VALID_POINTS = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

local OVERLAY_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
}

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function integerText(value)
	local rounded = math.floor(value + 0.5)
	if type(BreakUpLargeNumbers) == "function" then
		return BreakUpLargeNumbers(rounded)
	end
	return tostring(rounded)
end

local function percentText(value)
	return string.format("%.2f%%", value)
end

local function copyColor(color)
	return { color[1], color[2], color[3] }
end

local function applyHighContrastFont(fontString, size)
	local font = fontString:GetFont()
	if not font then
		return
	end
	if fontString:SetFont(font, size, "THICKOUTLINE") == false then
		fontString:SetFont(font, size, "OUTLINE")
	end
end

function Stats:GetStatDefinition(key)
	return definitionByKey[key]
end

function Stats:GetStatLabel(key)
	local definition = definitionByKey[key]
	if not definition then
		return key
	end
	if definition.primaryIndex then
		return _G["SPELL_STAT" .. definition.primaryIndex .. "_NAME"] or HTF.L[definition.fallbackKey]
	end
	return (definition.globalLabel and _G[definition.globalLabel]) or HTF.L[definition.fallbackKey]
end

function Stats:NormalizeSettings()
	local db = HTF.db
	if not db then
		return
	end

	if type(db.statsLocked) ~= "boolean" then
		db.statsLocked = HTF.defaults.statsLocked
	end
	if type(db.statsFontSize) ~= "number" then
		db.statsFontSize = HTF.defaults.statsFontSize
	else
		db.statsFontSize = clamp(math.floor(db.statsFontSize + 0.5), self.MIN_FONT_SIZE, self.MAX_FONT_SIZE)
	end

	if type(db.statsVisibility) ~= "table" then
		db.statsVisibility = {}
	end
	if type(db.statsColors) ~= "table" then
		db.statsColors = {}
	end
	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		local key = definition.key
		if type(db.statsVisibility[key]) ~= "boolean" then
			db.statsVisibility[key] = HTF.defaults.statsVisibility[key]
		end

		local savedColor = db.statsColors[key]
		local defaultColor = HTF.defaults.statsColors[key]
		if type(savedColor) ~= "table" then
			savedColor = copyColor(defaultColor)
			db.statsColors[key] = savedColor
		end
		for component = 1, 3 do
			if type(savedColor[component]) ~= "number" then
				savedColor[component] = defaultColor[component]
			else
				savedColor[component] = clamp(savedColor[component], 0, 1)
			end
		end
	end

	local savedPosition = db.statsPosition
	local defaultPosition = HTF.defaults.statsPosition
	if type(savedPosition) ~= "table" then
		savedPosition = {}
		db.statsPosition = savedPosition
	end
	if not VALID_POINTS[savedPosition.point] then
		savedPosition.point = defaultPosition.point
	end
	if not VALID_POINTS[savedPosition.relativePoint] then
		savedPosition.relativePoint = defaultPosition.relativePoint
	end
	if type(savedPosition.x) ~= "number" then
		savedPosition.x = defaultPosition.x
	else
		savedPosition.x = clamp(savedPosition.x, -4096, 4096)
	end
	if type(savedPosition.y) ~= "number" then
		savedPosition.y = defaultPosition.y
	else
		savedPosition.y = clamp(savedPosition.y, -4096, 4096)
	end
end

function Stats:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self:NormalizeSettings()
	self:CreateOverlay()
	self:ApplyOverlaySettings()

	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	self.eventFrame:RegisterEvent("UNIT_STATS")
	self.eventFrame:RegisterEvent("COMBAT_RATING_UPDATE")
	self.eventFrame:RegisterEvent("MASTERY_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.eventFrame:SetScript("OnEvent", function(_, event, unit)
		self:OnEvent(event, unit)
	end)
end

function Stats:CreateOverlay()
	if self.overlay then
		return
	end

	local overlay = CreateFrame("Frame", "HappyTreeFriendsStatsOverlay", UIParent, "BackdropTemplate")
	overlay:SetSize(190, 100)
	overlay:SetFrameStrata("MEDIUM")
	overlay:SetMovable(true)
	overlay:SetClampedToScreen(true)
	overlay:RegisterForDrag("LeftButton")
	overlay:SetBackdrop(OVERLAY_BACKDROP)
	overlay:SetScript("OnDragStart", function(frame)
		if not HTF:GetSetting("statsLocked") then
			frame:StartMoving()
		end
	end)
	overlay:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SavePosition()
	end)

	overlay.title = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	overlay.title:SetPoint("TOPLEFT", overlay, "TOPLEFT", 8, -7)
	overlay.title:SetText(HTF.L.STATS_DRAG_HINT)
	overlay.title:SetTextColor(0.77, 0.84, 0.94, 1)

	overlay.status = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	overlay.status:SetJustifyH("LEFT")
	overlay.status:SetTextColor(0.95, 0.72, 0.42, 1)
	overlay.status:SetShadowColor(0, 0, 0, 1)
	overlay.status:SetShadowOffset(2, -2)

	overlay.rows = {}
	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		local row = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row:SetJustifyH("LEFT")
		row:SetShadowColor(0, 0, 0, 1)
		row:SetShadowOffset(2, -2)
		row:SetText(string.format("%s: %s", self:GetStatLabel(definition.key), HTF.L.STAT_UNAVAILABLE))
		overlay.rows[definition.key] = row
	end

	self.overlay = overlay
end

function Stats:ApplyPosition()
	if not self.overlay then
		return
	end
	local position = HTF.db.statsPosition
	self.overlay:ClearAllPoints()
	self.overlay:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

function Stats:SavePosition()
	if not self.overlay or type(self.overlay.GetPoint) ~= "function" then
		return
	end

	local point, _, relativePoint, x, y = self.overlay:GetPoint(1)
	if not VALID_POINTS[point] or not VALID_POINTS[relativePoint] or type(x) ~= "number" or type(y) ~= "number" then
		HTF:Debug(HTF.L.DEBUG_STATS_POSITION_INVALID)
		return
	end

	local position = HTF.db.statsPosition
	position.point = point
	position.relativePoint = relativePoint
	position.x = clamp(x, -4096, 4096)
	position.y = clamp(y, -4096, 4096)
	HTF:Debugf(HTF.L.DEBUG_STATS_POSITION_SAVED, point, relativePoint, position.x, position.y)
end

function Stats:LayoutOverlay()
	if not self.overlay then
		return
	end

	local locked = HTF:GetSetting("statsLocked")
	local fontSize = self:GetFontSize()
	local lineHeight = fontSize + 5
	local yOffset = locked and -4 or -27
	local visibleCount = 0

	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		local row = self.overlay.rows[definition.key]
		row:ClearAllPoints()
		if self:IsStatVisible(definition.key) then
			row:SetPoint("TOPLEFT", self.overlay, "TOPLEFT", 8, yOffset)
			row:SetPoint("RIGHT", self.overlay, "RIGHT", -8, 0)
			row:SetHeight(lineHeight)
			row:Show()
			yOffset = yOffset - lineHeight
			visibleCount = visibleCount + 1
		else
			row:Hide()
		end
	end

	self.overlay.status:ClearAllPoints()
	if self.overlayStatus and self.overlayStatus ~= "" then
		self.overlay.status:SetPoint("TOPLEFT", self.overlay, "TOPLEFT", 8, yOffset - 1)
		self.overlay.status:SetPoint("RIGHT", self.overlay, "RIGHT", -8, 0)
		self.overlay.status:SetHeight(15)
		self.overlay.status:Show()
		yOffset = yOffset - 18
	else
		self.overlay.status:Hide()
	end

	local minimumHeight = locked and 16 or 34
	self.overlay:SetSize(math.max(190, fontSize * 11), math.max(minimumHeight, -yOffset + 4))
	self.visibleRowCount = visibleCount
end

function Stats:ApplyOverlaySettings()
	if not self.overlay or not HTF.db then
		return
	end

	self:NormalizeSettings()
	local locked = HTF:GetSetting("statsLocked")
	local fontSize = self:GetFontSize()
	self.overlay:EnableMouse(not locked)
	if locked then
		self.overlay:SetBackdropColor(0.04, 0.06, 0.09, 0)
		self.overlay:SetBackdropBorderColor(0.30, 0.89, 0.67, 0)
		self.overlay.title:Hide()
	else
		self.overlay:SetBackdropColor(0.04, 0.06, 0.09, 0.82)
		self.overlay:SetBackdropBorderColor(0.30, 0.89, 0.67, 0.95)
		self.overlay.title:Show()
	end

	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		local row = self.overlay.rows[definition.key]
		applyHighContrastFont(row, fontSize)
		local r, g, b = self:GetStatColor(definition.key)
		row:SetTextColor(r, g, b, 1)
	end
	applyHighContrastFont(self.overlay.status, 11)

	self:ApplyPosition()
	self:LayoutOverlay()
	if HTF:GetSetting("showStats") then
		self.overlay:Show()
	else
		self.overlay:Hide()
	end
end

function Stats:OnSettingChanged(key)
	if key ~= "showStats" and key ~= "statsLocked" and key ~= "statsFontSize" then
		return
	end
	self:ApplyOverlaySettings()
	if key == "showStats" and HTF:GetSetting("showStats") then
		self:RequestRefresh()
	end
end

function Stats:OnEvent(event, unit)
	if event == "UNIT_STATS" and unit ~= "player" then
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		self:ShowCombatRestriction()
		return
	end
	self:RequestRefresh()
end

function Stats:IsVisible()
	return self.overlay and self.overlay:IsShown() and HTF:GetSetting("showStats") == true
end

function Stats:RequestRefresh()
	if not self:IsVisible() or self.refreshQueued then
		return
	end

	self.refreshQueued = true
	local function refresh()
		self.refreshQueued = false
		self:Refresh()
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.05, refresh)
	else
		refresh()
	end
end

function Stats:AddValue(snapshot, key, value, formatter)
	if not HTF:IsSafeNumber(value) then
		snapshot[key] = { text = HTF.L.STAT_RESTRICTED, restricted = true }
		return true
	end

	snapshot[key] = { text = formatter(value), restricted = false }
	return false
end

function Stats:GetDisplayedCritChance()
	if type(GetCritChance) ~= "function" then
		return nil
	end

	local displayedCrit = GetCritChance()
	if not HTF:IsSafeNumber(displayedCrit) then
		return nil
	end

	if type(GetRangedCritChance) == "function" then
		local rangedCrit = GetRangedCritChance()
		if not HTF:IsSafeNumber(rangedCrit) then
			return nil
		end
		if rangedCrit > displayedCrit then
			displayedCrit = rangedCrit
		end
	end

	if type(GetSpellCritChance) == "function" then
		local maximumSpellSchool = HTF:IsSafeNumber(MAX_SPELL_SCHOOLS) and MAX_SPELL_SCHOOLS or 7
		local spellCrit
		for schoolIndex = 2, maximumSpellSchool do
			local schoolCrit = GetSpellCritChance(schoolIndex)
			if not HTF:IsSafeNumber(schoolCrit) then
				return nil
			end
			if not spellCrit or schoolCrit < spellCrit then
				spellCrit = schoolCrit
			end
		end
		if spellCrit and spellCrit > displayedCrit then
			displayedCrit = spellCrit
		end
	end

	return displayedCrit
end

function Stats:GetVersatility()
	if type(GetCombatRatingBonus) ~= "function"
		or type(GetVersatilityBonus) ~= "function"
		or not CR_VERSATILITY_DAMAGE_DONE then
		return nil
	end

	local ratingBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
	local effectBonus = GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
	if not HTF:IsSafeNumber(ratingBonus) or not HTF:IsSafeNumber(effectBonus) then
		return nil
	end
	return ratingBonus + effectBonus
end

function Stats:BuildSnapshot()
	local snapshot = {}
	local hasRestrictedValue = false

	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		local key = definition.key
		if self:IsStatVisible(key) then
			local value
			local formatter = percentText
			if definition.primaryIndex then
				if type(UnitStat) == "function" then
					local _, effectiveStat = UnitStat("player", definition.primaryIndex)
					value = effectiveStat
				end
				formatter = integerText
			elseif key == "armor" then
				if type(UnitArmor) == "function" then
					local _, effectiveArmor = UnitArmor("player")
					value = effectiveArmor
				end
				formatter = integerText
			elseif key == "criticalStrike" then
				value = self:GetDisplayedCritChance()
			elseif key == "haste" then
				if type(GetHaste) == "function" then
					value = GetHaste()
				end
			elseif key == "mastery" then
				if type(GetMasteryEffect) == "function" then
					value = GetMasteryEffect()
				end
			elseif key == "versatility" then
				value = self:GetVersatility()
			elseif key == "lifesteal" then
				if type(GetLifesteal) == "function" then
					value = GetLifesteal()
				end
			elseif key == "avoidance" then
				if type(GetAvoidance) == "function" then
					value = GetAvoidance()
				end
			elseif key == "speed" then
				if type(GetSpeed) == "function" then
					value = GetSpeed()
				end
			elseif key == "dodge" then
				if type(GetDodgeChance) == "function" then
					value = GetDodgeChance()
				end
			elseif key == "parry" then
				if type(GetParryChance) == "function" then
					value = GetParryChance()
				end
			end

			if self:AddValue(snapshot, key, value, formatter) then
				hasRestrictedValue = true
			end
		end
	end

	return snapshot, hasRestrictedValue
end

function Stats:RenderSnapshot(snapshot, hasRestrictedValue)
	if not self.overlay then
		return
	end

	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		local value = snapshot[definition.key]
		if value then
			self.overlay.rows[definition.key]:SetText(string.format("%s: %s", self:GetStatLabel(definition.key), value.text or HTF.L.STAT_UNAVAILABLE))
		end
	end

	if hasRestrictedValue then
		self:SetOverlayStatus(HTF.L.STATS_PARTIALLY_RESTRICTED)
	else
		self:SetOverlayStatus("")
	end
end

function Stats:SetOverlayStatus(text)
	self.overlayStatus = text or ""
	if self.overlay and self.overlay.status then
		self.overlay.status:SetText(self.overlayStatus)
		self:LayoutOverlay()
	end
end

function Stats:ShowCombatRestriction()
	if self:IsVisible() then
		self:SetOverlayStatus(HTF.L.STATS_IN_COMBAT)
	end
end

function Stats:Refresh()
	if not self:IsVisible() then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		self:ShowCombatRestriction()
		return
	end

	local snapshot, hasRestrictedValue = self:BuildSnapshot()
	self:RenderSnapshot(snapshot, hasRestrictedValue)
	HTF:Debug(HTF.L.DEBUG_STATS_REFRESHED)
end

function Stats:IsStatVisible(key)
	return HTF.db and HTF.db.statsVisibility and HTF.db.statsVisibility[key] == true
end

function Stats:SetStatVisible(key, visible)
	if not definitionByKey[key] or not HTF.db then
		return
	end
	HTF.db.statsVisibility[key] = visible == true
	self:ApplyOverlaySettings()
	self:RequestRefresh()
	if HTF.Options and HTF.Options.RefreshStatSettings then
		HTF.Options:RefreshStatSettings()
	end
	HTF:Debugf(HTF.L.DEBUG_STAT_VISIBILITY_UPDATED, key, tostring(visible == true))
end

function Stats:GetStatColor(key)
	local defaultColor = HTF.defaults.statsColors[key] or { 1, 1, 1 }
	local color = HTF.db and HTF.db.statsColors and HTF.db.statsColors[key] or defaultColor
	return color[1] or defaultColor[1], color[2] or defaultColor[2], color[3] or defaultColor[3]
end

function Stats:SetStatColor(key, r, g, b)
	if not definitionByKey[key] or not HTF.db then
		return
	end
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return
	end
	HTF.db.statsColors[key] = { clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1) }
	if self.overlay and self.overlay.rows[key] then
		local savedR, savedG, savedB = self:GetStatColor(key)
		self.overlay.rows[key]:SetTextColor(savedR, savedG, savedB, 1)
	end
	if HTF.Options and HTF.Options.RefreshStatSetting then
		HTF.Options:RefreshStatSetting(key)
	end
end

function Stats:GetFontSize()
	return HTF.db and HTF.db.statsFontSize or HTF.defaults.statsFontSize
end

function Stats:SetFontSize(size)
	if type(size) ~= "number" then
		return
	end
	HTF:SetSetting("statsFontSize", clamp(math.floor(size + 0.5), self.MIN_FONT_SIZE, self.MAX_FONT_SIZE))
end

function Stats:ResetPosition()
	local defaultPosition = HTF.defaults.statsPosition
	HTF.db.statsPosition = {
		point = defaultPosition.point,
		relativePoint = defaultPosition.relativePoint,
		x = defaultPosition.x,
		y = defaultPosition.y,
	}
	self:ApplyOverlaySettings()
	HTF:Notify(HTF.L.STATS_POSITION_RESET)
	HTF:Debug(HTF.L.STATS_POSITION_RESET)
end

function Stats:ResetColors()
	HTF.db.statsColors = {}
	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		HTF.db.statsColors[definition.key] = copyColor(HTF.defaults.statsColors[definition.key])
	end
	self:ApplyOverlaySettings()
	if HTF.Options and HTF.Options.RefreshStatSettings then
		HTF.Options:RefreshStatSettings()
	end
	HTF:Notify(HTF.L.STATS_COLORS_RESET)
	HTF:Debug(HTF.L.STATS_COLORS_RESET)
end

function Stats:GetVisibleStatCount()
	local count = 0
	for _, definition in ipairs(self.STAT_DEFINITIONS) do
		if self:IsStatVisible(definition.key) then
			count = count + 1
		end
	end
	return count
end

function Stats:GetPositionSummary()
	local position = HTF.db and HTF.db.statsPosition or HTF.defaults.statsPosition
	return string.format("%s/%s %.1f %.1f", position.point, position.relativePoint, position.x, position.y)
end
