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

local function anchorTwoColumnRow(frame, parent, column, yOffset)
	if column == "left" then
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
		frame:SetPoint("TOPRIGHT", parent, "TOP", -6, yOffset)
	else
		frame:SetPoint("TOPLEFT", parent, "TOP", 6, yOffset)
		frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOffset)
	end
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
		self.state:ClearAllPoints()
		if value then
			self:SetBackdropColor(COLORS.accentMuted[1], COLORS.accentMuted[2], COLORS.accentMuted[3], COLORS.accentMuted[4])
			self:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], COLORS.accent[4])
			self.knob:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
			self.knob:SetPoint("RIGHT", -3, 0)
			self.state:SetText(HTF.L.TOGGLE_ON)
			self.state:SetPoint("LEFT", 5, 0)
		else
			self:SetBackdropColor(COLORS.disabled[1], COLORS.disabled[2], COLORS.disabled[3], COLORS.disabled[4])
			self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
			self.knob:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
			self.knob:SetPoint("LEFT", 3, 0)
			self.state:SetText(HTF.L.TOGGLE_OFF)
			self.state:SetPoint("RIGHT", -4, 0)
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

function Options:CreateCompactToggleRow(parent, column, yOffset, settingKey, title, description)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	anchorTwoColumnRow(row, parent, column, yOffset)
	row:SetHeight(58)
	applyBackdrop(row, COLORS.panel, COLORS.border)

	local titleText = createText(row, "GameFontNormal", title, 13, COLORS.text)
	titleText:SetPoint("TOPLEFT", 13, -10)
	titleText:SetJustifyH("LEFT")

	local descriptionText = createText(row, "GameFontHighlightSmall", description, 10, COLORS.muted)
	descriptionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -5)
	descriptionText:SetPoint("RIGHT", row, "RIGHT", -62, 0)
	descriptionText:SetJustifyH("LEFT")

	local toggle = CreateFrame("Frame", nil, row, "BackdropTemplate")
	toggle:SetSize(40, 22)
	toggle:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	applyBackdrop(toggle, COLORS.disabled, COLORS.border)

	toggle.dot = toggle:CreateTexture(nil, "ARTWORK")
	toggle.dot:SetTexture("Interface\\Buttons\\WHITE8x8")
	toggle.dot:SetSize(14, 14)

	function toggle:Render(value)
		self.dot:ClearAllPoints()
		if value then
			self:SetBackdropColor(COLORS.accentMuted[1], COLORS.accentMuted[2], COLORS.accentMuted[3], COLORS.accentMuted[4])
			self:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], COLORS.accent[4])
			self.dot:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
			self.dot:SetPoint("RIGHT", -3, 0)
		else
			self:SetBackdropColor(COLORS.disabled[1], COLORS.disabled[2], COLORS.disabled[3], COLORS.disabled[4])
			self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
			self.dot:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
			self.dot:SetPoint("LEFT", 3, 0)
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

	local title = createText(card, "GameFontNormal", HTF.L.OVERVIEW_INTRO, 14, COLORS.text)
	title:SetPoint("TOPLEFT", 16, -15)

	local body = createText(card, "GameFontHighlightSmall", HTF.L.SETTINGS_HELP, 12, COLORS.muted)
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -9)
	body:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")

	local statusTitle = createText(page, "GameFontNormal", HTF.L.FEATURE_STATUS, 14, COLORS.text)
	statusTitle:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -24)
	statusTitle:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", 0, -24)
	statusTitle:SetJustifyH("LEFT")

	self.overviewStatus = {}
	local statuses = {
		{ key = "autoRepair", label = HTF.L.AUTO_REPAIR },
		{ key = "autoSellJunk", label = HTF.L.AUTO_SELL_JUNK },
		{ key = "friendlyNamesOnly", label = HTF.L.FRIENDLY_NAMES_ONLY },
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
	self:AddPageHeader(page, HTF.L.MERCHANT, HTF.L.MERCHANT_PAGE_HELP)

	self:CreateToggleRow(page, -84, "autoRepair", HTF.L.AUTO_REPAIR, HTF.L.AUTO_REPAIR_DESC)
	self:CreateToggleRow(page, -156, "repairFromGuild", HTF.L.REPAIR_FROM_GUILD, HTF.L.REPAIR_FROM_GUILD_DESC)
	self:CreateToggleRow(page, -228, "autoSellJunk", HTF.L.AUTO_SELL_JUNK, HTF.L.AUTO_SELL_JUNK_DESC)
	self:CreateToggleRow(page, -300, "showNotifications", HTF.L.SHOW_NOTIFICATIONS, HTF.L.SHOW_NOTIFICATIONS_DESC)

	local note = CreateFrame("Frame", nil, page, "BackdropTemplate")
	note:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -386)
	note:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -386)
	note:SetHeight(88)
	applyBackdrop(note, COLORS.sidebar, COLORS.border)

	local noteText = createText(note, "GameFontHighlightSmall", HTF.L.AUTO_ACTIONS_NOTICE, 11, COLORS.muted)
	noteText:SetPoint("TOPLEFT", 14, -13)
	noteText:SetPoint("TOPRIGHT", -14, -13)
	noteText:SetJustifyH("LEFT")
	noteText:SetJustifyV("TOP")
end

function Options:CreateStatSettingRow(parent, column, yOffset, key, label)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	anchorTwoColumnRow(row, parent, column, yOffset)
	row:SetHeight(29)
	applyBackdrop(row, COLORS.panel, COLORS.border)

	row.indicator = row:CreateTexture(nil, "ARTWORK")
	row.indicator:SetTexture("Interface\\Buttons\\WHITE8x8")
	row.indicator:SetSize(11, 11)
	row.indicator:SetPoint("LEFT", 10, 0)

	row.label = createText(row, "GameFontHighlightSmall", label, 11, COLORS.text)
	row.label:SetPoint("LEFT", row.indicator, "RIGHT", 8, 0)

	row.state = createText(row, "GameFontHighlightSmall", "", 10, COLORS.muted)
	row.state:SetPoint("RIGHT", row, "RIGHT", -43, 0)

	row.colorButton = CreateFrame("Button", nil, row, "BackdropTemplate")
	row.colorButton:SetSize(24, 17)
	row.colorButton:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	applyBackdrop(row.colorButton, COLORS.panelHover, COLORS.border)
	row.colorButton.swatch = row.colorButton:CreateTexture(nil, "ARTWORK")
	row.colorButton.swatch:SetPoint("TOPLEFT", 3, -3)
	row.colorButton.swatch:SetPoint("BOTTOMRIGHT", -3, 3)
	row.colorButton.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
	row.colorButton:SetScript("OnClick", function()
		self:OpenStatColorPicker(key)
	end)

	function row:Render(visible, r, g, b)
		self.colorButton.swatch:SetColorTexture(r, g, b, 1)
		if visible then
			self.indicator:SetColorTexture(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
			self.label:SetTextColor(r, g, b, 1)
			self.state:SetText(HTF.L.STAT_VISIBLE)
			self.state:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
		else
			self.indicator:SetColorTexture(COLORS.disabled[1], COLORS.disabled[2], COLORS.disabled[3], 1)
			self.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], COLORS.muted[4])
			self.state:SetText(HTF.L.STAT_HIDDEN)
			self.state:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], COLORS.muted[4])
		end
	end

	row:SetScript("OnEnter", function(self)
		self:SetBackdropColor(COLORS.panelHover[1], COLORS.panelHover[2], COLORS.panelHover[3], COLORS.panelHover[4])
	end)
	row:SetScript("OnLeave", function(self)
		self:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], COLORS.panel[4])
	end)
	row:SetScript("OnClick", function()
		HTF.Stats:SetStatVisible(key, not HTF.Stats:IsStatVisible(key))
	end)

	self.statSettingRows[key] = row
	return row
end

function Options:CreateStatsPage(page)
	self:AddPageHeader(page, HTF.L.CHARACTER_STATS, HTF.L.STATS_PAGE_HELP)
	self.statsDisplayToggleRow = self:CreateCompactToggleRow(page, "left", -84, "showStats", HTF.L.SHOW_STATS, HTF.L.SHOW_STATS_DESC)
	self.statsLockToggleRow = self:CreateCompactToggleRow(page, "right", -84, "statsLocked", HTF.L.LOCK_STATS, HTF.L.LOCK_STATS_DESC)

	local controlCard = CreateFrame("Frame", nil, page, "BackdropTemplate")
	controlCard:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -150)
	controlCard:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -150)
	controlCard:SetHeight(52)
	applyBackdrop(controlCard, COLORS.sidebar, COLORS.border)

	local fontLabel = createText(controlCard, "GameFontNormal", HTF.L.STATS_FONT_SIZE, 12, COLORS.text)
	fontLabel:SetPoint("LEFT", 13, 0)

	local minusButton = createActionButton(controlCard, "−")
	minusButton:SetSize(28, 26)
	minusButton:SetPoint("LEFT", fontLabel, "RIGHT", 12, 0)
	minusButton:SetScript("OnClick", function()
		HTF.Stats:SetFontSize(HTF.Stats:GetFontSize() - 1)
	end)

	self.statsFontValue = createText(controlCard, "GameFontNormal", "", 12, COLORS.accent)
	self.statsFontValue:SetPoint("LEFT", minusButton, "RIGHT", 10, 0)
	self.statsFontValue:SetWidth(24)
	self.statsFontValue:SetJustifyH("CENTER")

	local plusButton = createActionButton(controlCard, "+")
	plusButton:SetSize(28, 26)
	plusButton:SetPoint("LEFT", self.statsFontValue, "RIGHT", 10, 0)
	plusButton:SetScript("OnClick", function()
		HTF.Stats:SetFontSize(HTF.Stats:GetFontSize() + 1)
	end)

	local resetColorsButton = createActionButton(controlCard, HTF.L.STATS_RESET_COLORS)
	resetColorsButton:SetSize(96, 26)
	resetColorsButton:SetPoint("RIGHT", controlCard, "RIGHT", -12, 0)
	resetColorsButton:SetScript("OnClick", function()
		HTF.Stats:ResetColors()
	end)

	local resetPositionButton = createActionButton(controlCard, HTF.L.STATS_RESET_POSITION)
	resetPositionButton:SetSize(110, 26)
	resetPositionButton:SetPoint("RIGHT", resetColorsButton, "LEFT", -8, 0)
	resetPositionButton:SetScript("OnClick", function()
		HTF.Stats:ResetPosition()
	end)

	local listTitle = createText(page, "GameFontNormal", HTF.L.STATS_DISPLAY_ITEMS, 12, COLORS.text)
	listTitle:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -216)

	self.statSettingRows = {}
	for index, definition in ipairs(HTF.Stats.STAT_DEFINITIONS) do
		local column = index <= 7 and "left" or "right"
		local rowIndex = column == "left" and index or index - 7
		self:CreateStatSettingRow(page, column, -242 - (rowIndex - 1) * 34, definition.key, HTF.Stats:GetStatLabel(definition.key))
	end
end

function Options:CreateNameplatesPage(page)
	self:AddPageHeader(page, HTF.L.NAMEPLATES, HTF.L.NAMEPLATES_PAGE_HELP)
	self:CreateToggleRow(page, -96, "friendlyNamesOnly", HTF.L.FRIENDLY_NAMES_ONLY, HTF.L.FRIENDLY_NAMES_ONLY_DESC)

	local note = CreateFrame("Frame", nil, page, "BackdropTemplate")
	note:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -188)
	note:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -188)
	note:SetHeight(88)
	applyBackdrop(note, COLORS.sidebar, COLORS.border)

	local noteText = createText(note, "GameFontHighlightSmall", HTF.L.FRIENDLY_NAMES_ONLY_NOTICE, 11, COLORS.muted)
	noteText:SetPoint("TOPLEFT", 14, -13)
	noteText:SetPoint("TOPRIGHT", -14, -13)
	noteText:SetJustifyH("LEFT")
	noteText:SetJustifyV("TOP")
end

function Options:OpenStatColorPicker(key)
	if not HTF.Stats or type(ColorPickerFrame) ~= "table" or type(ColorPickerFrame.SetupColorPickerAndShow) ~= "function" then
		HTF:Notify(HTF.L.COLOR_PICKER_UNAVAILABLE)
		return
	end

	local originalR, originalG, originalB = HTF.Stats:GetStatColor(key)
	ColorPickerFrame:SetupColorPickerAndShow({
		r = originalR,
		g = originalG,
		b = originalB,
		hasOpacity = false,
		swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			HTF.Stats:SetStatColor(key, r, g, b)
		end,
		cancelFunc = function(previousValues)
			local r = type(previousValues) == "table" and previousValues.r or originalR
			local g = type(previousValues) == "table" and previousValues.g or originalG
			local b = type(previousValues) == "table" and previousValues.b or originalB
			HTF.Stats:SetStatColor(key, r, g, b)
		end,
	})
end

function Options:RefreshStatSettings()
	if not HTF.Stats then
		return
	end
	if self.statsFontValue then
		self.statsFontValue:SetText(tostring(HTF.Stats:GetFontSize()))
	end
	if self.statSettingRows then
		for key in pairs(self.statSettingRows) do
			self:RefreshStatSetting(key)
		end
	end
end

function Options:RefreshStatSetting(key)
	local row = self.statSettingRows and self.statSettingRows[key]
	if not row or not HTF.Stats then
		return
	end
	local r, g, b = HTF.Stats:GetStatColor(key)
	row:Render(HTF.Stats:IsStatVisible(key), r, g, b)
end

function Options:CreateDebugPage(page)
	local options = self
	self:AddPageHeader(page, HTF.L.DEBUG, HTF.L.DEBUG_PAGE_HELP)
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
	reportButton:SetSize(116, 28)
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
	local version = createText(sidebar, "GameFontHighlightSmall", string.format(HTF.L.VERSION_LABEL, HTF.VERSION), 10, COLORS.muted)
	version:SetPoint("TOPLEFT", tree, "BOTTOMLEFT", 0, -7)

	self:CreateNavigationButton(sidebar, "overview", HTF.L.OVERVIEW, -116)
	self:CreateNavigationButton(sidebar, "merchant", HTF.L.MERCHANT, -160)
	self:CreateNavigationButton(sidebar, "stats", HTF.L.CHARACTER_STATS, -204)
	self:CreateNavigationButton(sidebar, "nameplates", HTF.L.NAMEPLATES, -248)
	self:CreateNavigationButton(sidebar, "debug", HTF.L.DEBUG, -292)

	local sidebarHelp = createText(sidebar, "GameFontHighlightSmall", "/htf", 12, COLORS.accent)
	sidebarHelp:SetPoint("BOTTOMLEFT", 18, 23)
	local sidebarHint = createText(sidebar, "GameFontHighlightSmall", HTF.L.OPEN_SETTINGS, 10, COLORS.muted)
	sidebarHint:SetPoint("BOTTOMLEFT", sidebarHelp, "TOPLEFT", 0, 3)

	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
	content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

	for _, key in ipairs({ "overview", "merchant", "stats", "nameplates", "debug" }) do
		local page = CreateFrame("Frame", nil, content)
		page:SetAllPoints(content)
		page:Hide()
		self.pages[key] = page
	end

	self:CreateOverviewPage(self.pages.overview)
	self:CreateMerchantPage(self.pages.merchant)
	self:CreateStatsPage(self.pages.stats)
	self:CreateNameplatesPage(self.pages.nameplates)
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

	self:RefreshOverview()
	self:RefreshStatSettings()
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
			entry.row.value:SetText(HTF.L.STATUS_ENABLED)
			entry.row.value:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
		else
			entry.row.dot:SetColorTexture(COLORS.disabled[1], COLORS.disabled[2], COLORS.disabled[3], 1)
			entry.row.value:SetText(HTF.L.STATUS_DISABLED)
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
	self:RefreshStatSettings()
	self:RefreshDebugLog()
end

function Options:Open(page)
	if not self.panel then
		HTF:Notify(HTF.L.SETTINGS_UNAVAILABLE)
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
		HTF:Notify(HTF.L.DIAGNOSTIC_UNAVAILABLE)
		return
	end

	self:Open("debug")
	self:ShowDiagnosticReport()
end
