local _, HTF = ...

local Stats = {}
HTF.Stats = Stats

Stats.MIN_FONT_SIZE = 10
Stats.MAX_FONT_SIZE = 24
Stats.MIN_SCALE = 0.70
Stats.MAX_SCALE = 2.00
Stats.DURABILITY_WARNING_THRESHOLD = 40
Stats.DURABILITY_CRITICAL_THRESHOLD = 20
Stats.BAG_WARNING_THRESHOLD = 5
Stats.BAG_CRITICAL_THRESHOLD = 2
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

Stats.ADVENTURE_DEFINITIONS = {
	{ key = "durability", fallbackKey = "HUD_DURABILITY" },
	{ key = "bagSpace", fallbackKey = "HUD_BAG_SPACE" },
	{ key = "money", fallbackKey = "HUD_MONEY" },
	{ key = "latency", fallbackKey = "HUD_LATENCY" },
}

Stats.DISPLAY_DEFINITIONS = {}
for _, definition in ipairs(Stats.STAT_DEFINITIONS) do
	table.insert(Stats.DISPLAY_DEFINITIONS, definition)
end
for _, definition in ipairs(Stats.ADVENTURE_DEFINITIONS) do
	table.insert(Stats.DISPLAY_DEFINITIONS, definition)
end

local definitionByKey = {}
for _, definition in ipairs(Stats.DISPLAY_DEFINITIONS) do
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

local function applyBackdrop(frame, background, border)
	frame:SetBackdrop(OVERLAY_BACKDROP)
	frame:SetBackdropColor(background[1], background[2], background[3], background[4])
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local ALERT_COLORS = {
	warning = { 0.96, 0.72, 0.28 },
	critical = { 1.00, 0.34, 0.34 },
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

local function integerPercentText(value)
	return string.format("%d%%", math.floor(value + 0.5))
end

local function millisecondsText(value)
	return string.format("%d ms", math.floor(value + 0.5))
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
	if type(db.statsScale) ~= "number" then
		db.statsScale = HTF.defaults.statsScale
	else
		db.statsScale = clamp(db.statsScale, self.MIN_SCALE, self.MAX_SCALE)
	end

	if type(db.statsVisibility) ~= "table" then
		db.statsVisibility = {}
	end
	if type(db.statsColors) ~= "table" then
		db.statsColors = {}
	end
	for _, definition in ipairs(self.DISPLAY_DEFINITIONS) do
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
	self.eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
	self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
	self.eventFrame:RegisterEvent("PLAYER_MONEY")
	self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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
	overlay:SetResizable(true)
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

	overlay.resizeHandle = CreateFrame("Button", nil, overlay, "BackdropTemplate")
	overlay.resizeHandle:SetSize(18, 18)
	overlay.resizeHandle:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -4, 4)
	overlay.resizeHandle:RegisterForDrag("LeftButton")
	applyBackdrop(overlay.resizeHandle, { 0.12, 0.16, 0.23, 0.96 }, { 0.30, 0.89, 0.67, 0.95 })

	overlay.resizeHandle.grip = overlay.resizeHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	overlay.resizeHandle.grip:SetPoint("CENTER", 1, -1)
	overlay.resizeHandle.grip:SetText("◢")
	overlay.resizeHandle.grip:SetTextColor(0.70, 0.90, 0.82, 1)

	overlay.resizeHandle:SetScript("OnEnter", function(handle)
		handle:SetBackdropColor(0.16, 0.26, 0.30, 1)
	end)
	overlay.resizeHandle:SetScript("OnLeave", function(handle)
		handle:SetBackdropColor(0.12, 0.16, 0.23, 0.96)
	end)
	overlay.resizeHandle:SetScript("OnDragStart", function()
		self:BeginOverlayResize()
	end)
	overlay.resizeHandle:SetScript("OnDragStop", function()
		self:FinishOverlayResize()
	end)

	overlay.rows = {}
	for _, definition in ipairs(self.DISPLAY_DEFINITIONS) do
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

	for _, definition in ipairs(self.DISPLAY_DEFINITIONS) do
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
	self.overlayBaseWidth = math.max(190, fontSize * 11)
	self.overlayBaseHeight = math.max(minimumHeight, -yOffset + 4)
	if not self.resizingOverlay then
		self.overlay:SetSize(self.overlayBaseWidth, self.overlayBaseHeight)
	end
	self.visibleRowCount = visibleCount
end

function Stats:ApplyOverlaySettings()
	if not self.overlay or not HTF.db then
		return
	end

	self:NormalizeSettings()
	local locked = HTF:GetSetting("statsLocked")
	local fontSize = self:GetFontSize()
	self.overlay:SetScale(self:GetScale())
	self.overlay:EnableMouse(not locked)
	if locked then
		if self.resizingOverlay then
			self.overlay:StopMovingOrSizing()
			self.resizingOverlay = false
		end
		self.overlay:SetBackdropColor(0.04, 0.06, 0.09, 0)
		self.overlay:SetBackdropBorderColor(0.30, 0.89, 0.67, 0)
		self.overlay.title:Hide()
		self.overlay.resizeHandle:Hide()
	else
		self.overlay:SetBackdropColor(0.04, 0.06, 0.09, 0.82)
		self.overlay:SetBackdropBorderColor(0.30, 0.89, 0.67, 0.95)
		self.overlay.title:Show()
		self.overlay.resizeHandle:Show()
	end

	for _, definition in ipairs(self.DISPLAY_DEFINITIONS) do
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
	if key ~= "showStats" and key ~= "statsLocked" and key ~= "statsFontSize" and key ~= "statsScale" then
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

function Stats:AddValue(snapshot, key, value, formatter, color)
	if not HTF:IsSafeNumber(value) then
		snapshot[key] = { text = HTF.L.STAT_RESTRICTED, restricted = true }
		return true
	end

	snapshot[key] = { text = formatter(value), restricted = false, color = color }
	return false
end

function Stats:AddUnavailableValue(snapshot, key)
	snapshot[key] = { text = HTF.L.STAT_UNAVAILABLE, restricted = false }
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

function Stats:GetDurabilityPercent()
	if type(GetInventoryItemDurability) ~= "function" then
		return nil
	end

	local lastSlot = HTF:IsSafeNumber(INVSLOT_LAST_EQUIPPED) and INVSLOT_LAST_EQUIPPED or 19
	local currentTotal = 0
	local maximumTotal = 0
	for slot = 1, lastSlot do
		local current, maximum = GetInventoryItemDurability(slot)
		if HTF:IsSecretValue(current) then
			return current
		end
		if HTF:IsSecretValue(maximum) then
			return maximum
		end
		if HTF:IsSafeNumber(current) and HTF:IsSafeNumber(maximum) and maximum > 0 then
			currentTotal = currentTotal + current
			maximumTotal = maximumTotal + maximum
		end
	end

	if maximumTotal <= 0 then
		return nil
	end
	return currentTotal / maximumTotal * 100
end

function Stats:GetBagSpace()
	if type(C_Container) ~= "table"
		or type(C_Container.GetContainerNumFreeSlots) ~= "function"
		or type(C_Container.GetContainerNumSlots) ~= "function" then
		return nil, nil
	end

	local firstBag = HTF:IsSafeNumber(BACKPACK_CONTAINER) and BACKPACK_CONTAINER or 0
	local lastBag = HTF:IsSafeNumber(NUM_BAG_SLOTS) and NUM_BAG_SLOTS or 4
	local freeTotal = 0
	local slotTotal = 0
	for bag = firstBag, lastBag do
		local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
		local slots = C_Container.GetContainerNumSlots(bag)
		if HTF:IsSecretValue(freeSlots) then
			return freeSlots, nil
		end
		if HTF:IsSecretValue(slots) then
			return nil, slots
		end
		if not HTF:IsSafeNumber(freeSlots) or not HTF:IsSafeNumber(slots) then
			return nil, nil
		end
		freeTotal = freeTotal + freeSlots
		slotTotal = slotTotal + slots
	end

	if slotTotal <= 0 then
		return nil, nil
	end
	return freeTotal, slotTotal
end

function Stats:GetLatency()
	if type(GetNetStats) ~= "function" then
		return nil
	end

	local _, _, homeLatency, worldLatency = GetNetStats()
	if HTF:IsSecretValue(worldLatency) then
		return worldLatency
	end
	if HTF:IsSafeNumber(worldLatency) then
		return worldLatency
	end
	if HTF:IsSecretValue(homeLatency) then
		return homeLatency
	end
	if HTF:IsSafeNumber(homeLatency) then
		return homeLatency
	end
	return nil
end

function Stats:GetDurabilityAlertColor(value)
	if not HTF:IsSafeNumber(value) then
		return nil
	end
	if value <= self.DURABILITY_CRITICAL_THRESHOLD then
		return ALERT_COLORS.critical
	end
	if value <= self.DURABILITY_WARNING_THRESHOLD then
		return ALERT_COLORS.warning
	end
	return nil
end

function Stats:GetBagSpaceAlertColor(freeSlots)
	if not HTF:IsSafeNumber(freeSlots) then
		return nil
	end
	if freeSlots <= self.BAG_CRITICAL_THRESHOLD then
		return ALERT_COLORS.critical
	end
	if freeSlots <= self.BAG_WARNING_THRESHOLD then
		return ALERT_COLORS.warning
	end
	return nil
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

	for _, definition in ipairs(self.ADVENTURE_DEFINITIONS) do
		local key = definition.key
		if self:IsStatVisible(key) then
			if key == "durability" then
				local value = self:GetDurabilityPercent()
				if value == nil then
					self:AddUnavailableValue(snapshot, key)
				elseif self:AddValue(snapshot, key, value, integerPercentText, self:GetDurabilityAlertColor(value)) then
					hasRestrictedValue = true
				end
			elseif key == "bagSpace" then
				local freeSlots, totalSlots = self:GetBagSpace()
				if HTF:IsSafeNumber(freeSlots) and HTF:IsSafeNumber(totalSlots) then
					snapshot[key] = {
						text = string.format("%d/%d", math.floor(freeSlots), math.floor(totalSlots)),
						restricted = false,
						color = self:GetBagSpaceAlertColor(freeSlots),
					}
				else
					local restrictedValue = HTF:IsSecretValue(freeSlots) and freeSlots or (HTF:IsSecretValue(totalSlots) and totalSlots or nil)
					if restrictedValue == nil then
						self:AddUnavailableValue(snapshot, key)
					elseif self:AddValue(snapshot, key, restrictedValue, integerText) then
						hasRestrictedValue = true
					end
				end
			elseif key == "money" then
				local value = type(GetMoney) == "function" and GetMoney() or nil
				if value == nil then
					self:AddUnavailableValue(snapshot, key)
				elseif self:AddValue(snapshot, key, value, function(amount)
					return HTF:FormatMoney(amount)
				end) then
					hasRestrictedValue = true
				end
			elseif key == "latency" then
				local value = self:GetLatency()
				if value == nil then
					self:AddUnavailableValue(snapshot, key)
				elseif self:AddValue(snapshot, key, value, millisecondsText) then
					hasRestrictedValue = true
				end
			end
		end
	end

	return snapshot, hasRestrictedValue
end

function Stats:RenderSnapshot(snapshot, hasRestrictedValue)
	if not self.overlay then
		return
	end

	for _, definition in ipairs(self.DISPLAY_DEFINITIONS) do
		local value = snapshot[definition.key]
		if value then
			local row = self.overlay.rows[definition.key]
			row:SetText(string.format("%s: %s", self:GetStatLabel(definition.key), value.text or HTF.L.STAT_UNAVAILABLE))
			local r, g, b = self:GetStatColor(definition.key)
			if type(value.color) == "table" then
				r = value.color[1] or r
				g = value.color[2] or g
				b = value.color[3] or b
			end
			row:SetTextColor(r, g, b, 1)
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

function Stats:GetScale()
	return HTF.db and HTF.db.statsScale or HTF.defaults.statsScale
end

function Stats:SetScale(scale)
	if type(scale) ~= "number" then
		return
	end
	HTF:SetSetting("statsScale", clamp(scale, self.MIN_SCALE, self.MAX_SCALE))
end

function Stats:BeginOverlayResize()
	if not self.overlay or HTF:GetSetting("statsLocked") or self.resizingOverlay then
		return
	end

	local baseWidth = self.overlayBaseWidth or self.overlay:GetWidth()
	local baseHeight = self.overlayBaseHeight or self.overlay:GetHeight()
	local currentScale = self:GetScale()
	if type(baseWidth) ~= "number" or type(baseHeight) ~= "number" or baseWidth <= 0 or baseHeight <= 0 then
		return
	end

	self.resizingOverlay = true
	self.resizeBaseWidth = baseWidth
	self.resizeBaseHeight = baseHeight
	self.resizeInitialScale = currentScale
	if type(self.overlay.SetResizeBounds) == "function" then
		self.overlay:SetResizeBounds(
			baseWidth * self.MIN_SCALE / currentScale,
			baseHeight * self.MIN_SCALE / currentScale,
			baseWidth * self.MAX_SCALE / currentScale,
			baseHeight * self.MAX_SCALE / currentScale
		)
	end
	self.overlay:StartSizing("BOTTOMRIGHT")
end

function Stats:FinishOverlayResize()
	if not self.overlay or not self.resizingOverlay then
		return
	end

	local baseWidth = self.resizeBaseWidth
	local baseHeight = self.resizeBaseHeight
	local initialScale = self.resizeInitialScale
	local width = self.overlay:GetWidth()
	local height = self.overlay:GetHeight()
	self.overlay:StopMovingOrSizing()
	self.resizingOverlay = false
	self.resizeBaseWidth = nil
	self.resizeBaseHeight = nil
	self.resizeInitialScale = nil

	if type(baseWidth) ~= "number" or type(baseHeight) ~= "number" or type(initialScale) ~= "number"
		or type(width) ~= "number" or type(height) ~= "number" or baseWidth <= 0 or baseHeight <= 0 then
		self:ApplyOverlaySettings()
		return
	end

	local resizeRatio = math.max(width / baseWidth, height / baseHeight)
	self:SetScale(initialScale * resizeRatio)
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
	for _, definition in ipairs(self.DISPLAY_DEFINITIONS) do
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

function Stats:GetVisibleAdventureStatusCount()
	local count = 0
	for _, definition in ipairs(self.ADVENTURE_DEFINITIONS) do
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
