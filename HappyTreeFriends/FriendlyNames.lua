local _, HTF = ...

local FriendlyNames = {}
HTF.FriendlyNames = FriendlyNames

local FRIENDLY_PLAYER_NAMES_CVAR = "UnitNameFriendlyPlayerName"
local FRIENDLY_PLAYER_NAMEPLATES_CVAR = "nameplateShowFriendlyPlayers"
local FRIENDLY_PLAYER_NAMES_ONLY_CVAR = "nameplateShowOnlyNameForFriendlyPlayerUnits"

local MANAGED_CVARS = {
	FRIENDLY_PLAYER_NAMES_CVAR,
	FRIENDLY_PLAYER_NAMES_ONLY_CVAR,
	FRIENDLY_PLAYER_NAMEPLATES_CVAR,
}

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

	if success and changed then
		HTF:Debug(HTF.L.DEBUG_FRIENDLY_NAMES_APPLIED)
	end
	return success
end

function FriendlyNames:Restore()
	local snapshot = self:GetSnapshot()
	if not snapshot then
		return true
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

	if event == "PLAYER_ENTERING_WORLD" then
		self:ScheduleSynchronize()
	end
end

function FriendlyNames:Initialize()
	if self.initialized then
		return
	end

	if type(HTF.db.friendlyNamesOnly) ~= "boolean" then
		HTF.db.friendlyNamesOnly = false
	end

	self.initialized = true
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("CVAR_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.eventFrame:SetScript("OnEvent", function(_, event, ...)
		self:OnEvent(event, ...)
	end)
	self:Synchronize()
end
