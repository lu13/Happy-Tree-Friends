local ADDON_NAME, HTF = ...

HTF.ADDON_NAME = ADDON_NAME
HTF.VERSION = "0.5.0"
HTF.MAX_DEBUG_LOG_ENTRIES = 80
HTF.debugLog = {}

HTF.defaults = {
	autoRepair = false,
	repairFromGuild = false,
	autoSellJunk = false,
	protectedJunkItems = {},
	friendlyNamesOnly = false,
	showStats = true,
	statsLocked = true,
	statsFontSize = 15,
	statsPosition = {
		point = "TOPRIGHT",
		relativePoint = "TOPRIGHT",
		x = -70,
		y = -260,
	},
	statsVisibility = {
		strength = true,
		agility = true,
		stamina = true,
		intellect = true,
		armor = true,
		criticalStrike = true,
		haste = true,
		mastery = true,
		versatility = true,
		lifesteal = true,
		avoidance = true,
		speed = true,
		dodge = true,
		parry = true,
		durability = false,
		bagSpace = false,
		money = false,
		latency = false,
	},
	statsColors = {
		strength = { 0.96, 0.45, 0.42 },
		agility = { 0.42, 0.91, 0.62 },
		stamina = { 0.95, 0.68, 0.33 },
		intellect = { 0.44, 0.69, 1.00 },
		armor = { 0.74, 0.78, 0.86 },
		criticalStrike = { 1.00, 0.43, 0.50 },
		haste = { 0.96, 0.82, 0.34 },
		mastery = { 0.73, 0.55, 1.00 },
		versatility = { 0.31, 0.87, 0.81 },
		lifesteal = { 0.94, 0.48, 0.78 },
		avoidance = { 0.36, 0.76, 0.96 },
		speed = { 0.48, 0.93, 0.68 },
		dodge = { 0.69, 0.88, 0.34 },
		parry = { 1.00, 0.61, 0.31 },
		durability = { 0.95, 0.74, 0.35 },
		bagSpace = { 0.39, 0.83, 0.98 },
		money = { 1.00, 0.84, 0.30 },
		latency = { 0.64, 0.76, 1.00 },
	},
	showNotifications = true,
	debug = false,
	debugLog = {},
}

local function mergeDefaults(target, defaults)
	for key, defaultValue in pairs(defaults) do
		if type(defaultValue) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			mergeDefaults(target[key], defaultValue)
		elseif target[key] == nil then
			target[key] = defaultValue
		end
	end
end

local function normalizeDebugLog(log, maximumEntries)
	local normalized = {}
	if type(log) ~= "table" then
		return normalized
	end

	for _, line in ipairs(log) do
		if type(line) == "string" then
			table.insert(normalized, line)
			if #normalized > maximumEntries then
				table.remove(normalized, 1)
			end
		end
	end

	return normalized
end

function HTF:InitializeDatabase()
	if type(HappyTreeFriendsDB) ~= "table" then
		HappyTreeFriendsDB = {}
	end

	mergeDefaults(HappyTreeFriendsDB, self.defaults)
	self.db = HappyTreeFriendsDB
	self.db.debugLog = normalizeDebugLog(self.db.debugLog, self.MAX_DEBUG_LOG_ENTRIES)
	self.debugLog = self.db.debugLog
end

function HTF:GetSetting(key)
	return self.db and self.db[key]
end

function HTF:SetSetting(key, value)
	if not self.db then
		return
	end

	self.db[key] = value
	if self.FriendlyNames and self.FriendlyNames.OnSettingChanged and key == "friendlyNamesOnly" then
		self.FriendlyNames:OnSettingChanged()
	end
	if self.Stats and self.Stats.OnSettingChanged then
		self.Stats:OnSettingChanged(key)
	end
	if self.Options and self.Options.Refresh then
		self.Options:Refresh()
	end
end

function HTF:IsSecretValue(value)
	return type(issecretvalue) == "function" and issecretvalue(value) or false
end

function HTF:IsSafeNumber(value)
	if self:IsSecretValue(value) then
		return false
	end

	return type(value) == "number"
end

function HTF:SafeString(value, fallback)
	if self:IsSecretValue(value) or type(value) ~= "string" or value == "" then
		return fallback or ""
	end

	return value
end

function HTF:SafeScalarText(value, fallback)
	if self:IsSecretValue(value) then
		return "<restricted>"
	end

	local valueType = type(value)
	if valueType == "string" then
		return value ~= "" and value or (fallback or "unknown")
	end
	if valueType == "number" or valueType == "boolean" then
		return tostring(value)
	end

	return fallback or "unknown"
end

function HTF:Notify(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff6ee7b7[HTF]|r " .. message)
	end
end

function HTF:Debug(message)
	if not self.db or not self.db.debug then
		return
	end

	if type(self.debugLog) ~= "table" then
		self.debugLog = {}
		self.db.debugLog = self.debugLog
	end

	local timestamp = date and date("%Y-%m-%d %H:%M:%S") or "---- -- -- --:--:--"
	local line = string.format("[%s] %s", timestamp, self:SafeScalarText(message, "<unsupported message>"))
	table.insert(self.debugLog, line)
	if #self.debugLog > self.MAX_DEBUG_LOG_ENTRIES then
		table.remove(self.debugLog, 1)
	end

	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff8db7ff[HTF Debug]|r " .. line)
	end

	if self.Options and self.Options.RefreshDebugLog then
		self.Options:RefreshDebugLog()
	end
end

function HTF:ClearDebugLog()
	if type(self.debugLog) ~= "table" then
		self.debugLog = {}
	else
		for key in pairs(self.debugLog) do
			self.debugLog[key] = nil
		end
	end

	if self.db then
		self.db.debugLog = self.debugLog
	end
	if self.Options and self.Options.ShowDebugLog then
		self.Options:ShowDebugLog()
	elseif self.Options and self.Options.RefreshDebugLog then
		self.Options:RefreshDebugLog()
	end
end

function HTF:BuildDiagnosticReport()
	local gameVersion, buildNumber, buildDate, interfaceVersion
	if type(GetBuildInfo) == "function" then
		gameVersion, buildNumber, buildDate, interfaceVersion = GetBuildInfo()
	end

	local locale = type(GetLocale) == "function" and GetLocale() or nil
	local inCombat = type(InCombatLockdown) == "function" and InCombatLockdown() or false
	local inCombatText = self:IsSecretValue(inCombat) and "<restricted>" or tostring(inCombat == true)
	local merchant = self.Merchant or {}
	local ledger = merchant.GetSessionLedger and merchant:GetSessionLedger() or nil
	local timestamp = date and date("%Y-%m-%d %H:%M:%S") or "unknown"
	local lines = {
		"Happy Tree Friends - Diagnostic Report",
		"Generated: " .. timestamp,
		"Addon version: " .. self.VERSION,
		"WoW version: " .. self:SafeScalarText(gameVersion),
		"WoW build: " .. self:SafeScalarText(buildNumber),
		"Build date: " .. self:SafeScalarText(buildDate),
		"Interface: " .. self:SafeScalarText(interfaceVersion),
		"Locale: " .. self:SafeScalarText(locale),
		"In combat lockdown: " .. inCombatText,
		"Merchant open: " .. tostring(merchant.merchantOpen == true),
		"Merchant action pending: " .. tostring(merchant.pendingRun == true),
		"Protected junk item IDs: " .. tostring(merchant.GetProtectedJunkItemCount and merchant:GetProtectedJunkItemCount() or 0),
		"",
		"Settings:",
	}

	for _, key in ipairs({ "autoRepair", "repairFromGuild", "autoSellJunk", "friendlyNamesOnly", "showStats", "statsLocked", "showNotifications", "debug" }) do
		table.insert(lines, string.format("- %s: %s", key, tostring(self:GetSetting(key) == true)))
	end
	table.insert(lines, string.format("- statsFontSize: %s", self:SafeScalarText(self:GetSetting("statsFontSize"))))
	if self.Stats then
		table.insert(lines, string.format("- visibleStats: %d/%d", self.Stats:GetVisibleStatCount(), #self.Stats.STAT_DEFINITIONS))
		table.insert(lines, string.format("- visibleAdventureStatus: %d/%d", self.Stats:GetVisibleAdventureStatusCount(), #self.Stats.ADVENTURE_DEFINITIONS))
		table.insert(lines, "- statsPosition: " .. self.Stats:GetPositionSummary())
	end
	if ledger then
		table.insert(lines, string.format("- sessionRepairs: %s", self:FormatMoney(ledger.repairTotal)))
		table.insert(lines, string.format("- sessionJunkIncome: %s", ledger.junkIncomeKnown and self:FormatMoney(ledger.junkIncome) or "<unavailable>"))
		table.insert(lines, string.format("- sessionProtectedJunkSkipped: %d", #ledger.skippedItemOrder))
	end

	table.insert(lines, "")
	table.insert(lines, string.format("Persisted debug log (%d/%d):", #self.debugLog, self.MAX_DEBUG_LOG_ENTRIES))
	if #self.debugLog == 0 then
		table.insert(lines, "<empty>")
	else
		for _, line in ipairs(self.debugLog) do
			table.insert(lines, line)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "Privacy: no account, character, or realm identifiers are included.")
	return table.concat(lines, "\n")
end

function HTF:Debugf(formatText, ...)
	if not self.db or not self.db.debug then
		return
	end

	local ok, message = pcall(string.format, formatText, ...)
	self:Debug(ok and message or formatText)
end

function HTF:FormatMoney(copper)
	if not self:IsSafeNumber(copper) then
		return "—"
	end

	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local remainingCopper = copper % 100
	local parts = {}

	if gold > 0 then
		table.insert(parts, string.format("%d|cffffd700%s|r", gold, self.L.MONEY_GOLD))
	end
	if silver > 0 or gold > 0 then
		table.insert(parts, string.format("%d|cffc7c7cf%s|r", silver, self.L.MONEY_SILVER))
	end
	table.insert(parts, string.format("%d|cffeda55f%s|r", remainingCopper, self.L.MONEY_COPPER))

	return table.concat(parts, " ")
end

local function trim(value)
	return (value or ""):match("^%s*(.-)%s*$")
end

function HTF:OpenOptions(page)
	if self.Options and self.Options.Open then
		self.Options:Open(page)
	end
end

function HTF:HandleSlashCommand(input)
	local rawInput = trim(input)
	local command, argument = rawInput:match("^(%S+)%s*(.-)$")
	command = string.lower(command or "")
	argument = trim(argument)

	if command == "debug" then
		local enabled = not self:GetSetting("debug")
		self:SetSetting("debug", enabled)
		self:Notify(enabled and self.L.DEBUG_MODE_ENABLED or self.L.DEBUG_MODE_DISABLED)
		if enabled then
			self:Debug(self.L.DEBUG_MODE_ENABLED)
		end
		return
	end

	if command == "stats" or command == self.L.COMMAND_STATS_ALIAS then
		self:OpenOptions("stats")
		return
	end

	if command == "merchant" or command == self.L.COMMAND_MERCHANT_ALIAS then
		self:OpenOptions("merchant")
		return
	end

	if command == "nameplates" or command == self.L.COMMAND_NAMEPLATES_ALIAS then
		self:OpenOptions("nameplates")
		return
	end

	if command == "protect" or command == self.L.COMMAND_PROTECT_ALIAS then
		local itemID = self.Merchant and self.Merchant:ExtractItemID(argument)
		if not itemID or not self.Merchant:SetJunkItemProtected(itemID, true) then
			self:Notify(self.L.JUNK_PROTECTION_USAGE)
			return
		end
		self:Notify(string.format(self.L.JUNK_PROTECTION_ADDED, itemID))
		return
	end

	if command == "unprotect" or command == self.L.COMMAND_UNPROTECT_ALIAS then
		local itemID = self.Merchant and self.Merchant:ExtractItemID(argument)
		if not itemID or not self.Merchant:SetJunkItemProtected(itemID, false) then
			self:Notify(self.L.JUNK_PROTECTION_USAGE)
			return
		end
		self:Notify(string.format(self.L.JUNK_PROTECTION_REMOVED, itemID))
		return
	end

	if command == "protected" or command == self.L.COMMAND_PROTECTED_ALIAS then
		local itemIDs = self.Merchant and self.Merchant:GetProtectedJunkItemIDs() or {}
		if #itemIDs == 0 then
			self:Notify(self.L.JUNK_PROTECTION_EMPTY)
			return
		end
		local labels = {}
		for _, itemID in ipairs(itemIDs) do
			table.insert(labels, "#" .. tostring(itemID))
		end
		self:Notify(string.format(self.L.JUNK_PROTECTION_LIST, table.concat(labels, ", ")))
		return
	end

	if command == "help" or command == self.L.COMMAND_HELP_ALIAS then
		self:Notify(self.L.SLASH_HELP)
		return
	end

	if command == "dump" or command == self.L.COMMAND_DUMP_ALIAS then
		if self.Options and self.Options.OpenDiagnosticReport then
			self.Options:OpenDiagnosticReport()
		else
			self:Notify(self.L.DIAGNOSTIC_UNAVAILABLE)
		end
		return
	end

	if command == "clearlog" or command == self.L.COMMAND_CLEAR_LOG_ALIAS then
		self:ClearDebugLog()
		self:Notify(self.L.DEBUG_CLEARED)
		return
	end

	self:OpenOptions("overview")
end

function HTF:RegisterSlashCommands()
	SLASH_HAPPYTREEFRIENDS1 = "/htf"
	SLASH_HAPPYTREEFRIENDS2 = "/happytreefriends"
	SlashCmdList.HAPPYTREEFRIENDS = function(input)
		HTF:HandleSlashCommand(input)
	end
end

function HTF:Initialize()
	if self.initialized then
		return
	end

	self:InitializeDatabase()
	self:RegisterSlashCommands()

	if self.Merchant then
		self.Merchant:Initialize()
	end
	if self.FriendlyNames then
		self.FriendlyNames:Initialize()
	end
	if self.Stats then
		self.Stats:Initialize()
	end
	if self.Options then
		self.Options:Initialize()
	end

	self.initialized = true
	self:Debug(self.L.DEBUG_INITIALIZED)
end

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(_, _, loadedAddon)
	if loadedAddon ~= ADDON_NAME then
		return
	end

	bootstrapFrame:UnregisterEvent("ADDON_LOADED")
	HTF:Initialize()
end)
