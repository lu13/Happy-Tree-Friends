local _, HTF = ...

local FriendlyNames = {}
HTF.FriendlyNames = FriendlyNames

local FRIENDLY_PLAYER_NAMES_CVAR = "UnitNameFriendlyPlayerName"
local FRIENDLY_PLAYER_NAMEPLATES_CVAR = "nameplateShowFriendlyPlayers"
local FRIENDLY_PLAYER_NAMES_ONLY_CVAR = "nameplateShowOnlyNameForFriendlyPlayerUnits"
local FRIENDLY_PLAYER_CLASS_COLORS_CVAR = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR = "nameplateShowFriendlyClassColor"

local FONT_OBJECT_NAMES = {
	"SystemFont_NamePlate",
	"SystemFont_NamePlate_Outlined",
}

local MANAGED_CVARS = {
	FRIENDLY_PLAYER_NAMES_CVAR,
	FRIENDLY_PLAYER_NAMES_ONLY_CVAR,
	FRIENDLY_PLAYER_CLASS_COLORS_CVAR,
	FRIENDLY_PLAYER_NAMEPLATES_CVAR,
}

FriendlyNames.MIN_FONT_SIZE = 8
FriendlyNames.MAX_FONT_SIZE = 28
FriendlyNames.DEFAULT_FONT_SIZE = 14

local relevantCVarNames = {}
for _, cvarName in ipairs(MANAGED_CVARS) do
	relevantCVarNames[string.lower(cvarName)] = true
end

local function normalizeCVarValue(value)
	if HTF:IsSecretValue(value) then
		return nil
	end

	local valueType = type(value)
	if valueType == "string" then
		return value
	end
	if valueType == "number" then
		return tostring(value)
	end
	if valueType == "boolean" then
		return value and "1" or "0"
	end

	return nil
end

local function normalizeFontSize(value)
	if HTF:IsSecretValue(value) then
		return FriendlyNames.DEFAULT_FONT_SIZE
	end

	if type(value) ~= "number" then
		value = tonumber(value)
	end
	if type(value) ~= "number" then
		return FriendlyNames.DEFAULT_FONT_SIZE
	end

	return math.max(FriendlyNames.MIN_FONT_SIZE, math.min(FriendlyNames.MAX_FONT_SIZE, math.floor(value)))
end

local function getCVarGetter()
	if type(C_CVar) == "table" and type(C_CVar.GetCVar) == "function" then
		return C_CVar.GetCVar
	end
	if type(GetCVar) == "function" then
		return GetCVar
	end
	return nil
end

local function getCVarSetter()
	if type(C_CVar) == "table" and type(C_CVar.SetCVar) == "function" then
		return C_CVar.SetCVar
	end
	if type(SetCVar) == "function" then
		return SetCVar
	end
	return nil
end

function FriendlyNames:GetCVarValue(cvarName)
	local getter = getCVarGetter()
	if not getter then
		return nil, false
	end

	local ok, value = pcall(getter, cvarName)
	value = ok and normalizeCVarValue(value) or nil
	return value, value ~= nil
end

function FriendlyNames:SetCVarValue(cvarName, value)
	local expectedValue = normalizeCVarValue(value)
	local currentValue, supported = self:GetCVarValue(cvarName)
	local setter = getCVarSetter()
	if not expectedValue or not supported or not setter then
		HTF:Debugf(HTF.L.DEBUG_FRIENDLY_NAMES_CVAR_FAILED, cvarName)
		return false, false
	end
	if currentValue == expectedValue then
		return true, false
	end

	local ok, result = pcall(setter, cvarName, expectedValue)
	if not ok or result == false then
		HTF:Debugf(HTF.L.DEBUG_FRIENDLY_NAMES_CVAR_FAILED, cvarName)
		return false, false
	end

	local updatedValue, updated = self:GetCVarValue(cvarName)
	if not updated or updatedValue ~= expectedValue then
		HTF:Debugf(HTF.L.DEBUG_FRIENDLY_NAMES_CVAR_FAILED, cvarName)
		return false, false
	end

	return true, true
end

function FriendlyNames:GetFontSize()
	return normalizeFontSize(HTF:GetSetting("friendlyNameFontSize"))
end

function FriendlyNames:SetFontSize(size)
	if not HTF.db then
		return
	end
	HTF:SetSetting("friendlyNameFontSize", normalizeFontSize(size))
end

function FriendlyNames:IsCustomFontSizeActive()
	return HTF:GetSetting("friendlyNamesOnly") == true and HTF:GetSetting("friendlyNameCustomFontSize") == true
end

function FriendlyNames:GetFontObjects()
	local objects = {}
	for _, name in ipairs(FONT_OBJECT_NAMES) do
		local fontObject = _G[name]
		if fontObject and type(fontObject.GetFont) == "function" and type(fontObject.SetFont) == "function" then
			table.insert(objects, { name = name, object = fontObject })
		end
	end
	return objects
end

function FriendlyNames:CaptureFontSnapshot()
	if self.fontSnapshot then
		return true
	end

	local fontObjects = self:GetFontObjects()
	if #fontObjects ~= #FONT_OBJECT_NAMES then
		return false
	end

	local snapshot = {}
	for _, entry in ipairs(fontObjects) do
		local ok, font, size, flags = pcall(entry.object.GetFont, entry.object)
		if not ok or type(font) ~= "string" or type(size) ~= "number" then
			return false
		end
		snapshot[entry.name] = {
			font = font,
			size = size,
			flags = flags,
		}
	end

	self.fontSnapshot = snapshot
	return true
end

function FriendlyNames:SetManagedFontSize(size)
	if not self.fontSnapshot then
		return false
	end

	local fontObjects = self:GetFontObjects()
	if #fontObjects ~= #FONT_OBJECT_NAMES then
		return false
	end

	local success = true
	for _, entry in ipairs(fontObjects) do
		local snapshot = self.fontSnapshot[entry.name]
		if not snapshot then
			success = false
		else
			local ok, result = pcall(entry.object.SetFont, entry.object, snapshot.font, size, snapshot.flags)
			if not ok or result == false then
				success = false
			end
		end
	end
	return success
end

function FriendlyNames:ApplyFontSize()
	if not self:IsCustomFontSizeActive() then
		return self:RestoreFontSize()
	end
	if not self:CaptureFontSnapshot() then
		return false
	end
	return self:SetManagedFontSize(self:GetFontSize())
end

function FriendlyNames:RestoreFontSize()
	if not self.fontSnapshot then
		return true
	end

	local fontObjects = self:GetFontObjects()
	if #fontObjects ~= #FONT_OBJECT_NAMES then
		return false
	end

	local success = true
	for _, entry in ipairs(fontObjects) do
		local snapshot = self.fontSnapshot[entry.name]
		if not snapshot then
			success = false
		else
			local ok, result = pcall(entry.object.SetFont, entry.object, snapshot.font, snapshot.size, snapshot.flags)
			if not ok or result == false then
				success = false
			end
		end
	end

	if success then
		self.fontSnapshot = nil
	end
	return success
end

function FriendlyNames:ScheduleFontRefresh()
	if self.fontRefreshScheduled or not self:IsCustomFontSizeActive() or not self:CaptureFontSnapshot() then
		return
	end

	local fontSize = self:GetFontSize()
	local refreshSize = fontSize > self.MIN_FONT_SIZE and fontSize - 1 or fontSize + 1
	if not self:SetManagedFontSize(refreshSize) then
		return
	end

	self.fontRefreshScheduled = true
	local function applyFontSize()
		self.fontRefreshScheduled = false
		self:ApplyFontSize()
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, applyFontSize)
	else
		applyFontSize()
	end
end

function FriendlyNames:IsFriendlyPlayerNameplate(unit)
	if type(unit) ~= "string" or not unit:match("^nameplate") then
		return false
	end
	if type(UnitIsFriend) ~= "function" then
		return false
	end

	local friendOk, isFriend = pcall(UnitIsFriend, "player", unit)
	if not friendOk or HTF:IsSecretValue(isFriend) or isFriend ~= true then
		return false
	end
	if type(UnitIsPlayer) == "function" then
		local playerOk, isPlayer = pcall(UnitIsPlayer, unit)
		if not playerOk or HTF:IsSecretValue(isPlayer) or isPlayer ~= true then
			return false
		end
	end
	return true
end

function FriendlyNames:GetNameplateComponents(unit)
	if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
		return nil, nil
	end

	local ok, unitFrame, name = pcall(function()
		local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
		local frame = namePlate and namePlate.UnitFrame
		return frame, frame and frame.name
	end)
	if not ok or HTF:IsSecretValue(unitFrame) or HTF:IsSecretValue(name) then
		return nil, nil
	end
	return unitFrame, name
end

function FriendlyNames:ApplyFontToNameplate(unit)
	if not self:IsCustomFontSizeActive() or not self:IsFriendlyPlayerNameplate(unit) then
		return false
	end

	local _, name = self:GetNameplateComponents(unit)
	local fontOk, font, _, flags = pcall(function()
		if not name or type(name.GetFont) ~= "function" or type(name.SetFont) ~= "function" then
			return nil
		end
		return name:GetFont()
	end)
	if not fontOk or type(font) ~= "string" then
		return false
	end
	local setOk, result = pcall(function()
		return name:SetFont(font, self:GetFontSize(), flags)
	end)
	return setOk and result ~= false
end

function FriendlyNames:GetClassColor(unit)
	if type(UnitClass) ~= "function" or type(RAID_CLASS_COLORS) ~= "table" then
		return nil
	end

	local classOk, _, classToken = pcall(UnitClass, unit)
	if not classOk or HTF:IsSecretValue(classToken) or type(classToken) ~= "string" then
		return nil
	end

	local color = RAID_CLASS_COLORS[classToken]
	if HTF:IsSecretValue(color) or type(color) ~= "table" then
		return nil
	end

	local r, g, b
	if type(color.GetRGB) == "function" then
		local colorOk
		colorOk, r, g, b = pcall(color.GetRGB, color)
		if not colorOk then
			r, g, b = nil, nil, nil
		end
	end
	r = r or color.r
	g = g or color.g
	b = b or color.b
	if not HTF:IsSafeNumber(r) or not HTF:IsSafeNumber(g) or not HTF:IsSafeNumber(b) then
		return nil
	end
	return r, g, b
end

function FriendlyNames:ApplyClassColorToNameplate(unit, name)
	if not HTF:GetSetting("friendlyNamesOnly") or not HTF:GetSetting("friendlyNameClassColors")
		or not self:IsFriendlyPlayerNameplate(unit) then
		return false
	end

	local r, g, b = self:GetClassColor(unit)
	if not r then
		return false
	end
	local colorOk, colorResult = pcall(function()
		if not name then
			return false
		end
		-- Blizzard's nameplate renderer colors its FontString through the
		-- texture vertex color, including during mouseover redraws.
		if type(name.SetVertexColor) == "function" then
			return name:SetVertexColor(r, g, b, 1)
		end
		if type(name.SetTextColor) == "function" then
			return name:SetTextColor(r, g, b, 1)
		end
		return false
	end)
	return colorOk and colorResult ~= false
end

function FriendlyNames:GetNameColorText(name)
	local colorOk, r, g, b = pcall(function()
		if not name then
			return nil
		end
		if type(name.GetVertexColor) == "function" then
			return name:GetVertexColor()
		end
		if type(name.GetTextColor) == "function" then
			return name:GetTextColor()
		end
		return nil
	end)
	if not colorOk then
		return "<unavailable>"
	end
	if HTF:IsSecretValue(r) or HTF:IsSecretValue(g) or HTF:IsSecretValue(b) then
		return "<restricted>"
	end
	if not HTF:IsSafeNumber(r) or not HTF:IsSafeNumber(g) or not HTF:IsSafeNumber(b) then
		return "<unavailable>"
	end
	return string.format("%.3f,%.3f,%.3f", r, g, b)
end

function FriendlyNames:GetExpectedClassColorText(unit)
	local r, g, b = self:GetClassColor(unit)
	if not r then
		return "<unavailable>"
	end
	return string.format("%.3f,%.3f,%.3f", r, g, b)
end

function FriendlyNames:ScheduleMouseoverColorDiagnostic(unitFrame, unit)
	if not HTF:GetSetting("debug") then
		return
	end

	self.pendingMouseoverDiagnostic = { unitFrame = unitFrame, unit = unit }
	if self.mouseoverDiagnosticScheduled then
		return
	end
	self.mouseoverDiagnosticScheduled = true

	local function logFollowUp()
		self.mouseoverDiagnosticScheduled = false
		local pending = self.pendingMouseoverDiagnostic
		self.pendingMouseoverDiagnostic = nil
		if not pending or not HTF:GetSetting("debug") then
			return
		end
		local frameOk, name = pcall(function()
			return pending.unitFrame and pending.unitFrame.name
		end)
		local colorText = frameOk and self:GetNameColorText(name) or "<unavailable>"
		HTF:Debugf(
			HTF.L.DEBUG_FRIENDLY_NAMES_MOUSEOVER_AFTER,
			pending.unit,
			colorText,
			self:GetExpectedClassColorText(pending.unit)
		)
	end

	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, logFollowUp)
	else
		logFollowUp()
	end
end

function FriendlyNames:ApplyMouseoverClassColor(unitFrame)
	if not HTF:GetSetting("friendlyNamesOnly") or not HTF:GetSetting("friendlyNameClassColors") then
		return false
	end

	local frameOk, unit, name = pcall(function()
		return unitFrame and (unitFrame.unit or unitFrame.displayedUnit), unitFrame and unitFrame.name
	end)
	if not frameOk or HTF:IsSecretValue(unit) or HTF:IsSecretValue(name) or type(unit) ~= "string" then
		return false
	end
	if type(UnitIsUnit) == "function" then
		local mouseoverOk, isMouseover = pcall(UnitIsUnit, unit, "mouseover")
		if not mouseoverOk or HTF:IsSecretValue(isMouseover) or isMouseover ~= true then
			return false
		end
	end
	if not self:IsFriendlyPlayerNameplate(unit) then
		return false
	end

	local beforeColor = HTF:GetSetting("debug") and self:GetNameColorText(name) or nil
	pcall(function()
		unitFrame.colorNameWithClassColor = true
	end)
	local applied = self:ApplyClassColorToNameplate(unit, name)
	if HTF:GetSetting("debug") then
		local stateOk, classColorState = pcall(function()
			return unitFrame.colorNameWithClassColor
		end)
		HTF:Debugf(
			HTF.L.DEBUG_FRIENDLY_NAMES_MOUSEOVER_TRACE,
			"UPDATE_MOUSEOVER_UNIT",
			unit,
			beforeColor,
			tostring(applied == true),
			self:GetNameColorText(name),
			stateOk and HTF:SafeScalarText(classColorState, "nil") or "<unavailable>"
		)
		self:ScheduleMouseoverColorDiagnostic(unitFrame, unit)
	end
	return applied
end

function FriendlyNames:RefreshClassColorForNameplate(unit)
	if not self:IsFriendlyPlayerNameplate(unit) then
		return false
	end

	local unitFrame, name = self:GetNameplateComponents(unit)
	if not unitFrame then
		return false
	end

	local updateOk, updateResult = pcall(function()
		if type(unitFrame.UpdateNameClassColor) ~= "function" then
			return false
		end
		return unitFrame:UpdateNameClassColor()
	end)
	local refreshed = updateOk and updateResult ~= false

	if not HTF:GetSetting("friendlyNamesOnly") or not HTF:GetSetting("friendlyNameClassColors") then
		return refreshed
	end
	return self:ApplyClassColorToNameplate(unit, name) or refreshed
end

function FriendlyNames:RefreshVisibleClassColors()
	if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlates) ~= "function" then
		return
	end

	local platesOk, namePlates = pcall(C_NamePlate.GetNamePlates)
	if not platesOk or type(namePlates) ~= "table" then
		return
	end

	for _, namePlate in ipairs(namePlates) do
		local unitOk, unit = pcall(function()
			local unitFrame = namePlate and namePlate.UnitFrame
			return namePlate and namePlate.namePlateUnitToken
				or unitFrame and (unitFrame.unit or unitFrame.displayedUnit)
		end)
		if unitOk and not HTF:IsSecretValue(unit) and type(unit) == "string" then
			self:RefreshClassColorForNameplate(unit)
		end
	end
end

function FriendlyNames:ScheduleClassColorRefresh()
	if self.classColorRefreshScheduled then
		return
	end

	self.classColorRefreshScheduled = true
	local function refresh()
		self.classColorRefreshScheduled = false
		self:RefreshVisibleClassColors()
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, refresh)
	else
		refresh()
	end
end

-- Blizzard applies the friendly-name mouseover color before class colors.
function FriendlyNames:ApplyClassColorMouseoverPolicy(refreshSnapshot)
	if type(NamePlateFriendlyFrameOptions) ~= "table" then
		return false
	end

	local preserveClassColor = HTF:GetSetting("friendlyNamesOnly") and HTF:GetSetting("friendlyNameClassColors")
	if preserveClassColor then
		local readOk, mouseoverColor = pcall(function()
			return NamePlateFriendlyFrameOptions.nameMouseoverColor
		end)
		if not readOk or HTF:IsSecretValue(mouseoverColor) then
			return false
		end
		if refreshSnapshot or not self.nameMouseoverColorSnapshotCaptured then
			self.nameMouseoverColorSnapshot = mouseoverColor
			self.nameMouseoverColorSnapshotCaptured = true
		end
		local clearOk = pcall(function()
			NamePlateFriendlyFrameOptions.nameMouseoverColor = nil
		end)
		return clearOk
	end

	if not self.nameMouseoverColorSnapshotCaptured then
		return true
	end
	local restoreOk = pcall(function()
		NamePlateFriendlyFrameOptions.nameMouseoverColor = self.nameMouseoverColorSnapshot
	end)
	if restoreOk then
		self.nameMouseoverColorSnapshot = nil
		self.nameMouseoverColorSnapshotCaptured = false
	end
	return restoreOk
end

function FriendlyNames:InstallNameplateOptionsHook()
	if self.nameplateOptionsHookInstalled then
		return true
	end
	if type(hooksecurefunc) ~= "function" or type(NamePlateDriverMixin) ~= "table"
		or type(NamePlateDriverMixin.UpdateNamePlateOptions) ~= "function" then
		return false
	end

	local hookOk = pcall(hooksecurefunc, NamePlateDriverMixin, "UpdateNamePlateOptions", function()
		self:ApplyClassColorMouseoverPolicy(true)
	end)
	if hookOk then
		self.nameplateOptionsHookInstalled = true
	end
	return hookOk
end

function FriendlyNames:InstallNameplateMouseoverHook()
	if self.nameplateMouseoverHookInstalled then
		return true
	end
	if type(hooksecurefunc) ~= "function" or type(CompactUnitFrame_OnEvent) ~= "function" then
		return false
	end

	-- Existing nameplates may already hold the original mixin script, so hook its global dispatcher.
	local hookOk = pcall(hooksecurefunc, "CompactUnitFrame_OnEvent", function(unitFrame, event)
		if event == "UPDATE_MOUSEOVER_UNIT" then
			if HTF:GetSetting("debug") then
				self.mouseoverHookCalls = (self.mouseoverHookCalls or 0) + 1
			end
			self:ApplyMouseoverClassColor(unitFrame)
		end
	end)
	if hookOk then
		self.nameplateMouseoverHookInstalled = true
	end
	return hookOk
end

function FriendlyNames:GetDiagnosticSummary()
	local values = {}
	for _, cvarName in ipairs(MANAGED_CVARS) do
		local value, supported = self:GetCVarValue(cvarName)
		values[cvarName] = supported and value or "<unavailable>"
	end
	local healthClassColors, healthClassColorsSupported = self:GetCVarValue(ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR)
	return string.format(
		"worldNames=%s, nameplates=%s, namesOnly=%s, nameClassColors=%s, healthClassColors=%s, optionsHook=%s, mouseoverHook=%s, mouseoverHookCalls=%d",
		values[FRIENDLY_PLAYER_NAMES_CVAR],
		values[FRIENDLY_PLAYER_NAMEPLATES_CVAR],
		values[FRIENDLY_PLAYER_NAMES_ONLY_CVAR],
		values[FRIENDLY_PLAYER_CLASS_COLORS_CVAR],
		healthClassColorsSupported and healthClassColors or "<unavailable>",
		tostring(self.nameplateOptionsHookInstalled == true),
		tostring(self.nameplateMouseoverHookInstalled == true),
		self.mouseoverHookCalls or 0
	)
end

function FriendlyNames:GetSnapshot()
	if not HTF.db then
		return nil
	end

	local snapshot = HTF.db.friendlyNamesOnlySnapshot
	if snapshot == nil then
		return nil
	end
	if type(snapshot) ~= "table" then
		HTF.db.friendlyNamesOnlySnapshot = nil
		HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_SNAPSHOT_INVALID)
		return nil
	end

	-- Version 0.6.0 briefly mistook the health-bar class-color CVar for the
	-- friendly-name CVar. Restore the value captured by that version first.
	local erroneousHealthColorValue = snapshot[ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR]
	if erroneousHealthColorValue ~= nil then
		erroneousHealthColorValue = normalizeCVarValue(erroneousHealthColorValue)
		if erroneousHealthColorValue == nil then
			snapshot[ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR] = nil
		else
			local restored = self:SetCVarValue(ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR, erroneousHealthColorValue)
			if restored then
				snapshot[ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR] = nil
			end
		end
	end

	-- The erroneous migration removed the original name-color snapshot. Its
	-- current value is the safest available restoration point for affected users.
	if snapshot[FRIENDLY_PLAYER_CLASS_COLORS_CVAR] == nil then
		local currentValue, supported = self:GetCVarValue(FRIENDLY_PLAYER_CLASS_COLORS_CVAR)
		if supported then
			snapshot[FRIENDLY_PLAYER_CLASS_COLORS_CVAR] = currentValue
		end
	end

	for _, cvarName in ipairs(MANAGED_CVARS) do
		if snapshot[cvarName] ~= nil then
			local normalizedValue = normalizeCVarValue(snapshot[cvarName])
			if normalizedValue == nil then
				HTF.db.friendlyNamesOnlySnapshot = nil
				HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_SNAPSHOT_INVALID)
				return nil
			end
			snapshot[cvarName] = normalizedValue
		end
	end

	if snapshot[FRIENDLY_PLAYER_NAMES_CVAR] == nil or snapshot[FRIENDLY_PLAYER_NAMEPLATES_CVAR] == nil then
		HTF.db.friendlyNamesOnlySnapshot = nil
		HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_SNAPSHOT_INVALID)
		return nil
	end

	return snapshot
end

function FriendlyNames:CaptureSnapshot()
	local existingSnapshot = self:GetSnapshot()
	if existingSnapshot then
		return existingSnapshot
	end

	local snapshot = {}
	for _, cvarName in ipairs(MANAGED_CVARS) do
		local value, supported = self:GetCVarValue(cvarName)
		if supported then
			snapshot[cvarName] = value
		end
	end

	if snapshot[FRIENDLY_PLAYER_NAMES_CVAR] == nil or snapshot[FRIENDLY_PLAYER_NAMEPLATES_CVAR] == nil then
		return nil
	end

	HTF.db.friendlyNamesOnlySnapshot = snapshot
	HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_SNAPSHOT_SAVED)
	return snapshot
end

function FriendlyNames:Apply()
	local snapshot = self:CaptureSnapshot()
	if not snapshot then
		return false
	end

	local success = true
	local changed = false
	self.changingCVars = true

	local namesSuccess, namesChanged = self:SetCVarValue(FRIENDLY_PLAYER_NAMES_CVAR, "1")
	success = namesSuccess and success
	changed = namesChanged or changed

	local namesOnlySuccess = true
	if snapshot[FRIENDLY_PLAYER_NAMES_ONLY_CVAR] ~= nil then
		local namesOnlyChanged
		namesOnlySuccess, namesOnlyChanged = self:SetCVarValue(FRIENDLY_PLAYER_NAMES_ONLY_CVAR, "1")
		success = namesOnlySuccess and success
		changed = namesOnlyChanged or changed
	end

	if snapshot[FRIENDLY_PLAYER_CLASS_COLORS_CVAR] ~= nil then
		local classColorsSuccess, classColorsChanged = self:SetCVarValue(
			FRIENDLY_PLAYER_CLASS_COLORS_CVAR,
			HTF:GetSetting("friendlyNameClassColors") and "1" or "0"
		)
		success = classColorsSuccess and success
		changed = classColorsChanged or changed
	end

	-- Never expose friendly health bars when either prerequisite cannot be applied.
	local nameplatesValue = namesSuccess and namesOnlySuccess
		and snapshot[FRIENDLY_PLAYER_NAMES_ONLY_CVAR] ~= nil
		and "1"
		or "0"
	local nameplatesSuccess, nameplatesChanged = self:SetCVarValue(FRIENDLY_PLAYER_NAMEPLATES_CVAR, nameplatesValue)
	success = nameplatesSuccess and success
	changed = nameplatesChanged or changed
	self.changingCVars = false
	self:ApplyClassColorMouseoverPolicy()
	self:ApplyFontSize()
	self:ScheduleClassColorRefresh()

	if success and changed then
		HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_APPLIED)
	end
	return success
end

function FriendlyNames:Restore()
	local snapshot = self:GetSnapshot()
	if not snapshot then
		self:ApplyClassColorMouseoverPolicy()
		return self:RestoreFontSize()
	end

	local success = true
	self.changingCVars = true
	for _, cvarName in ipairs(MANAGED_CVARS) do
		local originalValue = snapshot[cvarName]
		if originalValue ~= nil then
			local cvarSuccess = self:SetCVarValue(cvarName, originalValue)
			success = cvarSuccess and success
		end
	end
	self.changingCVars = false
	self:ApplyClassColorMouseoverPolicy()
	success = self:RestoreFontSize() and success
	self:ScheduleClassColorRefresh()

	if success then
		HTF.db.friendlyNamesOnlySnapshot = nil
		HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_RESTORED)
	end
	return success
end

function FriendlyNames:Synchronize()
	if not HTF.db then
		return false
	end
	if HTF:GetSetting("friendlyNamesOnly") then
		return self:Apply()
	end
	return self:Restore()
end

function FriendlyNames:ScheduleSynchronize()
	if self.synchronizeScheduled then
		return
	end

	self.synchronizeScheduled = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, function()
			self.synchronizeScheduled = false
			self:Synchronize()
		end)
	else
		self.synchronizeScheduled = false
		self:Synchronize()
	end
end

function FriendlyNames:OnSettingChanged()
	if HTF:GetSetting("friendlyNamesOnly") then
		local success = self:Apply()
		if self:IsCustomFontSizeActive() then
			self:ScheduleFontRefresh()
		end
		if not success then
			if self:GetSnapshot() then
				HTF:Notify(HTF.L.FRIENDLY_NAMES_APPLY_PENDING)
			else
				HTF.db.friendlyNamesOnly = false
				HTF:Notify(HTF.L.FRIENDLY_NAMES_UNAVAILABLE)
			end
		end
		return
	end

	if not self:Restore() and self:GetSnapshot() then
		HTF:Notify(HTF.L.FRIENDLY_NAMES_RESTORE_PENDING)
	end
end

function FriendlyNames:OnEvent(event, cvarName)
	if event == "CVAR_UPDATE" then
		if self.changingCVars or type(cvarName) ~= "string" or not relevantCVarNames[string.lower(cvarName)] then
			return
		end
		if HTF:GetSetting("friendlyNamesOnly") or self:GetSnapshot() then
			self:ScheduleSynchronize()
		end
		return
	end

	if event == "NAME_PLATE_UNIT_ADDED" then
		self:RefreshClassColorForNameplate(cvarName)
		if self:IsCustomFontSizeActive() and self:IsFriendlyPlayerNameplate(cvarName) and not self:ApplyFontToNameplate(cvarName) then
			self:ScheduleFontRefresh()
		end
		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
		self:InstallNameplateOptionsHook()
		self:InstallNameplateMouseoverHook()
		self:ScheduleSynchronize()
		self:ScheduleFontRefresh()
	end
end

function FriendlyNames:Initialize()
	if self.initialized then
		return
	end

	if type(HTF.db.friendlyNamesOnly) ~= "boolean" then
		HTF.db.friendlyNamesOnly = false
	end
	if type(HTF.db.friendlyNameClassColors) ~= "boolean" then
		HTF.db.friendlyNameClassColors = false
	end
	if type(HTF.db.friendlyNameCustomFontSize) ~= "boolean" then
		HTF.db.friendlyNameCustomFontSize = false
	end
	HTF.db.friendlyNameFontSize = normalizeFontSize(HTF.db.friendlyNameFontSize)

	self.initialized = true
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("CVAR_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	self.eventFrame:SetScript("OnEvent", function(_, event, ...)
		self:OnEvent(event, ...)
	end)
	self:InstallNameplateOptionsHook()
	self:InstallNameplateMouseoverHook()
	self:Synchronize()
end
