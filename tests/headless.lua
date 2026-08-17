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

local noOpMethods = {
	"SetBackdrop",
	"SetBackdropColor",
	"SetBackdropBorderColor",
	"SetTextColor",
	"SetJustifyH",
	"SetJustifyV",
	"SetTexture",
	"SetColorTexture",
	"SetFrameStrata",
	"SetMultiLine",
	"SetAutoFocus",
	"EnableMouse",
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
local junkSellCalls = 0

function CanMerchantRepair()
	return true
end

function GetRepairAllCost()
	return 12345, true
end

function GetMoney()
	return 999999
end

function RepairAllItems()
	repairCalls = repairCalls + 1
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
local statReads = 0
local spellSchoolsRead = {}

function UnitName()
	return secretIdentity and SECRET or "Tester"
end

function UnitClass()
	return secretIdentity and SECRET or "德鲁伊", "DRUID", 11
end

function UnitLevel()
	return 80
end

function GetAverageItemLevel()
	return 650.5, 648.25
end

function UnitStat(_, index)
	statReads = statReads + 1
	return 1000 + index, 1100 + index
end

function UnitArmor()
	statReads = statReads + 1
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
	return 12.5
end

function GetMasteryEffect()
	return 18.25
end

CR_VERSATILITY_DAMAGE_DONE = 29

function GetCombatRatingBonus()
	return 4.5
end

function GetVersatilityBonus()
	return 1.5
end

function GetLifesteal()
	return 2.25
end

function GetAvoidance()
	return 3.5
end

function GetSpeed()
	return 4.75
end

function GetDodgeChance()
	return 6.5
end

function GetParryChance()
	return 7.25
end

function BreakUpLargeNumbers(value)
	return tostring(value)
end

function GetBuildInfo()
	return "12.1.0", "69299", "Aug 11 2026", 120100
end

function GetLocale()
	return "zhCN"
end

HappyTreeFriendsDB = { debugLog = {} }
for index = 1, 82 do
	if index == 10 then
		HappyTreeFriendsDB.debugLog[index] = false
	else
		HappyTreeFriendsDB.debugLog[index] = "seed-" .. index
	end
end

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
equal(HTF.VERSION, "0.1.1", "addon version")
equal(#HTF.debugLog, 80, "saved log is normalized to its cap")
equal(HTF.debugLog[1], "seed-2", "normalization keeps the newest valid entries")
check(HTF.debugLog == HappyTreeFriendsDB.debugLog, "runtime log must share the SavedVariables table")
equal(HTF:GetSetting("autoRepair"), false, "auto repair defaults off")
equal(HTF:GetSetting("autoSellJunk"), false, "auto sell defaults off")

fireEvent("PLAYER_LOGIN")
check(HTF.Options.panel ~= nil, "options panel is created at login")
equal(HTF.Options.selectedPageKey, "overview", "overview is the initial page")
equal(HTF.Options:IsPageVisible("overview"), false, "a hidden settings panel is not visible")
check(registeredCategory and registeredCategory.registered, "options panel is registered as an addon category")
equal(HTF.Options:GetCategoryID(), 120101, "registered category exposes its numeric ID")
check(HTF.Options.debugScrollFrame.ScrollBar ~= nil, "12.1 scroll template exposes its scrollbar through parentKey")
equal(HTF.Options.debugScrollFrame:GetName(), nil, "anonymous 12.1 scroll template remains supported")

local resizedFontCount = 0
for _, frame in ipairs(frames) do
	if frame.kind == "FontString" and frame.fontSize then
		resizedFontCount = resizedFontCount + 1
		equal(frame.fontFlags, "OUTLINE", "resizing text preserves template font flags")
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
equal(HTF.Stats.view.rows.criticalStrike.value:GetText(), "15.25%", "crit matches PaperDoll max melee/ranged/spell behavior")
local sawFirstSpellSchool = false
local sawLastSpellSchool = false
for _, school in ipairs(spellSchoolsRead) do
	check(school ~= 1, "PaperDoll crit calculation skips the physical school")
	sawFirstSpellSchool = sawFirstSpellSchool or school == 2
	sawLastSpellSchool = sawLastSpellSchool or school == MAX_SPELL_SCHOOLS
end
check(sawFirstSpellSchool and sawLastSpellSchool, "PaperDoll crit calculation reads spell schools 2 through MAX_SPELL_SCHOOLS")

secretIdentity = true
local profileOk, profileError = pcall(function()
	HTF.Stats:Refresh()
end)
check(profileOk, "secret identity values must not crash profile rendering: " .. tostring(profileError))
contains(HTF.Stats.view.profile:GetText(), "—", "secret identity falls back safely")
secretIdentity = false

secretCrit = true
local critOk, critError = pcall(function()
	HTF.Stats:Refresh()
end)
check(critOk, "secret crit values must not be compared or formatted: " .. tostring(critError))
equal(HTF.Stats.view.rows.criticalStrike.value:GetText(), HTF.L.STAT_RESTRICTED, "secret crit is marked restricted")
secretCrit = false

HTF.Options.panel:Hide()
local readsBeforeHiddenEvent = statReads
HTF.Stats:OnEvent("COMBAT_RATING_UPDATE")
flushTimers()
equal(statReads, readsBeforeHiddenEvent, "hidden settings panel does not refresh stats")

HTF:SetSetting("autoRepair", true)
HTF:SetSetting("autoSellJunk", true)
HTF:SetSetting("showNotifications", true)

fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairCalls, 1, "merchant show repairs exactly once")
equal(junkSellCalls, 1, "merchant show sells junk exactly once")
fireEvent("MERCHANT_CLOSED")

local repairsBeforeCancelledRun = repairCalls
local salesBeforeCancelledRun = junkSellCalls
fireEvent("MERCHANT_SHOW")
fireEvent("MERCHANT_CLOSED")
flushTimers()
equal(repairCalls, repairsBeforeCancelledRun, "closing a merchant invalidates its pending repair timer")
equal(junkSellCalls, salesBeforeCancelledRun, "closing a merchant invalidates its pending junk-sale timer")

combatLocked = true
fireEvent("MERCHANT_SHOW")
flushTimers()
equal(repairCalls, 1, "combat blocks repair")
equal(junkSellCalls, 1, "combat blocks junk sale")
check(HTF.Merchant.pendingRun, "combat-blocked merchant run is pending")

combatLocked = false
fireEvent("PLAYER_REGEN_ENABLED")
flushTimers()
equal(repairCalls, 2, "repair retries once after combat")
equal(junkSellCalls, 2, "junk sale retries once after combat")
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

print(string.format("Happy Tree Friends headless checks passed: %d", checks))
