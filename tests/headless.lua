local checks = 0

local function check(condition, message)
	checks = checks + 1
	if not condition then
		error(message or "check failed", 2)
	end
end

local function equal(actual, expected, message)
	check(actual == expected, string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)))
end

local function contains(haystack, needle, message)
	check(type(haystack) == "string" and haystack:find(needle, 1, true) ~= nil, message or ("missing text: " .. needle))
end

local testLocale = os.getenv and os.getenv("HTF_TEST_LOCALE") or "zhCN"
check(testLocale == "zhCN" or testLocale == "enUS", "HTF_TEST_LOCALE must be zhCN or enUS")
local activeClientLocale = testLocale

local SECRET = setmetatable({}, {
	__tostring = function()
		error("secret value must not be converted to text")
	end,
})

function issecretvalue(value)
	return value == SECRET
end

date = os.date
SlashCmdList = {}
UISpecialFrames = {}
ChatFontNormal = "ChatFontNormal"
GameFontHighlightSmall = "GameFontHighlightSmall"

local chatMessages = {}
DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, message)
		table.insert(chatMessages, message)
	end,
}

local frames = {}
local timers = {}

local objectMethods = {}

function objectMethods:SetScript(scriptName, handler)
	self.scripts[scriptName] = handler
end

function objectMethods:RegisterEvent(event)
	self.events[event] = true
end

function objectMethods:UnregisterEvent(event)
	self.events[event] = nil
end

function objectMethods:SetPoint(...)
	table.insert(self.points, { ... })
end

function objectMethods:GetPoint(index)
	local point = self.points[index or 1]
	if not point then
		return nil
	end
	local unpackValues = table.unpack or unpack
	return unpackValues(point)
end

function objectMethods:ClearAllPoints()
	self.points = {}
end

function objectMethods:SetAllPoints(target)
	self.points = { { "ALL", target or self.parent } }
end

function objectMethods:SetSize(width, height)
	self.width = width
	self.height = height
end

function objectMethods:SetWidth(width)
	self.width = width
end

function objectMethods:SetHeight(height)
	self.height = height
end

function objectMethods:GetWidth()
	return self.width or 174
end

function objectMethods:GetHeight()
	return self.height or 174
end

function objectMethods:Show()
	local wasShown = self.shown
	self.shown = true
	if not wasShown and self.scripts.OnShow then
		self.scripts.OnShow(self)
	end
end

function objectMethods:Hide()
	self.shown = false
end

function objectMethods:IsShown()
	return self.shown == true
end

function objectMethods:IsVisible()
	if not self:IsShown() then
		return false
	end
	if self.parent and type(self.parent.IsVisible) == "function" then
		return self.parent:IsVisible()
	end
	return true
end

function objectMethods:CreateFontString(_, _, template)
	return CreateFrame("FontString", nil, self, template)
end

function objectMethods:CreateTexture()
	return CreateFrame("Texture", nil, self)
end

function objectMethods:GetName()
	return self.frameName
end

function objectMethods:SetText(text)
	self.text = text or ""
end

function objectMethods:GetText()
	return self.text or ""
end

function objectMethods:GetFont()
	return self.font or "MockFont", self.fontSize or 12, self.fontFlags or "OUTLINE"
end

function objectMethods:SetFont(font, size, flags)
	self.font = font
	self.fontSize = size
	self.fontFlags = flags
	return true
end

function objectMethods:SetShadowColor(r, g, b, a)
	self.shadowColor = { r, g, b, a }
end

function objectMethods:SetShadowOffset(x, y)
	self.shadowOffset = { x, y }
end

function objectMethods:GetStringHeight()
	local text = self.text or ""
	local lines = 1
	for _ in text:gmatch("\n") do
		lines = lines + 1
	end
	return lines * 14
end

function objectMethods:SetFocus()
	self.focused = true
end

function objectMethods:ClearFocus()
	self.focused = false
end

function objectMethods:HighlightText()
	self.highlighted = true
end

function objectMethods:SetBackdropColor(r, g, b, a)
	self.backdropColor = { r, g, b, a }
end

function objectMethods:SetBackdropBorderColor(r, g, b, a)
	self.backdropBorderColor = { r, g, b, a }
end

function objectMethods:SetTextColor(r, g, b, a)
	self.textColor = { r, g, b, a }
end

function objectMethods:GetTextColor()
	local color = self.textColor or { 1, 1, 1, 1 }
	return color[1], color[2], color[3], color[4]
end

function objectMethods:SetVertexColor(r, g, b, a)
	self.vertexColor = { r, g, b, a }
end

function objectMethods:GetVertexColor()
	local color = self.vertexColor or self.textColor or { 1, 1, 1, 1 }
	return color[1], color[2], color[3], color[4]
end

function objectMethods:SetColorTexture(r, g, b, a)
	self.textureColor = { r, g, b, a }
end

function objectMethods:EnableMouse(enabled)
	self.mouseEnabled = enabled == true
end

function objectMethods:SetMovable(movable)
	self.movable = movable == true
end

function objectMethods:SetResizable(resizable)
	self.resizable = resizable == true
end

function objectMethods:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
	self.resizeBounds = { minWidth, minHeight, maxWidth, maxHeight }
end

function objectMethods:SetClampedToScreen(clamped)
	self.clampedToScreen = clamped == true
end

function objectMethods:SetScale(scale)
	self.scale = scale
end

function objectMethods:GetScale()
	return self.scale or 1
end

function objectMethods:RegisterForDrag(...)
	self.dragButtons = { ... }
end

function objectMethods:StartMoving()
	self.moving = true
end

function objectMethods:StartSizing(anchor)
	self.sizing = anchor
end

function objectMethods:StopMovingOrSizing()
	self.moving = false
	self.sizing = nil
	self.stoppedMoving = true
end

local noOpMethods = {
	"SetBackdrop",
	"SetJustifyH",
	"SetJustifyV",
	"SetTexture",
	"SetFrameStrata",
	"SetToplevel",
	"SetMultiLine",
	"SetAutoFocus",
	"SetFontObject",
	"SetTextInsets",
	"SetCursorPosition",
	"SetVerticalScroll",
	"SetScrollChild",
}

for _, methodName in ipairs(noOpMethods) do
	objectMethods[methodName] = function()
	end
end

local function newObject(kind, name, parent, template)
	local object = setmetatable({
		kind = kind,
		name = name,
		frameName = name,
		parent = parent,
		template = template,
		shown = true,
		scripts = {},
		events = {},
		points = {},
		text = "",
	}, { __index = objectMethods })
	table.insert(frames, object)
	return object
end

UIParent = newObject("Frame", "UIParent", nil)
SystemFont_NamePlate = newObject("Font", "SystemFont_NamePlate", UIParent)
SystemFont_NamePlate:SetFont("MockNameplateFont", 12, "")
SystemFont_NamePlate_Outlined = newObject("Font", "SystemFont_NamePlate_Outlined", UIParent)
SystemFont_NamePlate_Outlined:SetFont("MockNameplateOutlineFont", 13, "OUTLINE")

function CreateFrame(kind, name, parent, template)
	local object = newObject(kind, name, parent, template)
	if template == "UIPanelScrollFrameTemplate" then
		-- Retail 12.1 exposes the template-created scrollbar through parentKey,
		-- so an anonymous ScrollFrame remains valid.
		object.ScrollBar = newObject("Slider", name and (name .. "ScrollBar") or nil, object, "UIPanelScrollBarTemplate")
		object.ScrollBar.ScrollUpButton = newObject("Button", nil, object.ScrollBar)
		object.ScrollBar.ScrollDownButton = newObject("Button", nil, object.ScrollBar)
	end
	return object
end

local registeredCategory
local settingsOpenCalls = 0
local lastOpenedCategoryID
Settings = {
	RegisterCanvasLayoutCategory = function(panel, name)
		registeredCategory = {
			ID = 120101,
			panel = panel,
			name = name,
		}
		function registeredCategory:GetID()
			return self.ID
		end
		return registeredCategory
	end,
	RegisterAddOnCategory = function(category)
		category.registered = true
	end,
	OpenToCategory = function(categoryID)
		check(type(categoryID) == "number", "Settings.OpenToCategory requires a numeric category ID")
		settingsOpenCalls = settingsOpenCalls + 1
		lastOpenedCategoryID = categoryID
		registeredCategory.panel:Show()
	end,
}

C_Timer = {
	After = function(_, callback)
		table.insert(timers, callback)
	end,
}

local function flushTimers()
	local guard = 0
	while #timers > 0 do
		guard = guard + 1
		check(guard < 1000, "timer loop did not settle")
		local callback = table.remove(timers, 1)
		callback()
	end
end

local function fireEvent(event, ...)
	for _, frame in ipairs(frames) do
		if frame.events[event] and frame.scripts.OnEvent then
			frame.scripts.OnEvent(frame, event, ...)
		end
	end
end

local friendlyPlayerNamesCVar = "UnitNameFriendlyPlayerName"
local friendlyPlayerNameplatesCVar = "nameplateShowFriendlyPlayers"
local friendlyPlayerNamesOnlyCVar = "nameplateShowOnlyNameForFriendlyPlayerUnits"
local friendlyPlayerClassColorsCVar = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local friendlyHealthClassColorsCVar = "nameplateShowFriendlyClassColor"
local cvarValues = {
	[friendlyPlayerNamesCVar] = "0",
	[friendlyPlayerNameplatesCVar] = "0",
	[friendlyPlayerNamesOnlyCVar] = "0",
	[friendlyPlayerClassColorsCVar] = "0",
	[friendlyHealthClassColorsCVar] = "0",
}
local cvarSetFailures = {}
local cvarSetCalls = {}

C_CVar = {
	GetCVar = function(cvarName)
		return cvarValues[cvarName]
	end,
	SetCVar = function(cvarName, value)
		if cvarSetFailures[cvarName] or cvarValues[cvarName] == nil then
			return false
		end
		cvarValues[cvarName] = tostring(value)
		table.insert(cvarSetCalls, { name = cvarName, value = tostring(value) })
		return true
	end,
}

function GetCVar(cvarName)
	return C_CVar.GetCVar(cvarName)
end

function SetCVar(cvarName, value)
	return C_CVar.SetCVar(cvarName, value)
end

local mockNamePlates = {}
local nameplateUnitInfo = {}
C_NamePlate = {
	GetNamePlateForUnit = function(unit)
		return mockNamePlates[unit]
	end,
	GetNamePlates = function()
		local namePlates = {}
		for _, namePlate in pairs(mockNamePlates) do
			table.insert(namePlates, namePlate)
		end
		return namePlates
	end,
}

local initialFriendlyMouseoverColor = { r = 1, g = 1, b = 0 }
local updatedFriendlyMouseoverColor
NamePlateFriendlyFrameOptions = {
	nameMouseoverColor = initialFriendlyMouseoverColor,
}

NamePlateDriverMixin = {
	UpdateNamePlateOptions = function()
		updatedFriendlyMouseoverColor = { r = 1, g = 1, b = 0 }
		NamePlateFriendlyFrameOptions.nameMouseoverColor = updatedFriendlyMouseoverColor
	end,
}

function CompactUnitFrame_OnEvent(unitFrame, event)
	if event == "UPDATE_MOUSEOVER_UNIT" and unitFrame.name then
		unitFrame.name:SetVertexColor(1, 1, 1, 1)
		unitFrame.colorNameWithClassColor = false
	end
end

function hooksecurefunc(target, methodName, callback)
	local owner = target
	if type(target) == "string" then
		callback = methodName
		owner = _G
		methodName = target
	end
	local original = owner[methodName]
	owner[methodName] = function(...)
		local results = { original(...) }
		callback(...)
		local unpackValues = table.unpack or unpack
		return unpackValues(results)
	end
end

function UnitIsFriend(_, unit)
	return nameplateUnitInfo[unit] and nameplateUnitInfo[unit].friendly or false
end

function UnitIsPlayer(unit)
	return nameplateUnitInfo[unit] and nameplateUnitInfo[unit].player or false
end

local mouseoverUnit
function UnitIsUnit(unit, otherUnit)
	if otherUnit == "mouseover" then
		return unit == mouseoverUnit
	end
	return unit == otherUnit
end

local combatLocked = false
function InCombatLockdown()
	return combatLocked
end

local repairCalls = 0
local repairArguments = {}
local junkSellCalls = 0
local individualJunkSellCalls = 0
local personalMoney = 999999
local secretPersonalMoney = false
local secretMerchantPermission = false
local secretRepairCost = false
local secretRepairPermission = false
local guildCanRepair = false
local secretGuildPermission = false
local guildWithdrawMoney = 0
local guildBankMoney = 0
local secretGuildFunds = false

function CanMerchantRepair()
	if secretMerchantPermission then
		return SECRET
	end
	return true
end

function GetRepairAllCost()
	local cost = 12345
	local canRepair = true
	if secretRepairCost then
		cost = SECRET
	end
	if secretRepairPermission then
		canRepair = SECRET
	end
	return cost, canRepair
end

function GetMoney()
	if secretPersonalMoney then
		return SECRET
	end
	return personalMoney
end

function CanGuildBankRepair()
	if secretGuildPermission then
		return SECRET
	end
	return guildCanRepair
end

function GetGuildBankWithdrawMoney()
	if secretGuildFunds then
		return SECRET
	end
	return guildWithdrawMoney
end

function GetGuildBankMoney()
	if secretGuildFunds then
		return SECRET
	end
	return guildBankMoney
end

function RepairAllItems(useGuild)
	repairCalls = repairCalls + 1
	table.insert(repairArguments, useGuild == true and true or "personal")
end

BACKPACK_CONTAINER = 0
NUM_BAG_SLOTS = 4
INVSLOT_LAST_EQUIPPED = 19

local bagSlots = {
	[0] = 16,
	[1] = 16,
	[2] = 16,
	[3] = 16,
	[4] = 16,
}
local bagFreeSlots = {
	[0] = 2,
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
}
local containerItems = {
	[0] = {
		[16] = { itemID = 1001, stackCount = 2, quality = 0, hyperlink = "|cff9d9d9d|Hitem:1001:::::::::|h[Discarded Saber]|h|r", hasNoValue = false },
		[15] = { itemID = 1002, stackCount = 1, quality = 0, hyperlink = "|cff9d9d9d|Hitem:1002:::::::::|h[Broken Compass]|h|r", hasNoValue = false },
		[14] = { itemID = 2001, stackCount = 1, quality = 1, hyperlink = "|cffffffff|Hitem:2001:::::::::|h[Traveler's Bread]|h|r", hasNoValue = false },
	},
}
local itemInfo = {
	[1001] = { name = "Discarded Saber", quality = 0, sellPrice = 125 },
	[1002] = { name = "Broken Compass", quality = 0, sellPrice = 540 },
	[2001] = { name = "Traveler's Bread", quality = 1, sellPrice = 50 },
}
local secretDurability = false
local secretBagSpace = false
local secretLatency = false

C_Container = {
	GetContainerNumSlots = function(bag)
		return bagSlots[bag] or 0
	end,
	GetContainerNumFreeSlots = function(bag)
		if secretBagSpace then
			return SECRET
		end
		return bagFreeSlots[bag] or 0
	end,
	GetContainerItemInfo = function(bag, slot)
		return containerItems[bag] and containerItems[bag][slot] or nil
	end,
	UseContainerItem = function(bag, slot)
		local item = containerItems[bag] and containerItems[bag][slot]
		if item then
			individualJunkSellCalls = individualJunkSellCalls + 1
			personalMoney = personalMoney + ((itemInfo[item.itemID] and itemInfo[item.itemID].sellPrice or 0) * item.stackCount)
		end
	end,
}

C_Item = {
	GetItemInfo = function(itemID)
		local item = itemInfo[itemID]
		if not item then
			return nil
		end
		return item.name, "|Hitem:" .. itemID .. "|h[" .. item.name .. "]|h", item.quality, 1, 1, "Miscellaneous", "Junk", 20, "", 0, item.sellPrice, 0, 0, 0, 0, false, false
	end,
}

C_MerchantFrame = {
	GetNumJunkItems = function()
		return 3
	end,
	SellAllJunkItems = function()
		junkSellCalls = junkSellCalls + 1
		personalMoney = personalMoney + 790
	end,
}

local inventoryDurability = {
	[1] = { current = 35, maximum = 100 },
}
local worldLatency = 42

function GetInventoryItemDurability(slot)
	if secretDurability then
		return SECRET, SECRET
	end
	local durability = inventoryDurability[slot]
	if durability then
		return durability.current, durability.maximum
	end
	return nil, nil
end

function GetNetStats()
	if secretLatency then
		return 0, 0, 30, SECRET
	end
	return 0, 0, 30, worldLatency
end

local secretIdentity = false
local secretCrit = false
local secretHaste = false
local secretPrimaryStat = false
local secretArmor = false
local secretOtherStats = false
local statReads = 0
local unitStatReads = {}
local spellSchoolsRead = {}

function UnitName()
	return secretIdentity and SECRET or "Tester"
end

RAID_CLASS_COLORS = {
	DRUID = { r = 1, g = 0.49, b = 0.04 },
}

function UnitClass(unit)
	local unitInfo = nameplateUnitInfo[unit]
	if unitInfo and unitInfo.classToken then
		return unitInfo.classToken, unitInfo.classToken, 11
	end
	local localizedClass = testLocale == "zhCN" and "德鲁伊" or "Druid"
	return secretIdentity and SECRET or localizedClass, "DRUID", 11
end

function UnitLevel()
	return 80
end

function GetAverageItemLevel()
	return 650.5, 648.25
end

function UnitStat(_, index)
	statReads = statReads + 1
	unitStatReads[index] = (unitStatReads[index] or 0) + 1
	if secretPrimaryStat and index == 1 then
		return 1000 + index, SECRET
	end
	return 1000 + index, 1100 + index
end

function UnitArmor()
	statReads = statReads + 1
	if secretArmor then
		return 2500, SECRET
	end
	return 2500, 2600
end

function GetCritChance()
	statReads = statReads + 1
	return 5
end

function GetRangedCritChance()
	return secretCrit and SECRET or 10
end

function GetSpellCritChance(school)
	table.insert(spellSchoolsRead, school)
	return 17 - school / 4
end

MAX_SPELL_SCHOOLS = 7

function GetHaste()
	if secretHaste then
		return SECRET
	end
	return 12.5
end

function GetMasteryEffect()
	if secretOtherStats then
		return SECRET
	end
	return 18.25
end

CR_VERSATILITY_DAMAGE_DONE = 29

function GetCombatRatingBonus()
	if secretOtherStats then
		return SECRET
	end
	return 4.5
end

function GetVersatilityBonus()
	if secretOtherStats then
		return SECRET
	end
	return 1.5
end

function GetLifesteal()
	if secretOtherStats then
		return SECRET
	end
	return 2.25
end

function GetAvoidance()
	if secretOtherStats then
		return SECRET
	end
	return 3.5
end

function GetSpeed()
	if secretOtherStats then
		return SECRET
	end
	return 4.75
end

function GetDodgeChance()
	if secretOtherStats then
		return SECRET
	end
	return 6.5
end

function GetParryChance()
	if secretOtherStats then
		return SECRET
	end
	return 7.25
end

function BreakUpLargeNumbers(value)
	return tostring(value)
end

function GetBuildInfo()
	return "12.1.0", "69299", "Aug 11 2026", 120100
end

function GetLocale()
	return activeClientLocale
end

ColorPickerFrame = {
	r = 1,
	g = 1,
	b = 1,
}

function ColorPickerFrame:SetupColorPickerAndShow(info)
	self.info = info
	self.r = info.r
	self.g = info.g
	self.b = info.b
	self.shown = true
end

function ColorPickerFrame:GetColorRGB()
	return self.r, self.g, self.b
end

HappyTreeFriendsDB = { debugLog = {} }
for index = 1, 82 do
	if index == 10 then
		HappyTreeFriendsDB.debugLog[index] = false
	else
		HappyTreeFriendsDB.debugLog[index] = "seed-" .. index
	end
end

activeClientLocale = "frFR"
local fallbackLocaleHTF = {}
local fallbackLocaleChunk, fallbackLocaleError = loadfile("HappyTreeFriends/Locales.lua")
check(fallbackLocaleChunk ~= nil, fallbackLocaleError)
fallbackLocaleChunk("HappyTreeFriends", fallbackLocaleHTF)
equal(fallbackLocaleHTF.CLIENT_LOCALE, "frFR", "unsupported client locale is recorded")
equal(fallbackLocaleHTF.LOCALE, "enUS", "unsupported client locale falls back to English")
equal(fallbackLocaleHTF.L.SETTINGS, "Settings", "unsupported client locale receives English text")
activeClientLocale = testLocale

local HTF = {}
for _, path in ipairs({
	"HappyTreeFriends/Locales.lua",
	"HappyTreeFriends/Core.lua",
	"HappyTreeFriends/FriendlyNames.lua",
	"HappyTreeFriends/Merchant.lua",
	"HappyTreeFriends/Stats.lua",
	"HappyTreeFriends/Options.lua",
}) do
	local chunk, loadError = loadfile(path)
	check(chunk ~= nil, loadError)
	chunk("HappyTreeFriends", HTF)
end

fireEvent("ADDON_LOADED", "HappyTreeFriends")
equal(HTF.VERSION, "0.6.0", "addon version")
equal(HTF.LOCALE, testLocale, "addon selects the active supported locale")
equal(HTF.CLIENT_LOCALE, testLocale, "addon records the client locale")
equal(HTF.L.SETTINGS, testLocale == "zhCN" and "设置" or "Settings", "selected locale exposes translated settings text")
for key, value in pairs(HTF.LOCALES.enUS) do
	check(type(value) == "string" and value ~= "", "English locale value is non-empty: " .. key)
	check(type(HTF.LOCALES.zhCN[key]) == "string" and HTF.LOCALES.zhCN[key] ~= "", "zhCN locale includes English key: " .. key)
end
for key in pairs(HTF.LOCALES.zhCN) do
	check(HTF.LOCALES.enUS[key] ~= nil, "English locale includes zhCN key: " .. key)
end
for _, definition in ipairs(HTF.Stats.STAT_DEFINITIONS) do
	check(HTF.LOCALES.enUS[definition.fallbackKey] ~= nil, "English stat fallback exists: " .. definition.key)
	check(HTF.LOCALES.zhCN[definition.fallbackKey] ~= nil, "zhCN stat fallback exists: " .. definition.key)
end
local formatCases = {
	VERSION_LABEL = { "0.6.0" },
	REPAIRED_PERSONAL = { "1g" },
	REPAIRED_GUILD = { "1g" },
	REPAIRED_MIXED = { "1g" },
	SOLD_JUNK = { 3 },
	LEDGER_REPAIR_TOTAL = { "1g", "1g", "1g" },
	LEDGER_JUNK_TOTAL = { 3, "1g" },
	LEDGER_SKIPPED_ITEM = { "item", 1 },
	LEDGER_SKIPPED_MORE = { 2 },
	JUNK_PROTECTION_ADDED = { 1001 },
	JUNK_PROTECTION_REMOVED = { 1001 },
	JUNK_PROTECTION_LIST = { "#1001" },
	DEBUG_REPAIR_COMPLETED = { "1g", "personal" },
	DEBUG_JUNK_SOLD = { 3 },
	DEBUG_STATS_POSITION_SAVED = { "TOP", "TOP", 1, -1 },
	DEBUG_STAT_VISIBILITY_UPDATED = { "haste", "true" },
	DEBUG_FRIENDLY_NAMES_CVAR_FAILED = { friendlyPlayerNamesCVar },
	DEBUG_FRIENDLY_NAMES_MOUSEOVER_TRACE = { "UPDATE_MOUSEOVER_UNIT", "nameplate1", "1,1,1", "true", "1,0,0", "true" },
	DEBUG_FRIENDLY_NAMES_MOUSEOVER_AFTER = { "nameplate1", "1,0,0", "1,0,0" },
}
local unpackValues = table.unpack or unpack
for key, arguments in pairs(formatCases) do
	local ok = pcall(string.format, HTF.L[key], unpackValues(arguments))
	check(ok, "selected locale format placeholders are valid: " .. key)
end
equal(#HTF.debugLog, 80, "saved log is normalized to its cap")
equal(HTF.debugLog[1], "seed-2", "normalization keeps the newest valid entries")
check(HTF.debugLog == HappyTreeFriendsDB.debugLog, "runtime log must share the SavedVariables table")
equal(HTF:GetSetting("autoRepair"), false, "auto repair defaults off")
equal(HTF:GetSetting("repairFromGuild"), false, "guild repair defaults off")
equal(HTF:GetSetting("autoSellJunk"), false, "auto sell defaults off")
check(type(HTF:GetSetting("protectedJunkItems")) == "table", "protected junk item IDs default to an empty table")
equal(HTF:GetSetting("friendlyNamesOnly"), false, "friendly names-only mode defaults off")
equal(HTF:GetSetting("friendlyNameClassColors"), false, "friendly name class colors default off")
equal(HTF:GetSetting("friendlyNameCustomFontSize"), false, "friendly custom name size defaults off")
equal(HTF:GetSetting("friendlyNameFontSize"), 14, "friendly name font size has a safe default")
check(HTF.FriendlyNames.nameplateOptionsHookInstalled, "friendly nameplate option hook is installed when the nameplate UI is available")
check(HTF.FriendlyNames.nameplateMouseoverHookInstalled, "friendly nameplate mouseover hook is installed when the nameplate UI is available")
equal(HTF.db.friendlyNamesOnlySnapshot, nil, "friendly names-only mode has no default snapshot")
equal(HTF:GetSetting("statsLocked"), true, "stats overlay defaults locked")
equal(HTF:GetSetting("statsFontSize"), 15, "stats overlay default font size")
equal(HTF:GetSetting("statsScale"), 1, "stats overlay default scale")
equal(HTF.Stats:GetVisibleStatCount(), 14, "all stats default visible")
equal(HTF.Stats:GetVisibleAdventureStatusCount(), 0, "adventure status defaults hidden")

check(HTF.Stats.overlay ~= nil, "stats overlay is created during addon initialization")
equal(HTF.Stats.overlay:GetName(), "HappyTreeFriendsStatsOverlay", "stats overlay has a stable frame name")
check(HTF.Stats.overlay:IsShown(), "stats overlay defaults visible")
equal(HTF.Stats.overlay.mouseEnabled, false, "locked overlay does not intercept mouse input")
equal(HTF.Stats.overlay.backdropColor[4], 0, "locked overlay background is transparent")
equal(HTF.Stats.overlay.backdropBorderColor[4], 0, "locked overlay border is transparent")
check(not HTF.Stats.overlay.title:IsShown(), "locked overlay hides its drag hint")
check(HTF.Stats.overlay.movable, "stats overlay is movable")
check(HTF.Stats.overlay.resizable, "stats overlay supports native resizing")
check(HTF.Stats.overlay.clampedToScreen, "stats overlay stays clamped to screen")
equal(HTF.Stats.overlay.dragButtons[1], "LeftButton", "stats overlay uses left-button drag")
equal(HTF.Stats.overlay:GetScale(), 1, "stats overlay applies its default scale")
check(HTF.Stats.overlay.resizeHandle ~= nil, "stats overlay has a resize handle")
equal(HTF.Stats.overlay.resizeHandle.dragButtons[1], "LeftButton", "resize handle uses left-button drag")
check(not HTF.Stats.overlay.resizeHandle:IsShown(), "locked overlay hides its resize handle")
equal(HTF.Stats.overlay.rows.strength.fontSize, 15, "overlay applies the configured font size")
equal(HTF.Stats.overlay.rows.strength.fontFlags, "THICKOUTLINE", "overlay stat text uses a thick outline")
equal(HTF.Stats.overlay.rows.strength.shadowColor[4], 1, "overlay stat text uses an opaque black shadow")
equal(HTF.Stats.overlay.rows.strength.shadowOffset[1], 2, "overlay stat shadow has a visible horizontal offset")
equal(HTF.Stats.overlay.rows.strength.shadowOffset[2], -2, "overlay stat shadow has a visible vertical offset")
equal(HTF.Stats.overlay.status.fontFlags, "THICKOUTLINE", "overlay status text uses the same strong outline")
check(HTF.Stats.overlay.rows.strength.textColor[1] ~= HTF.Stats.overlay.rows.agility.textColor[1], "default stat rows use distinct colors")
check(HTF.Stats.overlay.rows.durability ~= nil, "overlay creates a durability row")
check(not HTF.Stats.overlay.rows.durability:IsShown(), "adventure status rows default hidden")

for _, frame in ipairs(frames) do
	check(frame.scripts.OnUpdate == nil, "addon frames do not use OnUpdate polling")
end

fireEvent("PLAYER_ENTERING_WORLD")
flushTimers()
equal(HTF.Stats.overlay.rows.criticalStrike:GetText(), HTF.Stats:GetStatLabel("criticalStrike") .. ": 15.25%", "HUD crit matches PaperDoll max melee/ranged/spell behavior")
local sawFirstSpellSchool = false
local sawLastSpellSchool = false
for _, school in ipairs(spellSchoolsRead) do
	check(school ~= 1, "PaperDoll crit calculation skips the physical school")
	sawFirstSpellSchool = sawFirstSpellSchool or school == 2
	sawLastSpellSchool = sawLastSpellSchool or school == MAX_SPELL_SCHOOLS
end
check(sawFirstSpellSchool and sawLastSpellSchool, "PaperDoll crit calculation reads spell schools 2 through MAX_SPELL_SCHOOLS")

fireEvent("PLAYER_LOGIN")
check(HTF.Options.panel ~= nil, "options panel is created at login")
equal(HTF.Options.panel:GetName(), "HappyTreeFriendsSettingsFrame", "options uses a dedicated top-level frame")
check(HTF.Options.closeButton ~= nil, "dedicated settings frame includes a close button")
equal(HTF.Options.closeButton.template, "UIPanelCloseButton", "dedicated settings frame uses the standard close control")
check(HTF.Options.panel.movable, "dedicated settings frame can be moved")
equal(HTF.Options.selectedPageKey, "overview", "overview is the initial page")
equal(HTF.Options:IsPageVisible("overview"), false, "a hidden settings panel is not visible")
check(registeredCategory and registeredCategory.registered, "options panel is registered as an addon category")
equal(HTF.Options:GetCategoryID(), 120101, "registered category exposes its numeric ID")
check(UISpecialFrames[1] == "HappyTreeFriendsSettingsFrame", "Escape closes the dedicated settings frame")
check(HTF.Options.pages.nameplates ~= nil, "friendly names page is created")
check(HTF.Options.navigation.nameplates ~= nil, "friendly names page has a navigation button")
check(HTF.Options.debugScrollFrame.ScrollBar ~= nil, "12.1 scroll template exposes its scrollbar through parentKey")
equal(HTF.Options.debugScrollFrame:GetName(), nil, "anonymous 12.1 scroll template remains supported")
local localizedToggle = HTF.Options.toggles[1].toggle
equal(localizedToggle.state:GetText(), HTF.L.TOGGLE_OFF, "disabled toggle uses the selected locale")
equal(localizedToggle.state.points[1][1], "RIGHT", "disabled toggle text stays opposite the knob")
localizedToggle:Render(true)
equal(localizedToggle.state:GetText(), HTF.L.TOGGLE_ON, "enabled toggle uses the selected locale")
equal(localizedToggle.state.points[1][1], "LEFT", "enabled toggle text stays opposite the knob")
localizedToggle:Render(false)
check(HTF.Options.debugReportButton.width >= 116, "diagnostic button accommodates its English label")

local customerCopy = {}
for _, frame in ipairs(frames) do
	if frame.kind == "FontString" then
		table.insert(customerCopy, frame:GetText())
	end
end
local allCustomerCopy = table.concat(customerCopy, "\n")
contains(allCustomerCopy, HTF.L.OVERVIEW_INTRO, "overview uses the selected locale")
contains(allCustomerCopy, HTF.L.MERCHANT_PAGE_HELP, "merchant page uses the selected locale")
contains(allCustomerCopy, HTF.L.STATS_PAGE_HELP, "stats page uses the selected locale")
contains(allCustomerCopy, HTF.L.NAMEPLATES_PAGE_HELP, "friendly names page uses the selected locale")
contains(allCustomerCopy, HTF.L.FRIENDLY_NAMES_ONLY_NOTICE, "friendly names page explains snapshot restoration")
contains(allCustomerCopy, HTF.L.DEBUG_PAGE_HELP, "debug page uses the selected locale")
for _, developerPhrase in ipairs({ "OnUpdate", "轮询", "扫描背包", "MVP", "12.1 原生规则", "continuous polling", "bag scanning" }) do
	check(not allCustomerCopy:find(developerPhrase, 1, true), "customer-facing UI omits developer phrase: " .. developerPhrase)
end

local resizedFontCount = 0
for _, frame in ipairs(frames) do
	if frame.kind == "FontString" and frame.fontSize then
		resizedFontCount = resizedFontCount + 1
		check(frame.fontFlags == "OUTLINE" or frame.fontFlags == "THICKOUTLINE", "resized text keeps an explicit outline")
	end
end
check(resizedFontCount > 0, "font preservation check inspected created text")

local overviewRow = HTF.Options.overviewStatus[1].row
equal(#overviewRow.points, 2, "overview status rows have left and right anchors")
local statusTitle = overviewRow.points[1][2]
check(statusTitle == overviewRow.points[2][2], "overview row anchors share a width reference")
equal(#statusTitle.points, 2, "overview width reference spans the content card")

HTF:HandleSlashCommand("nameplates")
check(HTF.Options:IsPageVisible("nameplates"), "/htf nameplates opens the friendly names page")
local friendlyNamesToggleRow
local friendlyNameClassColorsToggleRow
local friendlyNameFontToggleRow
for _, row in ipairs(HTF.Options.toggles) do
	if row.settingKey == "friendlyNamesOnly" then
		friendlyNamesToggleRow = row
	elseif row.settingKey == "friendlyNameClassColors" then
		friendlyNameClassColorsToggleRow = row
	elseif row.settingKey == "friendlyNameCustomFontSize" then
		friendlyNameFontToggleRow = row
	end
end
check(friendlyNamesToggleRow ~= nil, "friendly names page exposes its mode toggle")
check(friendlyNameClassColorsToggleRow ~= nil, "friendly names page exposes its class-color toggle")
check(friendlyNameFontToggleRow ~= nil, "friendly names page exposes its custom-size toggle")
equal(HTF.Options.friendlyNameFontValue:GetText(), "14", "friendly names page displays the default name font size")

cvarValues[friendlyPlayerNamesCVar] = "0"
cvarValues[friendlyPlayerNameplatesCVar] = "1"
cvarValues[friendlyPlayerNamesOnlyCVar] = "0"
cvarValues[friendlyPlayerClassColorsCVar] = "0"
SystemFont_NamePlate:SetFont("MockNameplateFont", 12, "")
SystemFont_NamePlate_Outlined:SetFont("MockNameplateOutlineFont", 13, "OUTLINE")
HTF:SetSetting("friendlyNamesOnly", true)
equal(HTF:GetSetting("friendlyNamesOnly"), true, "friendly names-only mode enables")
equal(cvarValues[friendlyPlayerNamesCVar], "1", "friendly player names are enabled")
equal(cvarValues[friendlyPlayerNameplatesCVar], "1", "friendly player nameplates remain enabled with native names-only support")
equal(cvarValues[friendlyPlayerNamesOnlyCVar], "1", "native friendly names-only mode is enabled")
equal(cvarValues[friendlyPlayerClassColorsCVar], "0", "class colors remain opt-in")
local friendlyNamesSnapshot = HTF.db.friendlyNamesOnlySnapshot
check(type(friendlyNamesSnapshot) == "table", "friendly settings are snapshotted before applying the mode")
equal(friendlyNamesSnapshot[friendlyPlayerNamesCVar], "0", "snapshot retains the original friendly name setting")
equal(friendlyNamesSnapshot[friendlyPlayerNameplatesCVar], "1", "snapshot retains the original friendly nameplate setting")
equal(friendlyNamesSnapshot[friendlyPlayerNamesOnlyCVar], "0", "snapshot retains the original native names-only setting")
equal(friendlyNamesSnapshot[friendlyPlayerClassColorsCVar], "0", "snapshot retains the original class-color setting")
equal(friendlyNamesToggleRow.toggle.state:GetText(), HTF.L.TOGGLE_ON, "friendly names toggle refreshes after enabling")

local cvarCallsBeforeUnrelatedUpdate = #cvarSetCalls
fireEvent("CVAR_UPDATE", "unrelatedCVar", "1")
flushTimers()
equal(#cvarSetCalls, cvarCallsBeforeUnrelatedUpdate, "unrelated CVar updates do not reapply the mode")

cvarValues[friendlyPlayerNameplatesCVar] = "0"
fireEvent("CVAR_UPDATE", string.upper(friendlyPlayerNameplatesCVar), "0")
flushTimers()
equal(cvarValues[friendlyPlayerNameplatesCVar], "1", "managed CVar changes are corrected while the mode is enabled")
check(HTF.db.friendlyNamesOnlySnapshot == friendlyNamesSnapshot, "reapplying the mode never overwrites the original snapshot")

HTF:SetSetting("friendlyNameClassColors", true)
equal(cvarValues[friendlyPlayerClassColorsCVar], "1", "class-color setting uses the native friendly-name CVar")
equal(cvarValues[friendlyHealthClassColorsCVar], "0", "friendly-name class colors do not alter friendly health-bar class colors")
equal(friendlyNameClassColorsToggleRow.toggle.dot.points[1][1], "RIGHT", "class-color toggle refreshes after enabling")

friendlyNamesSnapshot[friendlyPlayerClassColorsCVar] = nil
friendlyNamesSnapshot[friendlyHealthClassColorsCVar] = "0"
cvarValues[friendlyHealthClassColorsCVar] = "1"
HTF.FriendlyNames:Synchronize()
equal(cvarValues[friendlyHealthClassColorsCVar], "0", "0.6.0 migration restores the original friendly health-bar class-color value")
equal(friendlyNamesSnapshot[friendlyHealthClassColorsCVar], nil, "0.6.0 migration removes the erroneous health-bar snapshot")
equal(cvarValues[friendlyPlayerClassColorsCVar], "1", "0.6.0 migration reapplies the correct friendly-name class-color CVar")
equal(friendlyNamesSnapshot[friendlyPlayerClassColorsCVar], "1", "0.6.0 migration preserves the safest available name-color restoration value")
friendlyNamesSnapshot[friendlyPlayerClassColorsCVar] = "0"

HTF.FriendlyNames:SetFontSize(19)
equal(HTF:GetSetting("friendlyNameFontSize"), 19, "friendly name font size persists in settings")
equal(HTF.Options.friendlyNameFontValue:GetText(), "19", "friendly name font size control refreshes immediately")
local _, originalNameplateFontSize = SystemFont_NamePlate:GetFont()
local _, originalOutlinedNameplateFontSize = SystemFont_NamePlate_Outlined:GetFont()
equal(originalNameplateFontSize, 12, "custom name size stays inactive until enabled")
equal(originalOutlinedNameplateFontSize, 13, "outlined name font stays unchanged until enabled")

HTF:SetSetting("friendlyNameCustomFontSize", true)
flushTimers()
local _, selectedNameplateFontSize = SystemFont_NamePlate:GetFont()
local _, selectedOutlinedNameplateFontSize = SystemFont_NamePlate_Outlined:GetFont()
equal(selectedNameplateFontSize, 19, "custom name size applies to the standard nameplate font")
equal(selectedOutlinedNameplateFontSize, 19, "custom name size applies to the outlined nameplate font")
equal(friendlyNameFontToggleRow.toggle.dot.points[1][1], "RIGHT", "custom name-size toggle refreshes after enabling")

local accessibleFriendlyNameplate = CreateFrame("Frame", nil, UIParent)
accessibleFriendlyNameplate.UnitFrame = CreateFrame("Frame", nil, accessibleFriendlyNameplate)
accessibleFriendlyNameplate.UnitFrame.name = CreateFrame("FontString", nil, accessibleFriendlyNameplate.UnitFrame)
accessibleFriendlyNameplate.UnitFrame.name:SetFont("PerPlateFont", 12, "OUTLINE")
accessibleFriendlyNameplate.UnitFrame.UpdateNameClassColor = function(unitFrame)
	if cvarValues[friendlyPlayerClassColorsCVar] == "1" then
		unitFrame.name:SetVertexColor(1, 0.49, 0.04, 1)
	else
		unitFrame.name:SetVertexColor(1, 1, 1, 1)
	end
end
mockNamePlates.nameplate1 = accessibleFriendlyNameplate
accessibleFriendlyNameplate.UnitFrame.unit = "nameplate1"
nameplateUnitInfo.nameplate1 = { friendly = true, player = true, classToken = "DRUID" }
fireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
local _, accessibleFriendlyNameSize = accessibleFriendlyNameplate.UnitFrame.name:GetFont()
equal(accessibleFriendlyNameSize, 19, "new accessible friendly nameplates receive the selected font size")
equal(accessibleFriendlyNameplate.UnitFrame.name.vertexColor[1], 1, "new accessible friendly nameplates receive their class color")
equal(accessibleFriendlyNameplate.UnitFrame.name.vertexColor[2], 0.49, "class color uses the unit class green component")
equal(accessibleFriendlyNameplate.UnitFrame.name.vertexColor[3], 0.04, "class color uses the unit class blue component")

HTF:SetSetting("friendlyNameClassColors", false)
flushTimers()
equal(accessibleFriendlyNameplate.UnitFrame.name.vertexColor[2], 1, "turning class colors off refreshes visible friendly nameplates")
equal(NamePlateFriendlyFrameOptions.nameMouseoverColor, initialFriendlyMouseoverColor, "turning class colors off restores the friendly-name mouseover color")
mouseoverUnit = "nameplate1"
CompactUnitFrame_OnEvent(accessibleFriendlyNameplate.UnitFrame, "UPDATE_MOUSEOVER_UNIT")
equal(accessibleFriendlyNameplate.UnitFrame.name.vertexColor[2], 1, "mouseover hook leaves class colors disabled")
HTF:SetSetting("friendlyNameClassColors", true)
flushTimers()
equal(accessibleFriendlyNameplate.UnitFrame.name.vertexColor[2], 0.49, "turning class colors on refreshes visible friendly nameplates")
equal(NamePlateFriendlyFrameOptions.nameMouseoverColor, nil, "class colors suppress the friendly-name mouseover color override")
CompactUnitFrame_OnEvent(accessibleFriendlyNameplate.UnitFrame, "UPDATE_MOUSEOVER_UNIT")
equal(accessibleFriendlyNameplate.UnitFrame.name.vertexColor[2], 0.49, "mouseover redraw restores the friendly player's class color")
check(accessibleFriendlyNameplate.UnitFrame.colorNameWithClassColor, "mouseover refresh preserves the native class-color state")

HTF.db.debug = true
CompactUnitFrame_OnEvent(accessibleFriendlyNameplate.UnitFrame, "UPDATE_MOUSEOVER_UNIT")
flushTimers()
contains(HTF.debugLog[#HTF.debugLog - 1], "UPDATE_MOUSEOVER_UNIT", "debug mode records the mouseover redraw action")
contains(HTF.debugLog[#HTF.debugLog], "nameplate1", "debug mode records the post-event friendly-name color check")
HTF.db.debug = false

local enemyMouseoverNameplate = CreateFrame("Frame", nil, UIParent)
enemyMouseoverNameplate.name = CreateFrame("FontString", nil, enemyMouseoverNameplate)
enemyMouseoverNameplate.unit = "nameplateEnemy"
nameplateUnitInfo.nameplateEnemy = { friendly = false, player = true, classToken = "DRUID" }
mouseoverUnit = "nameplateEnemy"
CompactUnitFrame_OnEvent(enemyMouseoverNameplate, "UPDATE_MOUSEOVER_UNIT")
check(not enemyMouseoverNameplate.colorNameWithClassColor, "friendly class-color hover handling does not modify enemy nameplates")
equal(enemyMouseoverNameplate.name.vertexColor[2], 1, "enemy mouseover color remains controlled by the game")
mouseoverUnit = nil
NamePlateDriverMixin.UpdateNamePlateOptions()
equal(NamePlateFriendlyFrameOptions.nameMouseoverColor, nil, "nameplate option updates retain the class-color mouseover policy")

local fallbackFriendlyNameplate = CreateFrame("Frame", nil, UIParent)
fallbackFriendlyNameplate.UnitFrame = CreateFrame("Frame", nil, fallbackFriendlyNameplate)
fallbackFriendlyNameplate.UnitFrame.name = CreateFrame("FontString", nil, fallbackFriendlyNameplate.UnitFrame)
mockNamePlates.nameplate3 = fallbackFriendlyNameplate
fallbackFriendlyNameplate.UnitFrame.unit = "nameplate3"
nameplateUnitInfo.nameplate3 = { friendly = true, player = true, classToken = "DRUID" }
fireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
equal(fallbackFriendlyNameplate.UnitFrame.name.vertexColor[2], 0.49, "class-color fallback updates accessible nameplates without a native refresh method")

local secretClassNameplate = CreateFrame("Frame", nil, UIParent)
secretClassNameplate.UnitFrame = CreateFrame("Frame", nil, secretClassNameplate)
secretClassNameplate.UnitFrame.name = CreateFrame("FontString", nil, secretClassNameplate.UnitFrame)
mockNamePlates.nameplate4 = secretClassNameplate
nameplateUnitInfo.nameplate4 = { friendly = true, player = true, classToken = SECRET }
local secretClassOk = pcall(HTF.FriendlyNames.RefreshClassColorForNameplate, HTF.FriendlyNames, "nameplate4")
check(secretClassOk, "restricted class values do not break friendly-name color refreshes")

nameplateUnitInfo.nameplate2 = { friendly = true, player = true }
fireEvent("NAME_PLATE_UNIT_ADDED", "nameplate2")
local _, transientNameplateFontSize = SystemFont_NamePlate:GetFont()
equal(transientNameplateFontSize, 18, "inaccessible friendly nameplates trigger one coalesced font refresh")
flushTimers()
local _, refreshedNameplateFontSize = SystemFont_NamePlate:GetFont()
equal(refreshedNameplateFontSize, 19, "coalesced font refresh restores the chosen size")

HTF.FriendlyNames:SetFontSize(100)
flushTimers()
equal(HTF:GetSetting("friendlyNameFontSize"), HTF.FriendlyNames.MAX_FONT_SIZE, "friendly name font size is clamped to a safe maximum")
local _, maximumNameplateFontSize = SystemFont_NamePlate:GetFont()
equal(maximumNameplateFontSize, HTF.FriendlyNames.MAX_FONT_SIZE, "maximum font size applies immediately")
HTF.FriendlyNames:SetFontSize(1)
flushTimers()
equal(HTF:GetSetting("friendlyNameFontSize"), HTF.FriendlyNames.MIN_FONT_SIZE, "friendly name font size is clamped to a safe minimum")

HTF:SetSetting("friendlyNameCustomFontSize", false)
local _, restoredNameplateFontSize = SystemFont_NamePlate:GetFont()
local _, restoredOutlinedNameplateFontSize = SystemFont_NamePlate_Outlined:GetFont()
equal(restoredNameplateFontSize, 12, "turning custom name size off restores the standard font")
equal(restoredOutlinedNameplateFontSize, 13, "turning custom name size off restores the outlined font")
check(HTF.FriendlyNames.fontSnapshot == nil, "turning custom name size off clears the font snapshot")

HTF:SetSetting("friendlyNameCustomFontSize", true)
flushTimers()
HTF:SetSetting("friendlyNamesOnly", false)
equal(cvarValues[friendlyPlayerNamesCVar], "0", "disabling restores the original friendly name setting")
equal(cvarValues[friendlyPlayerNameplatesCVar], "1", "disabling restores the original friendly nameplate setting")
equal(cvarValues[friendlyPlayerNamesOnlyCVar], "0", "disabling restores the original native names-only setting")
equal(cvarValues[friendlyPlayerClassColorsCVar], "0", "disabling restores the original class-color setting")
equal(NamePlateFriendlyFrameOptions.nameMouseoverColor, updatedFriendlyMouseoverColor, "disabling restores the latest game mouseover color setting")
local _, disabledNameplateFontSize = SystemFont_NamePlate:GetFont()
local _, disabledOutlinedNameplateFontSize = SystemFont_NamePlate_Outlined:GetFont()
equal(disabledNameplateFontSize, 12, "disabling friendly names restores the standard nameplate font")
equal(disabledOutlinedNameplateFontSize, 13, "disabling friendly names restores the outlined nameplate font")
equal(HTF.db.friendlyNamesOnlySnapshot, nil, "successful restoration clears the saved snapshot")
equal(friendlyNamesToggleRow.toggle.state:GetText(), HTF.L.TOGGLE_OFF, "friendly names toggle refreshes after disabling")
HTF:SetSetting("friendlyNameClassColors", false)
HTF:SetSetting("friendlyNameCustomFontSize", false)
HTF.FriendlyNames:SetFontSize(14)

cvarValues[friendlyPlayerNamesCVar] = "0"
cvarValues[friendlyPlayerNameplatesCVar] = "1"
cvarValues[friendlyPlayerNamesOnlyCVar] = nil
HTF:SetSetting("friendlyNamesOnly", true)
equal(cvarValues[friendlyPlayerNamesCVar], "1", "fallback mode keeps friendly player names enabled")
equal(cvarValues[friendlyPlayerNameplatesCVar], "0", "fallback mode hides friendly nameplates when native names-only support is absent")
equal(HTF.db.friendlyNamesOnlySnapshot[friendlyPlayerNamesOnlyCVar], nil, "unsupported native names-only CVar is not snapshotted")
HTF:SetSetting("friendlyNamesOnly", false)
equal(cvarValues[friendlyPlayerNamesCVar], "0", "fallback restoration restores friendly player names")
equal(cvarValues[friendlyPlayerNameplatesCVar], "1", "fallback restoration restores friendly player nameplates")
equal(HTF.db.friendlyNamesOnlySnapshot, nil, "fallback restoration clears its snapshot")
cvarValues[friendlyPlayerNamesOnlyCVar] = "0"

cvarValues[friendlyPlayerNamesCVar] = "0"
cvarValues[friendlyPlayerNameplatesCVar] = "0"
cvarValues[friendlyPlayerNamesOnlyCVar] = "0"
cvarSetFailures[friendlyPlayerNamesOnlyCVar] = true
HTF:SetSetting("friendlyNamesOnly", true)
equal(HTF:GetSetting("friendlyNamesOnly"), true, "mode stays enabled while a captured activation retries")
equal(cvarValues[friendlyPlayerNamesCVar], "1", "activation applies friendly names before retrying")
equal(cvarValues[friendlyPlayerNameplatesCVar], "0", "failed native names-only activation never exposes friendly health bars")
check(type(HTF.db.friendlyNamesOnlySnapshot) == "table", "failed activation retains its original snapshot")
cvarSetFailures[friendlyPlayerNamesOnlyCVar] = nil
fireEvent("PLAYER_ENTERING_WORLD")
flushTimers()
equal(cvarValues[friendlyPlayerNamesOnlyCVar], "1", "failed native names-only activation retries after entering the world")
equal(cvarValues[friendlyPlayerNameplatesCVar], "1", "friendly nameplates enable after native names-only activation succeeds")
HTF:SetSetting("friendlyNamesOnly", false)
equal(cvarValues[friendlyPlayerNamesCVar], "0", "activation retry test restores friendly player names")
equal(cvarValues[friendlyPlayerNameplatesCVar], "0", "activation retry test restores friendly player nameplates")
equal(cvarValues[friendlyPlayerNamesOnlyCVar], "0", "activation retry test restores native names-only mode")

cvarValues[friendlyPlayerNamesCVar] = "0"
cvarValues[friendlyPlayerNameplatesCVar] = "0"
cvarValues[friendlyPlayerNamesOnlyCVar] = "0"
HTF:SetSetting("friendlyNamesOnly", true)
cvarSetFailures[friendlyPlayerNameplatesCVar] = true
HTF:SetSetting("friendlyNamesOnly", false)
equal(HTF:GetSetting("friendlyNamesOnly"), false, "mode remains disabled while restoration is pending")
check(type(HTF.db.friendlyNamesOnlySnapshot) == "table", "failed restoration retains the original snapshot")
equal(cvarValues[friendlyPlayerNameplatesCVar], "1", "failed CVar restoration leaves the unresolved value pending")
cvarSetFailures[friendlyPlayerNameplatesCVar] = nil
fireEvent("PLAYER_ENTERING_WORLD")
flushTimers()
equal(cvarValues[friendlyPlayerNameplatesCVar], "0", "pending restoration retries after entering the world")
equal(HTF.db.friendlyNamesOnlySnapshot, nil, "successful retry clears the retained snapshot")

cvarValues[friendlyPlayerNamesCVar] = nil
cvarValues[friendlyPlayerNameplatesCVar] = "0"
HTF:SetSetting("friendlyNamesOnly", true)
equal(HTF:GetSetting("friendlyNamesOnly"), false, "mode stays off when required game settings are unavailable")
equal(HTF.db.friendlyNamesOnlySnapshot, nil, "failed activation does not create an incomplete snapshot")
cvarValues[friendlyPlayerNamesCVar] = "0"

HTF.db.friendlyNamesOnlySnapshot = "invalid"
HTF.FriendlyNames:Synchronize()
equal(HTF.db.friendlyNamesOnlySnapshot, nil, "invalid persisted friendly settings snapshots are discarded safely")

local settingsOpenCallsBeforeSlash = settingsOpenCalls
HTF.Options:Open("stats")
check(HTF.Options:IsPageVisible("stats"), "stats page becomes visible")
equal(settingsOpenCalls, settingsOpenCallsBeforeSlash, "slash command opens the dedicated settings frame directly")
equal(HTF.Options.panel.points[1][1], "CENTER", "dedicated settings frame is centered when opened")
HTF.Options.panel.scripts.OnDragStart(HTF.Options.panel)
check(HTF.Options.panel.moving, "dedicated settings frame starts moving when dragged")
HTF.Options.panel:ClearAllPoints()
HTF.Options.panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -40)
HTF.Options.panel.scripts.OnDragStop(HTF.Options.panel)
check(HTF.Options.panel.stoppedMoving, "dedicated settings frame stops moving when drag ends")
HTF.Options.closeButton.scripts.OnClick(HTF.Options.closeButton)
check(not HTF.Options.panel:IsShown(), "settings close button hides the dedicated frame")
HTF.Options:Open("stats")
check(HTF.Options.panel:IsShown(), "opening settings restores the dedicated frame")
equal(HTF.Options.panel.points[1][1], "TOPLEFT", "reopening settings keeps the moved window position")
equal(HTF.Stats.view, nil, "settings page no longer owns a live stat-value view")
local configuredStatRows = 0
for _ in pairs(HTF.Options.statSettingRows) do
	configuredStatRows = configuredStatRows + 1
end
equal(configuredStatRows, 18, "settings page exposes all stat and adventure-status controls")
equal(HTF.Options.statsFontValue:GetText(), "15", "settings page displays the active font size")

local leftToggle = HTF.Options.statsDisplayToggleRow
local rightToggle = HTF.Options.statsLockToggleRow
equal(leftToggle.width, nil, "left stats toggle does not use a fixed width")
equal(rightToggle.width, nil, "right stats toggle does not use a fixed width")
equal(#leftToggle.points, 2, "left stats toggle stretches between two responsive anchors")
equal(leftToggle.points[1][3], "TOPLEFT", "left stats toggle starts at the content edge")
equal(leftToggle.points[2][3], "TOP", "left stats toggle ends at the content midpoint")
equal(rightToggle.points[1][3], "TOP", "right stats toggle starts at the content midpoint")
equal(rightToggle.points[2][3], "TOPRIGHT", "right stats toggle ends at the content edge")

local friendlyClassColorToggle = HTF.Options.friendlyNameClassColorToggleRow
local friendlyFontToggle = HTF.Options.friendlyNameFontToggleRow
equal(friendlyClassColorToggle.width, nil, "friendly class-color toggle does not use a fixed width")
equal(friendlyFontToggle.width, nil, "friendly font-size toggle does not use a fixed width")
equal(#friendlyClassColorToggle.points, 2, "friendly class-color toggle uses responsive anchors")
equal(#friendlyFontToggle.points, 2, "friendly font-size toggle uses responsive anchors")

local leftStatRow = HTF.Options.statSettingRows.strength
local rightStatRow = HTF.Options.statSettingRows.mastery
equal(leftStatRow.width, nil, "left stat control does not use a fixed width")
equal(rightStatRow.width, nil, "right stat control does not use a fixed width")
equal(leftStatRow.points[2][3], "TOP", "left stat control is constrained to the content midpoint")
equal(rightStatRow.points[1][3], "TOP", "right stat control begins at the content midpoint")
equal(rightStatRow.points[2][3], "TOPRIGHT", "right stat control remains inside the content edge")

HTF.Options.panel:Hide()
local readsBeforeHiddenPanelEvent = statReads
HTF.Stats:OnEvent("COMBAT_RATING_UPDATE")
flushTimers()
check(statReads > readsBeforeHiddenPanelEvent, "HUD refreshes even while the settings panel is hidden")

secretCrit = true
local critOk, critError = pcall(function()
	HTF.Stats:Refresh()
end)
check(critOk, "secret crit values must not be compared or formatted in the HUD: " .. tostring(critError))
equal(HTF.Stats.overlay.rows.criticalStrike:GetText(), HTF.Stats:GetStatLabel("criticalStrike") .. ": " .. HTF.L.STAT_RESTRICTED, "secret crit is marked restricted in the HUD")
equal(HTF.Stats.overlay.status:GetText(), HTF.L.STATS_PARTIALLY_RESTRICTED, "restricted stats produce a safe HUD status")
secretCrit = false

secretHaste = true
local hasteOk, hasteError = pcall(function()
	HTF.Stats:Refresh()
end)
check(hasteOk, "secret percentage values must not enter boolean or formatting operations: " .. tostring(hasteError))
equal(HTF.Stats.overlay.rows.haste:GetText(), HTF.Stats:GetStatLabel("haste") .. ": " .. HTF.L.STAT_RESTRICTED, "secret haste is marked restricted in the HUD")
secretHaste = false
HTF.Stats:Refresh()

secretPrimaryStat = true
secretArmor = true
secretOtherStats = true
local broadSecretStatsOk, broadSecretStatsError = pcall(function()
	HTF.Stats:Refresh()
end)
check(broadSecretStatsOk, "secret primary/armor/secondary stats must not be formatted or combined: " .. tostring(broadSecretStatsError))
equal(HTF.Stats.overlay.rows.strength:GetText(), HTF.Stats:GetStatLabel("strength") .. ": " .. HTF.L.STAT_RESTRICTED, "secret primary stat is marked restricted")
equal(HTF.Stats.overlay.rows.armor:GetText(), HTF.Stats:GetStatLabel("armor") .. ": " .. HTF.L.STAT_RESTRICTED, "secret armor is marked restricted")
for _, key in ipairs({ "mastery", "versatility", "lifesteal", "avoidance", "speed", "dodge", "parry" }) do
	contains(HTF.Stats.overlay.rows[key]:GetText(), HTF.L.STAT_RESTRICTED, "secret secondary stat is marked restricted: " .. key)
end
secretPrimaryStat = false
secretArmor = false
secretOtherStats = false
HTF.Stats:Refresh()

HTF:SetSetting("showStats", false)
check(not HTF.Stats.overlay:IsShown(), "disabling stats hides the HUD")
local readsBeforeHiddenOverlayEvent = statReads
HTF.Stats:OnEvent("COMBAT_RATING_UPDATE")
flushTimers()
equal(statReads, readsBeforeHiddenOverlayEvent, "hidden HUD does not read stat APIs")
HTF:SetSetting("showStats", true)
flushTimers()
check(HTF.Stats.overlay:IsShown(), "re-enabling stats shows the HUD")

local fullOverlayHeight = HTF.Stats.overlay.height
local strengthReadsBeforeHide = unitStatReads[1]
local agilityReadsBeforeHide = unitStatReads[2]
HTF.Stats:SetStatVisible("strength", false)
check(not HTF.Stats.overlay.rows.strength:IsShown(), "per-stat visibility hides the selected HUD row")
equal(HTF.Stats:GetVisibleStatCount(), 13, "visible stat count updates after hiding a row")
check(HTF.Stats.overlay.height < fullOverlayHeight, "HUD height shrinks when a stat row is hidden")
flushTimers()
equal(unitStatReads[1], strengthReadsBeforeHide, "hidden stat API is not read")
check(unitStatReads[2] > agilityReadsBeforeHide, "visible stat APIs continue to refresh")
HTF.Stats:SetStatVisible("strength", true)
flushTimers()
check(HTF.Stats.overlay.rows.strength:IsShown(), "per-stat visibility can restore a HUD row")
equal(HTF.Stats:GetVisibleStatCount(), 14, "visible stat count restores after showing a row")

check(HTF.Options.statSettingRows.durability ~= nil, "settings expose a durability toggle")
check(HTF.Options.statSettingRows.bagSpace ~= nil, "settings expose a bag-space toggle")
check(HTF.Options.statSettingRows.money ~= nil, "settings expose a money toggle")
check(HTF.Options.statSettingRows.latency ~= nil, "settings expose a latency toggle")
check(HTF.Stats.eventFrame.events.UPDATE_INVENTORY_DURABILITY, "HUD listens for durability changes")
check(HTF.Stats.eventFrame.events.BAG_UPDATE_DELAYED, "HUD listens for settled bag changes")
check(HTF.Stats.eventFrame.events.PLAYER_MONEY, "HUD listens for money changes")
check(HTF.Stats.eventFrame.events.ZONE_CHANGED_NEW_AREA, "HUD refreshes latency after area changes")

for _, key in ipairs({ "durability", "bagSpace", "money", "latency" }) do
	HTF.Stats:SetStatVisible(key, true)
end
flushTimers()
equal(HTF.Stats:GetVisibleAdventureStatusCount(), 4, "all selected adventure rows become visible")
equal(HTF.Stats.overlay.rows.durability:GetText(), HTF.Stats:GetStatLabel("durability") .. ": 35%", "HUD shows average equipment durability")
equal(HTF.Stats.overlay.rows.bagSpace:GetText(), HTF.Stats:GetStatLabel("bagSpace") .. ": 2/80", "HUD shows free and total bag slots")
contains(HTF.Stats.overlay.rows.money:GetText(), HTF.Stats:GetStatLabel("money") .. ": ", "HUD shows current money")
equal(HTF.Stats.overlay.rows.latency:GetText(), HTF.Stats:GetStatLabel("latency") .. ": 42 ms", "HUD shows world latency")
equal(HTF.Stats.overlay.rows.durability.textColor[1], 0.96, "low durability uses the warning color")
equal(HTF.Stats.overlay.rows.bagSpace.textColor[1], 1.00, "nearly full bags use the critical color")

inventoryDurability[1].current = 10
fireEvent("UPDATE_INVENTORY_DURABILITY")
flushTimers()
equal(HTF.Stats.overlay.rows.durability:GetText(), HTF.Stats:GetStatLabel("durability") .. ": 10%", "durability refreshes from its event")
equal(HTF.Stats.overlay.rows.durability.textColor[1], 1.00, "critical durability uses the critical color")

bagFreeSlots[0] = 5
fireEvent("BAG_UPDATE_DELAYED")
flushTimers()
equal(HTF.Stats.overlay.rows.bagSpace:GetText(), HTF.Stats:GetStatLabel("bagSpace") .. ": 5/80", "bag space refreshes from its event")
equal(HTF.Stats.overlay.rows.bagSpace.textColor[1], 0.96, "low bag space uses the warning color")

worldLatency = 77
fireEvent("ZONE_CHANGED_NEW_AREA")
flushTimers()
equal(HTF.Stats.overlay.rows.latency:GetText(), HTF.Stats:GetStatLabel("latency") .. ": 77 ms", "latency refreshes from an area-change event")

secretDurability = true
local secretDurabilityOk, secretDurabilityError = pcall(function()
	HTF.Stats:Refresh()
end)
check(secretDurabilityOk, "secret durability values must not be combined or formatted: " .. tostring(secretDurabilityError))
contains(HTF.Stats.overlay.rows.durability:GetText(), HTF.L.STAT_RESTRICTED, "secret durability is marked restricted")
secretDurability = false

secretBagSpace = true
local secretBagSpaceOk, secretBagSpaceError = pcall(function()
	HTF.Stats:Refresh()
end)
check(secretBagSpaceOk, "secret bag-space values must not be combined or formatted: " .. tostring(secretBagSpaceError))
contains(HTF.Stats.overlay.rows.bagSpace:GetText(), HTF.L.STAT_RESTRICTED, "secret bag space is marked restricted")
secretBagSpace = false

secretLatency = true
local secretLatencyOk, secretLatencyError = pcall(function()
	HTF.Stats:Refresh()
end)
check(secretLatencyOk, "secret latency values must not be formatted: " .. tostring(secretLatencyError))
contains(HTF.Stats.overlay.rows.latency:GetText(), HTF.L.STAT_RESTRICTED, "secret latency is marked restricted")
secretLatency = false

inventoryDurability[1] = nil
HTF.Stats:Refresh()
equal(HTF.Stats.overlay.rows.durability:GetText(), HTF.Stats:GetStatLabel("durability") .. ": " .. HTF.L.STAT_UNAVAILABLE, "missing durability data is unavailable rather than restricted")
inventoryDurability[1] = { current = 35, maximum = 100 }

local getContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots
C_Container.GetContainerNumFreeSlots = nil
HTF.Stats:Refresh()
equal(HTF.Stats.overlay.rows.bagSpace:GetText(), HTF.Stats:GetStatLabel("bagSpace") .. ": " .. HTF.L.STAT_UNAVAILABLE, "missing bag API is unavailable rather than restricted")
C_Container.GetContainerNumFreeSlots = getContainerNumFreeSlots

local getNetStats = GetNetStats
GetNetStats = nil
HTF.Stats:Refresh()
equal(HTF.Stats.overlay.rows.latency:GetText(), HTF.Stats:GetStatLabel("latency") .. ": " .. HTF.L.STAT_UNAVAILABLE, "missing latency API is unavailable rather than restricted")
GetNetStats = getNetStats

local getMoney = GetMoney
GetMoney = nil
HTF.Stats:Refresh()
equal(HTF.Stats.overlay.rows.money:GetText(), HTF.Stats:GetStatLabel("money") .. ": " .. HTF.L.STAT_UNAVAILABLE, "missing money API is unavailable rather than restricted")
GetMoney = getMoney

inventoryDurability[1].current = 35
bagFreeSlots[0] = 2
worldLatency = 42
for _, key in ipairs({ "durability", "bagSpace", "money", "latency" }) do
	HTF.Stats:SetStatVisible(key, false)
end
flushTimers()
equal(HTF.Stats:GetVisibleAdventureStatusCount(), 0, "adventure rows can be hidden again")

HTF.Stats:SetFontSize(19)
equal(HTF:GetSetting("statsFontSize"), 19, "font size persists in settings")
equal(HTF.Stats.overlay.rows.haste.fontSize, 19, "font size applies to HUD rows")
equal(HTF.Options.statsFontValue:GetText(), "19", "font size control refreshes immediately")
HTF.Stats:SetFontSize(100)
equal(HTF:GetSetting("statsFontSize"), HTF.Stats.MAX_FONT_SIZE, "font size is clamped to its safe maximum")
HTF.Stats:SetFontSize(14)

local originalR, originalG, originalB = HTF.Stats:GetStatColor("haste")
HTF.Options:OpenStatColorPicker("haste")
check(ColorPickerFrame.shown, "current 12.1 color picker opens")
equal(ColorPickerFrame.info.hasOpacity, false, "stat colors do not expose opacity")
local overlayPointsBeforeColorDrag = HTF.Stats.overlay.points
ColorPickerFrame.r, ColorPickerFrame.g, ColorPickerFrame.b = 0.12, 0.34, 0.56
ColorPickerFrame.info.swatchFunc()
local changedR, changedG, changedB = HTF.Stats:GetStatColor("haste")
equal(changedR, 0.12, "color picker persists red component")
equal(changedG, 0.34, "color picker persists green component")
equal(changedB, 0.56, "color picker persists blue component")
equal(HTF.Stats.overlay.rows.haste.textColor[3], 0.56, "color picker updates the HUD immediately")
check(HTF.Stats.overlay.points == overlayPointsBeforeColorDrag, "color dragging does not re-anchor or relayout the HUD")
ColorPickerFrame.info.cancelFunc({ r = originalR, g = originalG, b = originalB })
local restoredR, restoredG, restoredB = HTF.Stats:GetStatColor("haste")
equal(restoredR, originalR, "canceling color picker restores red")
equal(restoredG, originalG, "canceling color picker restores green")
equal(restoredB, originalB, "canceling color picker restores blue")

HTF.Stats.overlay.moving = false
HTF.Stats.overlay.scripts.OnDragStart(HTF.Stats.overlay)
equal(HTF.Stats.overlay.moving, false, "locked HUD cannot start moving")
HTF:SetSetting("statsLocked", false)
equal(HTF.Stats.overlay.mouseEnabled, true, "unlocked HUD accepts mouse input")
equal(HTF.Stats.overlay.backdropColor[4], 0.82, "unlocked HUD shows its drag background")
check(HTF.Stats.overlay.title:IsShown(), "unlocked HUD shows its drag hint")
check(HTF.Stats.overlay.resizeHandle:IsShown(), "unlocked HUD shows its resize handle")
local resizeBaseWidth = HTF.Stats.overlayBaseWidth
local resizeBaseHeight = HTF.Stats.overlayBaseHeight
HTF.Stats.overlay.resizeHandle.scripts.OnDragStart(HTF.Stats.overlay.resizeHandle)
equal(HTF.Stats.overlay.sizing, "BOTTOMRIGHT", "resize handle starts native bottom-right sizing")
check(HTF.Stats.overlay.resizeBounds ~= nil, "resize handle applies bounds for the allowed scale range")
HTF.Stats.overlay:SetSize(resizeBaseWidth * 1.5, resizeBaseHeight * 1.5)
HTF.Stats.overlay.resizeHandle.scripts.OnDragStop(HTF.Stats.overlay.resizeHandle)
equal(HTF:GetSetting("statsScale"), 1.5, "resizing persists proportional HUD scale")
equal(HTF.Stats.overlay:GetScale(), 1.5, "resizing applies HUD scale immediately")
equal(HTF.Stats.overlay.width, resizeBaseWidth, "resizing restores the HUD's calculated base width")
equal(HTF.Stats.overlay.height, resizeBaseHeight, "resizing restores the HUD's calculated base height")
HTF.Stats:SetScale(99)
equal(HTF.Stats:GetScale(), HTF.Stats.MAX_SCALE, "HUD scale clamps to its maximum")
HTF.Stats:SetScale(-1)
equal(HTF.Stats:GetScale(), HTF.Stats.MIN_SCALE, "HUD scale clamps to its minimum")
HTF.Stats:SetScale(1)
HTF.Stats.overlay.scripts.OnDragStart(HTF.Stats.overlay)
check(HTF.Stats.overlay.moving, "unlocked HUD starts moving")
HTF.Stats.overlay:ClearAllPoints()
HTF.Stats.overlay:SetPoint("CENTER", UIParent, "CENTER", 123, -45)
HTF.Stats.overlay.scripts.OnDragStop(HTF.Stats.overlay)
equal(HTF.db.statsPosition.point, "CENTER", "dragging persists HUD anchor point")
equal(HTF.db.statsPosition.x, 123, "dragging persists HUD x offset")
equal(HTF.db.statsPosition.y, -45, "dragging persists HUD y offset")
HTF.Stats:ApplyOverlaySettings()
equal(HTF.Stats.overlay.points[1][1], "CENTER", "persisted HUD position restores")
HTF.Stats.overlay:ClearAllPoints()
HTF.Stats.overlay:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 88, -99)
HTF.Stats.overlay:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -120, 140)
HTF.Stats:SavePosition()
equal(HTF.db.statsPosition.point, "TOPLEFT", "multi-anchor drag state persists its first canonical anchor")
equal(HTF.db.statsPosition.relativePoint, "TOPLEFT", "multi-anchor drag state persists the matching relative anchor")
equal(HTF.db.statsPosition.x, 88, "multi-anchor drag state persists its x offset")
HTF.Stats:ApplyOverlaySettings()
equal(#HTF.Stats.overlay.points, 1, "restoring a dragged HUD normalizes it to one stable anchor")
HTF.Stats:ResetPosition()
equal(HTF.db.statsPosition.point, HTF.defaults.statsPosition.point, "reset position restores default anchor")
HTF:SetSetting("statsLocked", true)
equal(HTF.Stats.overlay.mouseEnabled, false, "re-locking HUD releases mouse input")
equal(HTF.Stats.overlay.backdropColor[4], 0, "re-locking HUD restores transparency")
check(not HTF.Stats.overlay.resizeHandle:IsShown(), "re-locking HUD hides its resize handle")

combatLocked = true
fireEvent("PLAYER_REGEN_DISABLED")
equal(HTF.Stats.overlay.status:GetText(), HTF.L.STATS_IN_COMBAT, "combat preserves values and shows a HUD refresh notice")
combatLocked = false
fireEvent("PLAYER_REGEN_ENABLED")
flushTimers()
equal(HTF.Stats.overlay.status:GetText(), "", "leaving combat refreshes and clears the HUD notice")

HTF.db.statsLocked = "corrupt"
HTF.db.statsFontSize = "large"
HTF.db.statsScale = 9
HTF.db.statsVisibility = "corrupt"
HTF.db.statsColors = { strength = { 2, -1, "blue" } }
HTF.db.statsPosition = { point = "BOGUS", relativePoint = "NOPE", x = 9000, y = "down" }
HTF.Stats:NormalizeSettings()
equal(HTF.db.statsLocked, HTF.defaults.statsLocked, "invalid persisted lock state resets to default")
equal(HTF.db.statsFontSize, HTF.defaults.statsFontSize, "invalid persisted font size resets to default")
equal(HTF.db.statsScale, HTF.Stats.MAX_SCALE, "persisted HUD scale is clamped")
equal(HTF.Stats:GetVisibleStatCount(), 14, "invalid persisted visibility table is rebuilt")
local normalizedR, normalizedG, normalizedB = HTF.Stats:GetStatColor("strength")
equal(normalizedR, 1, "persisted color red component is clamped")
equal(normalizedG, 0, "persisted color green component is clamped")
equal(normalizedB, HTF.defaults.statsColors.strength[3], "invalid persisted color component resets to default")
equal(HTF.db.statsPosition.point, HTF.defaults.statsPosition.point, "invalid persisted anchor resets to default")
equal(HTF.db.statsPosition.relativePoint, HTF.defaults.statsPosition.relativePoint, "invalid persisted relative anchor resets to default")
equal(HTF.db.statsPosition.x, 4096, "persisted x offset is clamped")
equal(HTF.db.statsPosition.y, HTF.defaults.statsPosition.y, "invalid persisted y offset resets to default")
HTF.Stats:ResetColors()
HTF.Stats:ResetPosition()
HTF.db.statsScale = "large"
HTF.Stats:NormalizeSettings()
equal(HTF.db.statsScale, HTF.defaults.statsScale, "invalid persisted HUD scale resets to default")
HTF.Stats:ApplyOverlaySettings()

HTF:SetSetting("autoRepair", true)
HTF:SetSetting("autoSellJunk", true)
HTF:SetSetting("showNotifications", true)

secretMerchantPermission = true
local secretMerchantOk, secretMerchantResult = pcall(function()
	return HTF.Merchant:TryAutoRepair()
end)
check(secretMerchantOk and secretMerchantResult == nil, "secret merchant permission safely skips repair")
secretMerchantPermission = false

secretRepairCost = true
local secretCostOk, secretCostResult = pcall(function()
	return HTF.Merchant:TryAutoRepair()
end)
check(secretCostOk and secretCostResult == nil, "secret repair cost safely skips repair")
secretRepairCost = false

secretRepairPermission = true
local secretRepairPermissionOk, secretRepairPermissionResult = pcall(function()
	return HTF.Merchant:TryAutoRepair()
end)
check(secretRepairPermissionOk and secretRepairPermissionResult == nil, "secret repair eligibility safely skips repair")
secretRepairPermission = false

secretPersonalMoney = true
local secretMoneyOk, secretMoneyResult = pcall(function()
	return HTF.Merchant:TryAutoRepair()
end)
check(secretMoneyOk and secretMoneyResult == false, "secret personal money safely reports insufficient funds")
secretPersonalMoney = false

HTF:SetSetting("repairFromGuild", true)
secretGuildPermission = true
personalMoney = 999999
guildWithdrawMoney = 50000
guildBankMoney = 50000
local secretGuildPermissionOk, secretGuildPermissionResult = pcall(function()
	return HTF.Merchant:TryAutoRepair()
end)
check(secretGuildPermissionOk, "secret guild permission must not be used as a branch condition")
equal(secretGuildPermissionResult.source, "personal", "secret guild permission falls back to personal repair")
secretGuildPermission = false

HTF.Merchant:ResetSessionLedger()
HTF:SetSetting("repairFromGuild", false)
personalMoney = 999999
local ledgerRepair = HTF.Merchant:TryAutoRepair()
check(type(ledgerRepair) == "table", "a completed repair returns ledger data")
local ledgerSale = HTF.Merchant:TryAutoSellJunk()
check(type(ledgerSale) == "table", "a completed junk sale returns ledger data")
equal(ledgerSale.count, 3, "ledger counts the stack quantity of sold junk")
equal(ledgerSale.value, 790, "ledger sums known gray-item vendor value")
check(ledgerSale.valueKnown, "cached item data produces a known junk-sale value")
local sessionLedger = HTF.Merchant:GetSessionLedger()
equal(sessionLedger.repairTotal, 12345, "session ledger records repair cost")
equal(sessionLedger.repairPersonal, 12345, "session ledger records personal repair spending")
equal(sessionLedger.repairGuild, 0, "session ledger records zero guild spending for personal repair")
equal(sessionLedger.junkItemsSold, 3, "session ledger records sold gray-item quantity")
equal(sessionLedger.junkIncome, 790, "session ledger records gray-item earnings")
contains(HTF.Merchant:GetSessionLedgerText(), HTF.L.LEDGER_SKIPPED_EMPTY, "new ledger reports no protected items skipped")

HTF:HandleSlashCommand(HTF.L.COMMAND_PROTECT_ALIAS .. " |Hitem:1001:::::::::|h[Discarded Saber]|h")
check(HTF.Merchant:IsJunkItemProtected(1001), "slash protection stores a gray-item ID")
local nativeSalesBeforeProtection = junkSellCalls
local individualSalesBeforeProtection = individualJunkSellCalls
local protectedSale = HTF.Merchant:TryAutoSellJunk()
equal(protectedSale.count, 1, "protected gray items are excluded from the sale count")
equal(protectedSale.value, 540, "protected gray items are excluded from the sale value")
equal(junkSellCalls, nativeSalesBeforeProtection, "protected-item mode avoids native sell-all")
equal(individualJunkSellCalls, individualSalesBeforeProtection + 1, "protected-item mode sells only unprotected gray items")
equal(sessionLedger.junkItemsSold, 4, "session ledger accumulates protected-mode sales")
equal(sessionLedger.junkIncome, 1330, "session ledger accumulates protected-mode earnings")
equal(sessionLedger.skippedItems["1001"].count, 2, "session ledger records skipped protected stack quantity")
contains(HTF.Merchant:GetSessionLedgerText(), "Discarded Saber", "session ledger identifies skipped protected items")
HTF:HandleSlashCommand(HTF.L.COMMAND_PROTECTED_ALIAS)
contains(chatMessages[#chatMessages], "#1001", "localized slash command lists protected gray-item IDs")

HTF.Options:Open("merchant")
contains(HTF.Options.merchantLedgerText:GetText(), "Discarded Saber", "merchant page displays the live session ledger")
HTF:HandleSlashCommand(HTF.L.COMMAND_UNPROTECT_ALIAS .. " 1001")
check(not HTF.Merchant:IsJunkItemProtected(1001), "slash unprotect removes a protected gray-item ID")

HTF:HandleSlashCommand(HTF.L.COMMAND_PROTECT_ALIAS .. " 9999")
local nativeSalesBeforeAbsentProtection = junkSellCalls
local individualSalesBeforeAbsentProtection = individualJunkSellCalls
local absentProtectionSale = HTF.Merchant:TryAutoSellJunk()
equal(absentProtectionSale.count, 3, "unrelated protections still allow other gray items to sell")
equal(junkSellCalls, nativeSalesBeforeAbsentProtection, "any saved protection keeps sell-all disabled for safety")
equal(individualJunkSellCalls, individualSalesBeforeAbsentProtection + 2, "unrelated protections use per-item sale handling")
HTF:HandleSlashCommand(HTF.L.COMMAND_UNPROTECT_ALIAS .. " 9999")

repairCalls = 0
repairArguments = {}
junkSellCalls = 0
individualJunkSellCalls = 0
HTF.Merchant:ResetSessionLedger()

HTF:SetSetting("repairFromGuild", false)
personalMoney = 999999
guildCanRepair = true
guildWithdrawMoney = 999999
guildBankMoney = 999999

fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairCalls, 1, "merchant show repairs exactly once")
equal(repairArguments[1], "personal", "guild repair off always uses personal funds")
equal(junkSellCalls, 1, "merchant show sells junk exactly once")
fireEvent("MERCHANT_CLOSED")

local repairsBeforeCancelledRun = repairCalls
local salesBeforeCancelledRun = junkSellCalls
fireEvent("MERCHANT_SHOW")
fireEvent("MERCHANT_CLOSED")
flushTimers()
equal(repairCalls, repairsBeforeCancelledRun, "closing a merchant invalidates its pending repair timer")
equal(junkSellCalls, salesBeforeCancelledRun, "closing a merchant invalidates its pending junk-sale timer")

HTF:SetSetting("repairFromGuild", true)
guildCanRepair = true
guildWithdrawMoney = -1
guildBankMoney = 50000
fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairArguments[#repairArguments], true, "guild leader repair uses RepairAllItems(true)")
fireEvent("MERCHANT_CLOSED")

guildWithdrawMoney = 5000
guildBankMoney = 5000
personalMoney = 999999
local repairsBeforeMixed = repairCalls
fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairCalls, repairsBeforeMixed + 1, "guild funds can be combined with personal funds")
equal(repairArguments[#repairArguments], true, "mixed funding still uses the native guild repair call")
fireEvent("MERCHANT_CLOSED")

guildCanRepair = false
local repairsBeforeFallback = repairCalls
fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairCalls, repairsBeforeFallback + 1, "missing guild permission safely falls back to personal repair")
equal(repairArguments[#repairArguments], "personal", "permission fallback uses personal RepairAllItems call")
fireEvent("MERCHANT_CLOSED")

guildCanRepair = true
secretGuildFunds = true
personalMoney = 999999
local repairsBeforeRestrictedGuild = repairCalls
local restrictedGuildOk, restrictedGuildError = pcall(function()
	fireEvent("MERCHANT_SHOW")
	flushTimers()
end)
check(restrictedGuildOk, "secret guild-fund values must not be branched on: " .. tostring(restrictedGuildError))
equal(repairCalls, repairsBeforeRestrictedGuild + 1, "restricted guild funds safely fall back to personal repair")
equal(repairArguments[#repairArguments], "personal", "restricted guild funds use the personal repair call")
fireEvent("MERCHANT_CLOSED")
secretGuildFunds = false

guildCanRepair = true
guildWithdrawMoney = 5000
guildBankMoney = 5000
personalMoney = 5000
local repairsBeforeInsufficient = repairCalls
fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairCalls, repairsBeforeInsufficient, "insufficient combined funds skip repair")
fireEvent("MERCHANT_CLOSED")

HTF:SetSetting("repairFromGuild", false)
personalMoney = 999999
combatLocked = true
local repairsBeforeCombat = repairCalls
local salesBeforeCombat = junkSellCalls
fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairCalls, repairsBeforeCombat, "combat blocks repair")
equal(junkSellCalls, salesBeforeCombat, "combat blocks junk sale")
check(HTF.Merchant.pendingRun, "combat-blocked merchant run is pending")

combatLocked = false
fireEvent("PLAYER_REGEN_ENABLED")
flushTimers()
equal(repairCalls, repairsBeforeCombat + 1, "repair retries once after combat")
equal(junkSellCalls, salesBeforeCombat + 1, "junk sale retries once after combat")
check(not HTF.Merchant.pendingRun, "merchant retry clears pending state")
fireEvent("MERCHANT_CLOSED")

HTF:SetSetting("debug", true)
HTF:ClearDebugLog()
local hiddenDebugText = HTF.Options.debugEditBox:GetText()
for index = 1, 85 do
	HTF:Debug("entry-" .. index)
end
equal(#HTF.debugLog, 80, "debug log remains bounded")
contains(HTF.debugLog[1], "entry-6", "debug log drops its oldest entry")
contains(HTF.debugLog[80], "entry-85", "debug log keeps its newest entry")
check(HTF.debugLog == HappyTreeFriendsDB.debugLog, "new log entries persist in SavedVariables")
equal(HTF.Options.debugEditBox:GetText(), hiddenDebugText, "hidden debug page avoids live text layout work")

HTF:InitializeDatabase()
equal(#HTF.debugLog, 80, "database reinitialization preserves bounded logs")
check(HTF.debugLog == HappyTreeFriendsDB.debugLog, "database reinitialization restores the shared log reference")

local report = HTF:BuildDiagnosticReport()
contains(report, "Happy Tree Friends - Diagnostic Report", "diagnostic report header")
contains(report, "WoW build: 69299", "diagnostic report build")
contains(report, "repairFromGuild: false", "diagnostic report includes guild repair setting")
contains(report, "friendlyNamesRuntime:", "diagnostic report includes friendly-name runtime details")
contains(report, "friendlyNamesOnly: false", "diagnostic report includes friendly names-only setting")
contains(report, "friendlyNameClassColors: false", "diagnostic report includes friendly name class-color setting")
contains(report, "friendlyNameCustomFontSize: false", "diagnostic report includes friendly name custom-size setting")
contains(report, "friendlyNameFontSize: 14", "diagnostic report includes friendly name font size")
contains(report, "statsFontSize: 15", "diagnostic report includes HUD font size")
contains(report, "statsScale: 1", "diagnostic report includes HUD scale")
contains(report, "visibleStats: 14/14", "diagnostic report includes visible HUD stat count")
contains(report, "visibleAdventureStatus: 0/4", "diagnostic report includes visible adventure-status count")
contains(report, "Protected junk item IDs: 0", "diagnostic report excludes protected item details while reporting their count")
contains(report, "sessionRepairs:", "diagnostic report includes session repair total")
contains(report, "sessionJunkIncome:", "diagnostic report includes session junk income")
contains(report, "statsPosition:", "diagnostic report includes HUD position")
contains(report, "Persisted debug log (80/80)", "diagnostic report log count")
contains(report, "no account, character, or realm identifiers", "diagnostic report privacy note")

HTF:HandleSlashCommand("dump")
check(HTF.Options.showingDiagnosticReport, "/htf dump opens diagnostic mode")
contains(HTF.Options.debugEditBox:GetText(), "Diagnostic Report", "/htf dump fills the copyable edit box")
check(HTF.Options.debugEditBox.highlighted, "/htf dump selects report text for copying")

HTF:HandleSlashCommand("clearlog")
equal(#HTF.debugLog, 0, "/htf clearlog empties the runtime log")
equal(#HappyTreeFriendsDB.debugLog, 0, "/htf clearlog empties the persisted log")

local secretLogOk, secretLogError = pcall(function()
	HTF:Debug(SECRET)
end)
check(secretLogOk, "secret debug messages must not be stringified: " .. tostring(secretLogError))
contains(HTF.debugLog[1], "<restricted>", "secret debug messages use a safe placeholder")

print(string.format("Happy Tree Friends %s headless checks passed: %d", testLocale, checks))
