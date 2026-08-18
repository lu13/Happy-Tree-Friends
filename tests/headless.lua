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
	return self.name
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

function objectMethods:SetColorTexture(r, g, b, a)
	self.textureColor = { r, g, b, a }
end

function objectMethods:EnableMouse(enabled)
	self.mouseEnabled = enabled == true
end

function objectMethods:SetMovable(movable)
	self.movable = movable == true
end

function objectMethods:SetClampedToScreen(clamped)
	self.clampedToScreen = clamped == true
end

function objectMethods:RegisterForDrag(...)
	self.dragButtons = { ... }
end

function objectMethods:StartMoving()
	self.moving = true
end

function objectMethods:StopMovingOrSizing()
	self.moving = false
	self.stoppedMoving = true
end

local noOpMethods = {
	"SetBackdrop",
	"SetJustifyH",
	"SetJustifyV",
	"SetTexture",
	"SetFrameStrata",
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

local combatLocked = false
function InCombatLockdown()
	return combatLocked
end

local repairCalls = 0
local repairArguments = {}
local junkSellCalls = 0
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

C_MerchantFrame = {
	GetNumJunkItems = function()
		return 3
	end,
	SellAllJunkItems = function()
		junkSellCalls = junkSellCalls + 1
	end,
}

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

function UnitClass()
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
	"HappyTreeFriends/Merchant.lua",
	"HappyTreeFriends/Stats.lua",
	"HappyTreeFriends/Options.lua",
}) do
	local chunk, loadError = loadfile(path)
	check(chunk ~= nil, loadError)
	chunk("HappyTreeFriends", HTF)
end

fireEvent("ADDON_LOADED", "HappyTreeFriends")
equal(HTF.VERSION, "0.3.0", "addon version")
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
	VERSION_LABEL = { "0.3.0" },
	REPAIRED_PERSONAL = { "1g" },
	REPAIRED_GUILD = { "1g" },
	REPAIRED_MIXED = { "1g" },
	SOLD_JUNK = { 3 },
	DEBUG_REPAIR_COMPLETED = { "1g", "personal" },
	DEBUG_JUNK_SOLD = { 3 },
	DEBUG_STATS_POSITION_SAVED = { "TOP", "TOP", 1, -1 },
	DEBUG_STAT_VISIBILITY_UPDATED = { "haste", "true" },
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
equal(HTF:GetSetting("statsLocked"), true, "stats overlay defaults locked")
equal(HTF:GetSetting("statsFontSize"), 15, "stats overlay default font size")
equal(HTF.Stats:GetVisibleStatCount(), 14, "all stats default visible")

check(HTF.Stats.overlay ~= nil, "stats overlay is created during addon initialization")
equal(HTF.Stats.overlay:GetName(), "HappyTreeFriendsStatsOverlay", "stats overlay has a stable frame name")
check(HTF.Stats.overlay:IsShown(), "stats overlay defaults visible")
equal(HTF.Stats.overlay.mouseEnabled, false, "locked overlay does not intercept mouse input")
equal(HTF.Stats.overlay.backdropColor[4], 0, "locked overlay background is transparent")
equal(HTF.Stats.overlay.backdropBorderColor[4], 0, "locked overlay border is transparent")
check(not HTF.Stats.overlay.title:IsShown(), "locked overlay hides its drag hint")
check(HTF.Stats.overlay.movable, "stats overlay is movable")
check(HTF.Stats.overlay.clampedToScreen, "stats overlay stays clamped to screen")
equal(HTF.Stats.overlay.dragButtons[1], "LeftButton", "stats overlay uses left-button drag")
equal(HTF.Stats.overlay.rows.strength.fontSize, 15, "overlay applies the configured font size")
equal(HTF.Stats.overlay.rows.strength.fontFlags, "THICKOUTLINE", "overlay stat text uses a thick outline")
equal(HTF.Stats.overlay.rows.strength.shadowColor[4], 1, "overlay stat text uses an opaque black shadow")
equal(HTF.Stats.overlay.rows.strength.shadowOffset[1], 2, "overlay stat shadow has a visible horizontal offset")
equal(HTF.Stats.overlay.rows.strength.shadowOffset[2], -2, "overlay stat shadow has a visible vertical offset")
equal(HTF.Stats.overlay.status.fontFlags, "THICKOUTLINE", "overlay status text uses the same strong outline")
check(HTF.Stats.overlay.rows.strength.textColor[1] ~= HTF.Stats.overlay.rows.agility.textColor[1], "default stat rows use distinct colors")

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
equal(HTF.Options.selectedPageKey, "overview", "overview is the initial page")
equal(HTF.Options:IsPageVisible("overview"), false, "a hidden settings panel is not visible")
check(registeredCategory and registeredCategory.registered, "options panel is registered as an addon category")
equal(HTF.Options:GetCategoryID(), 120101, "registered category exposes its numeric ID")
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

HTF.Options:Open("stats")
check(HTF.Options:IsPageVisible("stats"), "stats page becomes visible")
equal(lastOpenedCategoryID, 120101, "options opens the registered numeric category ID")
equal(HTF.Stats.view, nil, "settings page no longer owns a live stat-value view")
local configuredStatRows = 0
for _ in pairs(HTF.Options.statSettingRows) do
	configuredStatRows = configuredStatRows + 1
end
equal(configuredStatRows, 14, "settings page exposes all stat visibility/color controls")
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

combatLocked = true
fireEvent("PLAYER_REGEN_DISABLED")
equal(HTF.Stats.overlay.status:GetText(), HTF.L.STATS_IN_COMBAT, "combat preserves values and shows a HUD refresh notice")
combatLocked = false
fireEvent("PLAYER_REGEN_ENABLED")
flushTimers()
equal(HTF.Stats.overlay.status:GetText(), "", "leaving combat refreshes and clears the HUD notice")

HTF.db.statsLocked = "corrupt"
HTF.db.statsFontSize = "large"
HTF.db.statsVisibility = "corrupt"
HTF.db.statsColors = { strength = { 2, -1, "blue" } }
HTF.db.statsPosition = { point = "BOGUS", relativePoint = "NOPE", x = 9000, y = "down" }
HTF.Stats:NormalizeSettings()
equal(HTF.db.statsLocked, HTF.defaults.statsLocked, "invalid persisted lock state resets to default")
equal(HTF.db.statsFontSize, HTF.defaults.statsFontSize, "invalid persisted font size resets to default")
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

repairCalls = 0
repairArguments = {}
junkSellCalls = 0

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
contains(report, "statsFontSize: 15", "diagnostic report includes HUD font size")
contains(report, "visibleStats: 14/14", "diagnostic report includes visible HUD stat count")
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
