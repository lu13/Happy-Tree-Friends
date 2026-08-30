local _, HTF = ...

local RaidDebuffs = {}
HTF.RaidDebuffs = RaidDebuffs

RaidDebuffs.DEFAULT_ICON_SIZE = 12
RaidDebuffs.MIN_ICON_SIZE = 8
RaidDebuffs.MAX_ICON_SIZE = 24
RaidDebuffs.ICON_SPACING = 1
RaidDebuffs.MAX_PER_CATEGORY = 2
RaidDebuffs.MAX_OFFSET = 40
RaidDebuffs.MAX_SHORT_OTHER_DURATION = 60
RaidDebuffs.ICONS_PER_ROW = 4

RaidDebuffs.GROUPS = {
	{
		key = "bleed",
		settingKey = "raidDebuffsShowBleed",
		filterString = "HARMFUL|!RAID",
		candidateFilters = {
			includeDispelTypes = { Bleed = true },
			isBossAura = false,
			isRoleAura = false,
			isPriorityAura = false,
		},
	},
	{
		key = "crowdControl",
		settingKey = "raidDebuffsShowCrowdControl",
		filterString = "HARMFUL|!RAID|CROWD_CONTROL",
		candidateFilters = {
			excludeDispelTypes = { Bleed = true },
			isBossAura = false,
			isRoleAura = false,
			isPriorityAura = false,
		},
	},
	{
		key = "raidInCombat",
		settingKey = "raidDebuffsShowRaidInCombat",
		filterString = "HARMFUL|!RAID|RAID_IN_COMBAT|!CROWD_CONTROL",
		candidateFilters = {
			excludeDispelTypes = { Bleed = true },
			isBossAura = false,
			isRoleAura = false,
			isPriorityAura = false,
		},
	},
	{
		key = "shortOther",
		settingKey = "raidDebuffsShowShortOther",
		filterString = "HARMFUL|!RAID|!CROWD_CONTROL|!RAID_IN_COMBAT",
		candidateFilters = {
			excludeDispelTypes = { Bleed = true },
			isBossAura = false,
			isRoleAura = false,
			isPriorityAura = false,
			maxDuration = RaidDebuffs.MAX_SHORT_OTHER_DURATION,
		},
	},
}

RaidDebuffs.SETTING_KEYS = {
	raidDebuffsEnabled = true,
	raidDebuffsShowBleed = true,
	raidDebuffsShowCrowdControl = true,
	raidDebuffsShowRaidInCombat = true,
	raidDebuffsShowShortOther = true,
	raidDebuffsIconSize = true,
	raidDebuffsAnchor = true,
	raidDebuffsOffsetX = true,
	raidDebuffsOffsetY = true,
}

RaidDebuffs.ANCHORS = {
	TOPLEFT = {
		horizontal = "Right",
		vertical = "Down",
	},
	TOPRIGHT = {
		horizontal = "Left",
		vertical = "Down",
	},
	BOTTOMLEFT = {
		horizontal = "Right",
		vertical = "Up",
	},
	BOTTOMRIGHT = {
		horizontal = "Left",
		vertical = "Up",
	},
}

local function isCombatLocked()
	if type(InCombatLockdown) ~= "function" then
		return false
	end

	local locked = InCombatLockdown()
	if HTF:IsSecretValue(locked) then
		return true
	end
	return locked == true
end

local function clampOffset(value, fallback)
	if not HTF:IsSafeNumber(value) then
		return fallback
	end
	return math.max(-RaidDebuffs.MAX_OFFSET, math.min(RaidDebuffs.MAX_OFFSET, math.floor(value + 0.5)))
end

local function clampIconSize(value)
	if not HTF:IsSafeNumber(value) then
		return RaidDebuffs.DEFAULT_ICON_SIZE
	end
	return math.max(RaidDebuffs.MIN_ICON_SIZE, math.min(RaidDebuffs.MAX_ICON_SIZE, math.floor(value + 0.5)))
end

function RaidDebuffs:InitializeAuraButton(button)
	local iconSize = self:GetIconSize()
	button:SetSize(iconSize, iconSize)
	button:SetMouseClickEnabled(false)
	button:SetMouseMotionEnabled(true)
	button:SetHideTooltipInCombat(false)
	button:SetTooltipAnchorPoint("ANCHOR_RIGHT")

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button:SetIcon(icon)

	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button)
	cooldown:SetDrawEdge(false)
	cooldown:SetReverse(true)
	cooldown:SetHideCountdownNumbers(true)
	button:SetDurationCooldown(cooldown)

	local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
	button:SetApplicationCount(count)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
	button:SetAuraBorder(border)
end

function RaidDebuffs:IsSupportedUnit(unit)
	if HTF:IsSecretValue(unit) or type(unit) ~= "string" then
		return false
	end
	if unit == "player" then
		return true
	end

	local partyIndex = tonumber(unit:match("^party(%d+)$"))
	if partyIndex then
		return partyIndex >= 1 and partyIndex <= 4
	end

	local raidIndex = tonumber(unit:match("^raid(%d+)$"))
	return raidIndex ~= nil and raidIndex >= 1 and raidIndex <= 40
end

function RaidDebuffs:IsBlizzardCompactFrame(frame)
	if not frame or type(frame.GetParent) ~= "function" then
		return false
	end

	local parent = frame:GetParent()
	if parent and parent == _G.CompactPartyFrame then
		return true
	end
	if parent and parent == _G.CompactRaidFrameContainer then
		return true
	end

	local grandParent = parent and type(parent.GetParent) == "function" and parent:GetParent() or nil
	if grandParent ~= _G.CompactRaidFrameContainer then
		return false
	end

	local parentName = type(parent.GetName) == "function" and parent:GetName() or nil
	return type(parentName) == "string" and parentName:match("^CompactRaidGroup%d+$") ~= nil
end

function RaidDebuffs:GetFrameUnit(frame)
	if not frame then
		return nil
	end

	local unit = frame.displayedUnit
	if HTF:IsSecretValue(unit) then
		return nil
	end
	if type(unit) ~= "string" or unit == "" then
		unit = frame.unit
	end
	return self:IsSupportedUnit(unit) and unit or nil
end

function RaidDebuffs:GetAnchor()
	local anchor = HTF:GetSetting("raidDebuffsAnchor")
	return self.ANCHORS[anchor] and anchor or "BOTTOMRIGHT"
end

function RaidDebuffs:GetOffsetX()
	return clampOffset(HTF:GetSetting("raidDebuffsOffsetX"), -2)
end

function RaidDebuffs:GetOffsetY()
	return clampOffset(HTF:GetSetting("raidDebuffsOffsetY"), 2)
end

function RaidDebuffs:GetIconSize()
	return clampIconSize(HTF:GetSetting("raidDebuffsIconSize"))
end

function RaidDebuffs:SetAnchor(anchor)
	if not self.ANCHORS[anchor] then
		return false
	end
	HTF:SetSetting("raidDebuffsAnchor", anchor)
	return true
end

function RaidDebuffs:SetOffset(axis, value)
	local settingKey = axis == "x" and "raidDebuffsOffsetX" or axis == "y" and "raidDebuffsOffsetY" or nil
	if not settingKey then
		return false
	end
	HTF:SetSetting(settingKey, clampOffset(value, axis == "x" and -2 or 2))
	return true
end

function RaidDebuffs:AdjustOffset(axis, delta)
	if not HTF:IsSafeNumber(delta) then
		return false
	end
	local current = axis == "x" and self:GetOffsetX() or axis == "y" and self:GetOffsetY() or nil
	if current == nil then
		return false
	end
	return self:SetOffset(axis, current + delta)
end

function RaidDebuffs:SetIconSize(value)
	if not HTF:IsSafeNumber(value) then
		return false
	end
	HTF:SetSetting("raidDebuffsIconSize", clampIconSize(value))
	return true
end

function RaidDebuffs:AdjustIconSize(delta)
	if not HTF:IsSafeNumber(delta) then
		return false
	end
	return self:SetIconSize(self:GetIconSize() + delta)
end

function RaidDebuffs:ResetPosition()
	if not HTF.db then
		return
	end
	HTF.db.raidDebuffsAnchor = "BOTTOMRIGHT"
	HTF.db.raidDebuffsOffsetX = -2
	HTF.db.raidDebuffsOffsetY = 2
	self:OnSettingChanged("raidDebuffsAnchor")
	if HTF.Options and HTF.Options.Refresh then
		HTF.Options:Refresh()
	end
end

function RaidDebuffs:ConfigureContainerLayout(container)
	local anchor = self:GetAnchor()
	local layout = self.ANCHORS[anchor]
	local horizontal = AnchorUtil.FlowDirection[layout.horizontal]
	local vertical = AnchorUtil.FlowDirection[layout.vertical]

	container:ClearAllPoints()
	container:SetPoint(anchor, container:GetParent(), anchor, self:GetOffsetX(), self:GetOffsetY())
	container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
	container:SetFlowLayoutAnchorPoint(anchor)
	container:SetFlowLayoutGrowthDirection(horizontal, vertical)
	container:SetFlowLayoutPadding(0, 0, 0, 0)
	local iconSize = self:GetIconSize()
	container:SetFlowLayoutMaximumLineSize((iconSize * self.ICONS_PER_ROW) + (self.ICON_SPACING * (self.ICONS_PER_ROW - 1)))
end

function RaidDebuffs:GetGroupLayout(layoutIndex)
	local iconSize = self:GetIconSize()
	return {
		elementSpacing = self.ICON_SPACING,
		lineSpacing = self.ICON_SPACING,
		groupSpacing = 0,
		groupLineSpacing = self.ICON_SPACING,
		elementWidth = iconSize,
		elementHeight = iconSize,
		layoutIndex = layoutIndex,
	}
end

function RaidDebuffs:ConfigureIconSize(container)
	local iconSize = self:GetIconSize()
	for index, definition in ipairs(self.GROUPS) do
		container:SetAuraGroupLayout(definition.key, self:GetGroupLayout(index))
		local frameCount = container:GetAuraGroupFrameCount(definition.key)
		for frameIndex = 1, frameCount do
			local button = container:GetAuraGroupFrame(definition.key, frameIndex)
			if button then
				button:SetSize(iconSize, iconSize)
			end
		end
	end
end

function RaidDebuffs:ConfigureCategoryVisibility(container)
	for _, definition in ipairs(self.GROUPS) do
		local maximum = HTF:GetSetting(definition.settingKey) == true and self.MAX_PER_CATEGORY or 0
		container:SetAuraGroupMaxFrameCount(definition.key, maximum)
	end
end

function RaidDebuffs:CreateContainer(frame, unit)
	local container
	local ok, result = pcall(function()
		container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
		self:ConfigureContainerLayout(container)

		for index, definition in ipairs(self.GROUPS) do
			container:AddAuraGroup(definition.key, definition.filterString, {
				maxFrameCount = HTF:GetSetting(definition.settingKey) == true and self.MAX_PER_CATEGORY or 0,
				candidateFilters = definition.candidateFilters,
				initializeFrame = function(button)
					self:InitializeAuraButton(button)
				end,
				layout = self:GetGroupLayout(index),
			})
		end

		container:SetUnit(unit)
		container:SetEnabled(true)
		container:Show()
		return container
	end)

	if not ok or not result then
		self.creationFailed = true
		if container then
			pcall(function()
				container:SetEnabled(false)
				container:Hide()
			end)
		end
		HTF:Debugf(HTF.L.DEBUG_RAID_DEBUFFS_UNAVAILABLE, HTF:SafeScalarText(result))
		if not self.unavailableNotified then
			self.unavailableNotified = true
			HTF:Notify(HTF.L.RAID_DEBUFFS_UNAVAILABLE)
		end
		return nil
	end

	container = result
	self.containers[frame] = container
	HTF:Debugf(HTF.L.DEBUG_RAID_DEBUFFS_ATTACHED, unit)
	return container
end

function RaidDebuffs:SynchronizeFrame(frame, allowCreation)
	if not self:IsBlizzardCompactFrame(frame) then
		return false
	end

	local container = self.containers[frame]
	local unit = self:GetFrameUnit(frame)
	if HTF:GetSetting("raidDebuffsEnabled") ~= true or not unit then
		if container then
			container:SetEnabled(false)
			container:Hide()
		end
		return false
	end

	if not container then
		if not allowCreation or isCombatLocked() or self.creationFailed then
			self.pendingApply = true
			return false
		end
		container = self:CreateContainer(frame, unit)
		return container ~= nil
	end

	if container:GetUnit() ~= unit then
		container:SetUnit(unit)
	end
	container:SetEnabled(true)
	container:Show()
	return true
end

function RaidDebuffs:OnCompactUnitFrameUpdated(frame)
	if HTF:GetSetting("raidDebuffsEnabled") ~= true and not self.containers[frame] then
		return
	end
	local combatLocked = isCombatLocked()
	if combatLocked and HTF:GetSetting("raidDebuffsEnabled") ~= true then
		self.pendingApply = true
		return
	end
	self:SynchronizeFrame(frame, not combatLocked)
end

function RaidDebuffs:RefreshKnownFrames()
	if HTF:GetSetting("raidDebuffsEnabled") ~= true then
		return
	end

	local partyFrame = _G.CompactPartyFrame
	if partyFrame and type(partyFrame.memberUnitFrames) == "table" then
		for _, frame in ipairs(partyFrame.memberUnitFrames) do
			self:SynchronizeFrame(frame, true)
		end
	end

	local raidContainer = _G.CompactRaidFrameContainer
	if raidContainer and type(raidContainer.ApplyToFrames) == "function" then
		raidContainer:ApplyToFrames("normal", function(frame)
			self:SynchronizeFrame(frame, true)
		end)
	end
end

function RaidDebuffs:ApplySettings(notifyPending)
	if isCombatLocked() then
		local wasPending = self.pendingApply == true
		self.pendingApply = true
		if notifyPending and not self.pendingNotified then
			self.pendingNotified = true
			HTF:Notify(HTF.L.RAID_DEBUFFS_APPLY_PENDING)
		end
		if not wasPending then
			HTF:Debug(HTF.L.DEBUG_RAID_DEBUFFS_DEFERRED)
		end
		return false
	end

	local enabled = HTF:GetSetting("raidDebuffsEnabled") == true
	if enabled then
		self:RefreshKnownFrames()
	end

	for frame, container in pairs(self.containers) do
		if container then
			if enabled and self:GetFrameUnit(frame) then
				self:ConfigureContainerLayout(container)
				self:ConfigureIconSize(container)
				self:ConfigureCategoryVisibility(container)
				self:SynchronizeFrame(frame, false)
			else
				container:SetEnabled(false)
				container:Hide()
			end
		end
	end

	self.pendingApply = false
	self.pendingNotified = false
	return true
end

function RaidDebuffs:OnSettingChanged(key)
	if not self.SETTING_KEYS[key] then
		return
	end
	self:ApplySettings(true)
end

function RaidDebuffs:GetContainer(frame)
	return self.containers and self.containers[frame] or nil
end

function RaidDebuffs:GetTrackedFrameCount()
	local count = 0
	for _frame, container in pairs(self.containers or {}) do
		if container then
			count = count + 1
		end
	end
	return count
end

function RaidDebuffs:IsAvailable()
	return not self.creationFailed
		and type(CreateFrame) == "function"
		and type(hooksecurefunc) == "function"
		and type(CompactUnitFrame_UpdateAll) == "function"
		and type(AnchorUtil) == "table"
		and type(AnchorUtil.FlowLayoutAxis) == "table"
		and type(AnchorUtil.FlowDirection) == "table"
end

function RaidDebuffs:OnEvent(event, loadedAddon)
	if event == "PLAYER_REGEN_ENABLED" then
		if self.pendingApply then
			if self:ApplySettings(false) then
				HTF:Debug(HTF.L.DEBUG_RAID_DEBUFFS_APPLIED)
			end
		end
	elseif event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE" then
		if HTF:GetSetting("raidDebuffsEnabled") == true then
			self:ApplySettings(false)
		end
	elseif event == "ADDON_LOADED" and loadedAddon == "Blizzard_CompactRaidFrames" then
		if HTF:GetSetting("raidDebuffsEnabled") == true then
			self:ApplySettings(false)
		end
	end
end

function RaidDebuffs:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self.containers = setmetatable({}, { __mode = "k" })
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	self.eventFrame:RegisterEvent("ADDON_LOADED")
	self.eventFrame:SetScript("OnEvent", function(_, event, ...)
		self:OnEvent(event, ...)
	end)

	if self:IsAvailable() then
		hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
			self:OnCompactUnitFrameUpdated(frame)
		end)
	else
		self.creationFailed = true
	end

	if HTF:GetSetting("raidDebuffsEnabled") == true then
		self:ApplySettings(false)
	end
end
