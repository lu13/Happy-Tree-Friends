local ADDON_NAME, HTF = ...

HTF.ADDON_NAME = ADDON_NAME
HTF.VERSION = "0.1.1"
HTF.MAX_DEBUG_LOG_ENTRIES = 80
HTF.debugLog = {}

HTF.defaults = {
	autoRepair = false,
	autoSellJunk = false,
	showStats = true,
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
		"",
		"Settings:",
	}

	for _, key in ipairs({ "autoRepair", "autoSellJunk", "showStats", "showNotifications", "debug" }) do
		table.insert(lines, string.format("- %s: %s", key, tostring(self:GetSetting(key) == true)))
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
		table.insert(parts, string.format("%d|cffffd700金|r", gold))
	end
	if silver > 0 or gold > 0 then
		table.insert(parts, string.format("%d|cffc7c7cf银|r", silver))
	end
	table.insert(parts, string.format("%d|cffeda55f铜|r", remainingCopper))

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
	local command = string.lower(trim(input))

	if command == "debug" then
		local enabled = not self:GetSetting("debug")
		self:SetSetting("debug", enabled)
		self:Notify(enabled and "调试模式已开启。" or "调试模式已关闭。")
		if enabled then
			self:Debug("调试模式已开启。")
		end
		return
	end

	if command == "stats" or command == "属性" then
		self:OpenOptions("stats")
		return
	end

	if command == "merchant" or command == "商人" then
		self:OpenOptions("merchant")
		return
	end

	if command == "help" or command == "帮助" then
		self:Notify("/htf — 设置；/htf stats — 角色属性；/htf debug — 调试开关；/htf dump — 可复制诊断报告；/htf clearlog — 清空日志。")
		return
	end

	if command == "dump" or command == "诊断" then
		if self.Options and self.Options.OpenDiagnosticReport then
			self.Options:OpenDiagnosticReport()
		else
			self:Notify("诊断界面将在角色进入世界后可用。")
		end
		return
	end

	if command == "clearlog" or command == "清空日志" then
		self:ClearDebugLog()
		self:Notify("调试日志已清空。")
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
	if self.Stats then
		self.Stats:Initialize()
	end
	if self.Options then
		self.Options:Initialize()
	end

	self.initialized = true
	self:Debug("初始化完成。")
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
