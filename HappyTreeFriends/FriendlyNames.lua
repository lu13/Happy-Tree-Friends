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

function FriendlyNames:ApplyFontToNameplate(unit)
	if not self:IsCustomFontSizeActive() or not self:IsFriendlyPlayerNameplate(unit)
		or type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
		return false
	end

	local ok, name = pcall(function()
		local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
		return namePlate and namePlate.UnitFrame and namePlate.UnitFrame.name
	end)
	if not ok or not name or type(name.GetFont) ~= "function" or type(name.SetFont) ~= "function" then
		return false
	end

	local fontOk, font, _, flags = pcall(name.GetFont, name)
	if not fontOk or type(font) ~= "string" then
		return false
	end
	local setOk, result = pcall(name.SetFont, name, font, self:GetFontSize(), flags)
	return setOk and result ~= false
end

function FriendlyNames:GetSnapshot()
	if not HTF.db then
		return nil
	end
	self.removedClassColorCleanupPending = false

	local snapshot = HTF.db.friendlyNamesOnlySnapshot
	if snapshot == nil then
		if self.removedClassColorsActive then
			local restored = self:SetCVarValue(FRIENDLY_PLAYER_CLASS_COLORS_CVAR, "0")
			if restored then
				self.removedClassColorsActive = false
			end
		end
		return nil
	end
	if type(snapshot) ~= "table" then
		HTF.db.friendlyNamesOnlySnapshot = nil
		HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_SNAPSHOT_INVALID)
		return nil
	end

	-- Version 0.6.0 briefly managed the friendly health-bar class-color CVar
	-- by mistake. Restore the captured value, then remove that migration key.
	local healthColorValue = snapshot[ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR]
	local hasErroneousColorSnapshot = healthColorValue ~= nil
	local cleanupPending = false
	if healthColorValue ~= nil then
		healthColorValue = normalizeCVarValue(healthColorValue)
		if healthColorValue == nil then
			snapshot[ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR] = nil
		else
			local restored = self:SetCVarValue(ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR, healthColorValue)
			if restored then
				snapshot[ERRONEOUS_FRIENDLY_HEALTH_CLASS_COLORS_CVAR] = nil
			else
				cleanupPending = true
			end
		end
	end

	-- Restore and stop managing the removed name-color feature. The erroneous
	-- 0.6.0 migration lost this value, so use the feature's original default.
	local nameColorValue = snapshot[FRIENDLY_PLAYER_CLASS_COLORS_CVAR]
	if self.removedClassColorsActive or (nameColorValue == nil and hasErroneousColorSnapshot) then
		nameColorValue = "0"
	end
	if nameColorValue ~= nil then
		nameColorValue = normalizeCVarValue(nameColorValue)
		if nameColorValue == nil then
			snapshot[FRIENDLY_PLAYER_CLASS_COLORS_CVAR] = nil
		else
			local restored = self:SetCVarValue(FRIENDLY_PLAYER_CLASS_COLORS_CVAR, nameColorValue)
			if restored then
				snapshot[FRIENDLY_PLAYER_CLASS_COLORS_CVAR] = nil
				self.removedClassColorsActive = false
			else
				cleanupPending = true
			end
		end
	end
	self.removedClassColorCleanupPending = cleanupPending

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

	-- Never expose friendly health bars when either prerequisite cannot be applied.
	local nameplatesValue = namesSuccess and namesOnlySuccess
		and snapshot[FRIENDLY_PLAYER_NAMES_ONLY_CVAR] ~= nil
		and "1"
		or "0"
	local nameplatesSuccess, nameplatesChanged = self:SetCVarValue(FRIENDLY_PLAYER_NAMEPLATES_CVAR, nameplatesValue)
	success = nameplatesSuccess and success
	changed = nameplatesChanged or changed
	self.changingCVars = false
	self:ApplyFontSize()

	if success and changed then
		HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_APPLIED)
	end
	return success
end

function FriendlyNames:Restore()
	local snapshot = self:GetSnapshot()
	if not snapshot then
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
	success = self:RestoreFontSize() and success
	success = not self.removedClassColorCleanupPending and success

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
		if self:IsCustomFontSizeActive() and self:IsFriendlyPlayerNameplate(cvarName) and not self:ApplyFontToNameplate(cvarName) then
			self:ScheduleFontRefresh()
		end
		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
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
	self.removedClassColorsActive = HTF.db.friendlyNamesOnly == true and HTF.db.friendlyNameClassColors == true
	HTF.db.friendlyNameClassColors = nil
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
	self:Synchronize()
end
