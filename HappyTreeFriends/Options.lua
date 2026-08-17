local _, HTF = ...

local Options = {}
HTF.Options = Options

local COLORS = {
	background = { 0.045, 0.059, 0.086, 0.98 },
	sidebar = { 0.065, 0.082, 0.118, 1.00 },
	panel = { 0.090, 0.110, 0.157, 0.98 },
	panelHover = { 0.115, 0.140, 0.192, 1.00 },
	border = { 0.180, 0.220, 0.290, 0.95 },
	accent = { 0.310, 0.890, 0.670, 1.00 },
	accentMuted = { 0.150, 0.410, 0.330, 1.00 },
	text = { 0.900, 0.940, 1.000, 1.00 },
	muted = { 0.540, 0.590, 0.690, 1.00 },
	disabled = { 0.330, 0.370, 0.450, 1.00 },
}

local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
}

local function applyBackdrop(frame, background, border)
	frame:SetBackdrop(BACKDROP)
	frame:SetBackdropColor(background[1], background[2], background[3], background[4])
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function createText(parent, template, text, size, color)
	local fontString = parent:CreateFontString(nil, "OVERLAY", template)
	if size then
		local font, _, flags = fontString:GetFont()
		fontString:SetFont(font, size, flags)
	end
	if color then
		fontString:SetTextColor(color[1], color[2], color[3], color[4])
	end
	fontString:SetText(text or "")
	return fontString
end

local function createActionButton(parent, text)
	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetHeight(30)
	applyBackdrop(button, COLORS.panel, COLORS.border)

	button.label = createText(button, "GameFontNormalSmall", text, 12, COLORS.text)
	button.label:SetPoint("CENTER")

	button:SetScript("OnEnter", function(self)
		self:SetBackdropColor(COLORS.panelHover[1], COLORS.panelHover[2], COLORS.panelHover[3], COLORS.panelHover[4])
		self:SetBackdropBorderColor(COLORS.accentMuted[1], COLORS.accentMuted[2], COLORS.accentMuted[3], COLORS.accentMuted[4])
	end)
	button:SetScript("OnLeave", function(self)
		self:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], COLORS.panel[4])
		self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
	end)

	return button
end

function Options:CreateToggleRow(parent, yOffset, settingKey, title, description)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	row:SetHeight(70)
	applyBackdrop(row, COLORS.panel, COLORS.border)

	local titleText = createText(row, "GameFontNormal", title, 14, COLORS.text)
	titleText:SetPoint("TOPLEFT", 16, -13)
	titleText:SetJustifyH("LEFT")

	local descriptionText = createText(row, "GameFontHighlightSmall", description, 11, COLORS.muted)
	descriptionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
	descriptionText:SetPoint("RIGHT", row, "RIGHT", -78, 0)
	descriptionText:SetJustifyH("LEFT")
	descriptionText:SetJustifyV("TOP")

	local toggle = CreateFrame("Frame", nil, row, "BackdropTemplate")
	toggle:SetSize(48, 24)
	toggle:SetPoint("RIGHT", row, "RIGHT", -16, 0)
	applyBackdrop(toggle, COLORS.disabled, COLORS.border)

	toggle.knob = toggle:CreateTexture(nil, "ARTWORK")
	toggle.knob:SetTexture("Interface\\Buttons\\WHITE8x8")
	toggle.knob:SetSize(18, 18)

	toggle.state = createText(toggle, "GameFontNormalSmall", "", 9, COLORS.text)
	toggle.state:SetPoint("CENTER")

	function toggle:Render(value)
		self.knob:ClearAllPoints()
		if value then
			self:SetBackdropColor(COLORS.accentMuted[1], COLORS.accentMuted[2], COLORS.accentMuted[3], COLORS.accentMuted[4])
			self:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], COLORS.accent[4])
			self.knob:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
			self.knob:SetPoint("RIGHT", -3, 0)
			self.state:SetText("开")
		else
			self:SetBackdropColor(COLORS.disabled[1], COLORS.disabled[2], COLORS.disabled[3], COLORS.disabled[4])
			self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
			self.knob:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
			self.knob:SetPoint("LEFT", 3, 0)
			self.state:SetText("关")
		end
	end

	row:SetScript("OnEnter", function(self)
		self:SetBackdropColor(COLORS.panelHover[1], COLORS.panelHover[2], COLORS.panelHover[3], COLORS.panelHover[4])
	end)
	row:SetScript("OnLeave", function(self)
		self:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], COLORS.panel[4])
	end)
	row:SetScript("OnClick", function()
		HTF:SetSetting(settingKey, not HTF:GetSetting(settingKey))
	end)

	row.toggle = toggle
	row.settingKey = settingKey
	table.insert(self.toggles, row)
	return row
end

function Options:CreateNavigationButton(parent, key, text, yOffset)
	local options = self
	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)
	button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, yOffset)
	button:SetHeight(38)
	applyBackdrop(button, COLORS.sidebar, COLORS.sidebar)

	button.label = createText(button, "GameFontNormal", text, 13, COLORS.muted)
	button.label:SetPoint("LEFT", 12, 0)
	button.label:SetJustifyH("LEFT")

	function button:SetSelected(selected)
		self.selected = selected
		if selected then
			self:SetBackdropColor(COLORS.accentMuted[1], COLORS.accentMuted[2], COLORS.accentMuted[3], COLORS.accentMuted[4])
			self:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], COLORS.accent[4])
			self.label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
		else
			self:SetBackdropColor(COLORS.sidebar[1], COLORS.sidebar[2], COLORS.sidebar[3], COLORS.sidebar[4])
			self:SetBackdropBorderColor(COLORS.sidebar[1], COLORS.sidebar[2], COLORS.sidebar[3], COLORS.sidebar[4])
			self.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], COLORS.muted[4])
		end
	end

	button:SetScript("OnEnter", function(self)
		if not self.selected then
			self:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], COLORS.panel[4])
			self.label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
		end
	end)
	button:SetScript("OnLeave", function(self)
		if not self.selected then
			self:SetBackdropColor(COLORS.sidebar[1], COLORS.sidebar[2], COLORS.sidebar[3], COLORS.sidebar[4])
			self.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], COLORS.muted[4])
		end
	end)
	button:SetScript("OnClick", function()
		options:SelectPage(key)
	end)

	self.navigation[key] = button
	return button
end

function Options:AddPageHeader(page, title, subtitle)
	local heading = createText(page, "GameFontNormalLarge", title, 22, COLORS.text)
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -18)

	local supporting = createText(page, "GameFontHighlightSmall", subtitle, 12, COLORS.muted)
	supporting:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
	supporting:SetPoint("RIGHT", page, "RIGHT", -20, 0)
	supporting:SetJustifyH("LEFT")

	local rule = page:CreateTexture(nil, "ARTWORK")
	rule:SetTexture("Interface\\Buttons\\WHITE8x8")
	rule:SetColorTexture(COLORS.accentMuted[1], COLORS.accentMuted[2], COLORS.accentMuted[3], 1)
	rule:SetPoint("TOPLEFT", supporting, "BOTTOMLEFT", 0, -14)
	rule:SetPoint("RIGHT", page, "RIGHT", -20, 0)
	rule:SetHeight(1)
end

function Options:CreateOverviewPage(page)
	self:AddPageHeader(page, HTF.L.ADDON_NAME, HTF.L.SUBTITLE)

	local card = CreateFrame("Frame", nil, page, "BackdropTemplate")
	card:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -96)
	card:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -96)
	card:SetHeight(118)
	applyBackdrop(card, COLORS.panel, COLORS.border)

	local title = createText(card, "GameFontNormal", "MVP · WoW Retail 12.1", 14, COLORS.text)
	title:SetPoint("TOPLEFT", 16, -15)

	local body = createText(card, "GameFontHighlightSmall", HTF.L.SETTINGS_HELP, 12, COLORS.muted)
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -9)
	body:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")

	local statusTitle = createText(page, "GameFontNormal", "功能状态", 14, COLORS.text)
	statusTitle:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -24)
	statusTitle:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", 0, -24)
	statusTitle:SetJustifyH("LEFT")

	self.overviewStatus = {}
	local statuses = {
		{ key = "autoRepair", label = HTF.L.AUTO_REPAIR },
		{ key = "autoSellJunk", label = HTF.L.AUTO_SELL_JUNK },
		{ key = "showStats", label = HTF.L.CHARACTER_STATS },
		{ key = "debug", label = HTF.L.DEBUG_MODE },
	}

	for index, status in ipairs(statuses) do
		local row = CreateFrame("Frame", nil, page, "BackdropTemplate")
		row:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -10 - (index - 1) * 38)
		row:SetPoint("TOPRIGHT", statusTitle, "BOTTOMRIGHT", 0, -10 - (index - 1) * 38)
		row:SetHeight(30)
		applyBackdrop(row, COLORS.panel, COLORS.border)

		row.dot = row:CreateTexture(nil, "ARTWORK")
		row.dot:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.dot:SetSize(7, 7)
		row.dot:SetPoint("LEFT", 13, 0)

		row.label = createText(row, "GameFontHighlightSmall", status.label, 12, COLORS.text)
		row.label:SetPoint("LEFT", row.dot, "RIGHT", 9, 0)

		row.value = createText(row, "GameFontHighlightSmall", "", 12, COLORS.muted)
		row.value:SetPoint("RIGHT", -13, 0)
		table.insert(self.overviewStatus, { settingKey = status.key, row = row })
	end
end

function Options:CreateMerchantPage(page)
	self:AddPageHeader(page, HTF.L.MERCHANT, "仅在打开商人窗口时执行；不扫描背包，也不使用常驻轮询。")

	self:CreateToggleRow(page, -96, "autoRepair", HTF.L.AUTO_REPAIR, HTF.L.AUTO_REPAIR_DESC)
	self:CreateToggleRow(page, -174, "autoSellJunk", HTF.L.AUTO_SELL_JUNK, HTF.L.AUTO_SELL_JUNK_DESC)
	self:CreateToggleRow(page, -252, "showNotifications", HTF.L.SHOW_NOTIFICATIONS, HTF.L.SHOW_NOTIFICATIONS_DESC)

	local note = CreateFrame("Frame", nil, page, "BackdropTemplate")
	note:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -346)
	note:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -346)
	note:SetHeight(72)
	applyBackdrop(note, COLORS.sidebar, COLORS.border)

	local noteText = createText(note, "GameFontHighlightSmall", HTF.L.AUTO_ACTIONS_NOTICE .. " 自动修理只使用个人金币；金币不足时不会扣款。自动售卖使用 12.1 的 C_MerchantFrame.SellAllJunkItems()，只处理有售价的灰色物品。", 12, COLORS.muted)
	noteText:SetPoint("TOPLEFT", 14, -13)
	noteText:SetPoint("TOPRIGHT", -14, -13)
	noteText:SetJustifyH("LEFT")
	noteText:SetJustifyV("TOP")
end

function Options:CreateStatRow(parent, xOffset, yOffset, key, label)
	local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
	row:SetSize(278, 31)
	applyBackdrop(row, COLORS.panel, COLORS.border)

	row.label = createText(row, "GameFontHighlightSmall", label, 12, COLORS.muted)
	row.label:SetPoint("LEFT", 12, 0)
	row.defaultLabel = label

	row.value = createText(row, "GameFontNormal", HTF.L.STAT_UNAVAILABLE, 12, COLORS.text)
	row.value:SetPoint("RIGHT", -12, 0)
	row.value:SetJustifyH("RIGHT")
	return row
end

function Options:CreateStatsPage(page)
	self:AddPageHeader(page, HTF.L.CHARACTER_STATS, "事件触发刷新。12.0+ 受限值会显示为“受限”，不会造成 Lua 错误。")
	self:CreateToggleRow(page, -96, "showStats", HTF.L.SHOW_STATS, HTF.L.SHOW_STATS_DESC)

	local profileCard = CreateFrame("Frame", nil, page, "BackdropTemplate")
	profileCard:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -180)
	profileCard:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -180)
	profileCard:SetHeight(58)
	applyBackdrop(profileCard, COLORS.sidebar, COLORS.border)

	local profile = createText(profileCard, "GameFontNormal", "", 13, COLORS.text)
	profile:SetPoint("TOPLEFT", 14, -11)
	profile:SetPoint("RIGHT", profileCard, "RIGHT", -106, 0)
	profile:SetJustifyH("LEFT")

	local status = createText(profileCard, "GameFontHighlightSmall", "", 11, COLORS.muted)
	status:SetPoint("TOPLEFT", profile, "BOTTOMLEFT", 0, -7)
	status:SetPoint("RIGHT", profileCard, "RIGHT", -106, 0)
	status:SetJustifyH("LEFT")

	local refreshButton = createActionButton(profileCard, HTF.L.REFRESH)
	refreshButton:SetSize(82, 28)
	refreshButton:SetPoint("RIGHT", -14, 0)
	refreshButton:SetScript("OnClick", function()
		if HTF.Stats then
			HTF.Stats:Refresh()
		end
	end)

	local statRows = {}
	local left = {
		{ "strength", "力量" },
		{ "agility", "敏捷" },
		{ "stamina", "耐力" },
		{ "intellect", "智力" },
		{ "armor", "护甲" },
		{ "criticalStrike", "暴击" },
		{ "dodge", "躲闪" },
	}
	local right = {
		{ "haste", "急速" },
		{ "mastery", "精通" },
		{ "versatility", "全能" },
		{ "lifesteal", "吸血" },
		{ "avoidance", "闪避" },
		{ "speed", "速度" },
		{ "parry", "招架" },
	}

	for index, entry in ipairs(left) do
		statRows[entry[1]] = self:CreateStatRow(page, 20, -254 - (index - 1) * 37, entry[1], entry[2])
	end
	for index, entry in ipairs(right) do
		statRows[entry[1]] = self:CreateStatRow(page, 316, -254 - (index - 1) * 37, entry[1], entry[2])
	end

	if HTF.Stats then
		HTF.Stats:AttachView({
			profile = profile,
			status = status,
			rows = statRows,
		})
	end
end

function Options:CreateDebugPage(page)
	local options = self
	self:AddPageHeader(page, HTF.L.DEBUG, "用于定位商人事件、自动操作及属性刷新中的实际运行情况。")
	self:CreateToggleRow(page, -96, "debug", HTF.L.DEBUG_MODE, HTF.L.DEBUG_MODE_DESC)
	self.showingDiagnosticReport = false

	local helper = createText(page, "GameFontHighlightSmall", HTF.L.DEBUG_HELP, 12, COLORS.muted)
	helper:SetPoint("TOPLEFT", page, "TOPLEFT", 22, -183)
	helper:SetPoint("RIGHT", page, "RIGHT", -22, 0)
	helper:SetJustifyH("LEFT")

	local logTitle = createText(page, "GameFontNormal", HTF.L.DEBUG_LOG, 14, COLORS.text)
	logTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -220)

	local clearButton = createActionButton(page, HTF.L.DEBUG_CLEAR)
	clearButton:SetSize(78, 28)
	clearButton:SetPoint("RIGHT", page, "RIGHT", -20, -216)
	clearButton:SetScript("OnClick", function()
		HTF:ClearDebugLog()
		HTF:Notify(HTF.L.DEBUG_CLEARED)
	end)

	local reportButton = createActionButton(page, HTF.L.DEBUG_REPORT)
	reportButton:SetSize(92, 28)
	reportButton:SetPoint("RIGHT", clearButton, "LEFT", -8, 0)
	reportButton:SetScript("OnClick", function()
		if options.showingDiagnosticReport then
			options:ShowDebugLog()
		else
			options:ShowDiagnosticReport()
		end
	end)
	self.debugReportButton = reportButton

	local logPanel = CreateFrame("Frame", nil, page, "BackdropTemplate")
	logPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -254)
	logPanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -254)
	logPanel:SetHeight(194)
	applyBackdrop(logPanel, COLORS.sidebar, COLORS.border)

	local scrollFrame = CreateFrame("ScrollFrame", nil, logPanel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 10, -9)
	scrollFrame:SetPoint("BOTTOMRIGHT", logPanel, "BOTTOMRIGHT", -28, 9)
	self.debugScrollFrame = scrollFrame

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:EnableMouse(true)
	editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	editBox:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], COLORS.muted[4])
	editBox:SetTextInsets(4, 4, 4, 4)
	editBox:SetWidth(548)
	editBox:SetHeight(174)
	editBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	scrollFrame:SetScrollChild(editBox)
	self.debugEditBox = editBox

	local measure = createText(logPanel, "ChatFontNormal", "", 11, COLORS.muted)
	measure:SetWidth(540)
	measure:SetJustifyH("LEFT")
	measure:SetJustifyV("TOP")
	measure:Hide()
	self.debugMeasure = measure
end

function Options:SetDebugText(text, highlight)
	if not self.debugEditBox then
		return
	end

	local content = text or ""
	local viewportHeight = self.debugScrollFrame and self.debugScrollFrame:GetHeight() or 174
	if type(viewportHeight) ~= "number" or viewportHeight <= 0 then
		viewportHeight = 174
	end

	local measuredHeight = viewportHeight
	if self.debugMeasure then
		self.debugMeasure:SetText(content)
		local stringHeight = self.debugMeasure:GetStringHeight()
		if type(stringHeight) == "number" then
			measuredHeight = math.max(viewportHeight, stringHeight + 12)
		end
	end

	self.debugEditBox:SetHeight(measuredHeight)
	self.debugEditBox:SetText(content)
	self.debugEditBox:SetCursorPosition(0)
	if self.debugScrollFrame then
		self.debugScrollFrame:SetVerticalScroll(0)
	end
	if highlight then
		self.debugEditBox:SetFocus()
		self.debugEditBox:HighlightText()
	end
end

function Options:ShowDiagnosticReport()
	self.showingDiagnosticReport = true
	if self.debugReportButton and self.debugReportButton.label then
		self.debugReportButton.label:SetText(HTF.L.DEBUG_REPORT_BACK)
	end
	self:SetDebugText(HTF:BuildDiagnosticReport(), true)
end

function Options:ShowDebugLog()
	self.showingDiagnosticReport = false
	if self.debugReportButton and self.debugReportButton.label then
		self.debugReportButton.label:SetText(HTF.L.DEBUG_REPORT)
	end
	self:RefreshDebugLog()
end

function Options:CreatePanel()
	self.toggles = {}
	self.navigation = {}
	self.pages = {}

	local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	panel.name = HTF.L.ADDON_NAME
	panel:SetSize(840, 520)
	applyBackdrop(panel, COLORS.background, COLORS.border)
	self.panel = panel

	local sidebar = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	sidebar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	sidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
	sidebar:SetWidth(190)
	applyBackdrop(sidebar, COLORS.sidebar, COLORS.border)

	local brand = createText(sidebar, "GameFontNormalLarge", "Happy", 22, COLORS.text)
	brand:SetPoint("TOPLEFT", 18, -22)
	local tree = createText(sidebar, "GameFontNormalLarge", "Tree Friends", 22, COLORS.accent)
	tree:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -1)
	local version = createText(sidebar, "GameFontHighlightSmall", "MVP " .. HTF.VERSION, 10, COLORS.muted)
	version:SetPoint("TOPLEFT", tree, "BOTTOMLEFT", 0, -7)

	self:CreateNavigationButton(sidebar, "overview", HTF.L.OVERVIEW, -116)
	self:CreateNavigationButton(sidebar, "merchant", HTF.L.MERCHANT, -160)
	self:CreateNavigationButton(sidebar, "stats", HTF.L.CHARACTER_STATS, -204)
	self:CreateNavigationButton(sidebar, "debug", HTF.L.DEBUG, -248)

	local sidebarHelp = createText(sidebar, "GameFontHighlightSmall", "/htf", 12, COLORS.accent)
	sidebarHelp:SetPoint("BOTTOMLEFT", 18, 23)
	local sidebarHint = createText(sidebar, "GameFontHighlightSmall", "打开设置", 10, COLORS.muted)
	sidebarHint:SetPoint("BOTTOMLEFT", sidebarHelp, "TOPLEFT", 0, 3)

	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
	content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

	for _, key in ipairs({ "overview", "merchant", "stats", "debug" }) do
		local page = CreateFrame("Frame", nil, content)
		page:SetAllPoints(content)
		page:Hide()
		self.pages[key] = page
	end

	self:CreateOverviewPage(self.pages.overview)
	self:CreateMerchantPage(self.pages.merchant)
	self:CreateStatsPage(self.pages.stats)
	self:CreateDebugPage(self.pages.debug)

	panel:SetScript("OnShow", function()
		self:Refresh()
	end)
	panel:Hide()
end

function Options:GetCategoryID()
	if not self.category then
		return nil
	end
	if type(self.category.GetID) == "function" then
		return self.category:GetID()
	end
	return self.category.ID
end

function Options:RegisterCategory()
	if type(Settings) ~= "table"
		or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
		or type(Settings.RegisterAddOnCategory) ~= "function" then
		self.standalone = true
		return
	end

	self.category = Settings.RegisterCanvasLayoutCategory(self.panel, HTF.L.ADDON_NAME)
	Settings.RegisterAddOnCategory(self.category)
end

function Options:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	self.eventFrame:SetScript("OnEvent", function()
		self.eventFrame:UnregisterEvent("PLAYER_LOGIN")
		self:CreatePanel()
		self:RegisterCategory()
		self:SelectPage("overview")
		self:Refresh()
	end)
end

function Options:IsPageVisible(key)
	return self.panel
		and self.panel:IsVisible()
		and self.selectedPageKey == key
		and self.pages
		and self.pages[key]
		and self.pages[key]:IsVisible()
end

function Options:SelectPage(key)
	if not self.pages or not self.pages[key] then
		key = "overview"
	end

	self.selectedPageKey = key
	for pageKey, page in pairs(self.pages) do
		if pageKey == key then
			page:Show()
		else
			page:Hide()
		end
	end
	for pageKey, button in pairs(self.navigation) do
		button:SetSelected(pageKey == key)
	end

	if key == "stats" and HTF.Stats then
		HTF.Stats:Refresh()
	end
	self:RefreshOverview()
	self:RefreshDebugLog()
end

function Options:RefreshOverview()
	if not self.overviewStatus then
		return
	end

	for _, entry in ipairs(self.overviewStatus) do
		local enabled = HTF:GetSetting(entry.settingKey)
		if enabled then
			entry.row.dot:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
			entry.row.value:SetText("已开启")
			entry.row.value:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
		else
			entry.row.dot:SetColorTexture(COLORS.disabled[1], COLORS.disabled[2], COLORS.disabled[3], 1)
			entry.row.value:SetText("已关闭")
			entry.row.value:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], COLORS.muted[4])
		end
	end
end

function Options:RefreshDebugLog()
	if not self.debugEditBox or self.showingDiagnosticReport or not self:IsPageVisible("debug") then
		return
	end
	if #HTF.debugLog == 0 then
		self:SetDebugText(HTF.L.DEBUG_EMPTY)
		return
	end

	local first = math.max(1, #HTF.debugLog - 10)
	local lines = {}
	for index = first, #HTF.debugLog do
		table.insert(lines, HTF.debugLog[index])
	end
	self:SetDebugText(table.concat(lines, "\n"))
end

function Options:Refresh()
	if not self.panel then
		return
	end

	for _, row in ipairs(self.toggles) do
		row.toggle:Render(HTF:GetSetting(row.settingKey))
	end
	self:RefreshOverview()
	self:RefreshDebugLog()
	if self:IsPageVisible("stats") and HTF.Stats then
		HTF.Stats:Refresh()
	end
end

function Options:Open(page)
	if not self.panel then
		HTF:Notify("设置界面将在角色进入世界后可用。")
		return
	end

	self:SelectPage(page or "overview")
	local categoryID = self:GetCategoryID()
	if categoryID and type(Settings) == "table" and type(Settings.OpenToCategory) == "function" then
		Settings.OpenToCategory(categoryID)
	else
		self.panel:ClearAllPoints()
		self.panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		self.panel:SetFrameStrata("DIALOG")
		self.panel:Show()
	end
	self:Refresh()
end

function Options:OpenDiagnosticReport()
	if not self.panel then
		HTF:Notify("诊断界面将在角色进入世界后可用。")
		return
	end

	self:Open("debug")
	self:ShowDiagnosticReport()
end
