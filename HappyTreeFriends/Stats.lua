local _, HTF = ...

local Stats = {}
HTF.Stats = Stats

local primaryStats = {
	{ key = "strength", index = 1, fallback = "力量" },
	{ key = "agility", index = 2, fallback = "敏捷" },
	{ key = "stamina", index = 3, fallback = "耐力" },
	{ key = "intellect", index = 4, fallback = "智力" },
}

local function integerText(value)
	local rounded = math.floor(value + 0.5)
	if type(BreakUpLargeNumbers) == "function" then
		return BreakUpLargeNumbers(rounded)
	end
	return tostring(rounded)
end

local function percentText(value)
	return string.format("%.2f%%", value)
end

function Stats:GetDisplayedCritChance()
	if type(GetCritChance) ~= "function" then
		return nil
	end

	local displayedCrit = GetCritChance()
	if not HTF:IsSafeNumber(displayedCrit) then
		return nil
	end

	if type(GetRangedCritChance) == "function" then
		local rangedCrit = GetRangedCritChance()
		if not HTF:IsSafeNumber(rangedCrit) then
			return nil
		end
		if rangedCrit > displayedCrit then
			displayedCrit = rangedCrit
		end
	end

	if type(GetSpellCritChance) == "function" then
		local maximumSpellSchool = HTF:IsSafeNumber(MAX_SPELL_SCHOOLS) and MAX_SPELL_SCHOOLS or 7
		local spellCrit
		for schoolIndex = 2, maximumSpellSchool do
			local schoolCrit = GetSpellCritChance(schoolIndex)
			if not HTF:IsSafeNumber(schoolCrit) then
				return nil
			end
			if not spellCrit or schoolCrit < spellCrit then
				spellCrit = schoolCrit
			end
		end
		if spellCrit and spellCrit > displayedCrit then
			displayedCrit = spellCrit
		end
	end

	return displayedCrit
end

function Stats:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	self.eventFrame:RegisterEvent("UNIT_STATS")
	self.eventFrame:RegisterEvent("COMBAT_RATING_UPDATE")
	self.eventFrame:RegisterEvent("MASTERY_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.eventFrame:SetScript("OnEvent", function(_, event, unit)
		self:OnEvent(event, unit)
	end)
end

function Stats:OnEvent(event, unit)
	if event == "UNIT_STATS" and unit ~= "player" then
		return
	end

	if event == "PLAYER_REGEN_DISABLED" then
		self:ShowCombatRestriction()
		return
	end

	self:RequestRefresh()
end

function Stats:IsVisible()
	return HTF.Options and HTF.Options:IsPageVisible("stats")
end

function Stats:AttachView(view)
	self.view = view
	self:Refresh()
end

function Stats:RequestRefresh()
	if not self:IsVisible() or self.refreshQueued then
		return
	end

	self.refreshQueued = true
	local function refresh()
		self.refreshQueued = false
		self:Refresh()
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.05, refresh)
	else
		refresh()
	end
end

function Stats:AddValue(snapshot, key, label, value, formatter)
	if not HTF:IsSafeNumber(value) then
		snapshot[key] = { label = label, text = HTF.L.STAT_RESTRICTED, restricted = true }
		return true
	end

	snapshot[key] = { label = label, text = formatter(value), restricted = false }
	return false
end

function Stats:BuildSnapshot()
	local snapshot = {}
	local hasRestrictedValue = false

	for _, stat in ipairs(primaryStats) do
		local _, effectiveStat = UnitStat("player", stat.index)
		local label = _G["SPELL_STAT" .. stat.index .. "_NAME"] or stat.fallback
		if self:AddValue(snapshot, stat.key, label, effectiveStat, integerText) then
			hasRestrictedValue = true
		end
	end

	local _, effectiveArmor = UnitArmor("player")
	if self:AddValue(snapshot, "armor", _G.STAT_ARMOR or "护甲", effectiveArmor, integerText) then
		hasRestrictedValue = true
	end

	if self:AddValue(snapshot, "criticalStrike", _G.STAT_CRITICAL_STRIKE or "暴击", self:GetDisplayedCritChance(), percentText) then
		hasRestrictedValue = true
	end

	if self:AddValue(snapshot, "haste", _G.STAT_HASTE or "急速", GetHaste(), percentText) then
		hasRestrictedValue = true
	end

	local masteryEffect = GetMasteryEffect()
	if self:AddValue(snapshot, "mastery", _G.STAT_MASTERY or "精通", masteryEffect, percentText) then
		hasRestrictedValue = true
	end

	local versatilityBonus
	if type(GetCombatRatingBonus) == "function"
		and type(GetVersatilityBonus) == "function"
		and CR_VERSATILITY_DAMAGE_DONE then
		local ratingBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
		local effectBonus = GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
		if HTF:IsSafeNumber(ratingBonus) and HTF:IsSafeNumber(effectBonus) then
			versatilityBonus = ratingBonus + effectBonus
		end
	end
	if self:AddValue(snapshot, "versatility", _G.STAT_VERSATILITY or "全能", versatilityBonus, percentText) then
		hasRestrictedValue = true
	end

	if self:AddValue(snapshot, "lifesteal", _G.STAT_LIFESTEAL or "吸血", GetLifesteal(), percentText) then
		hasRestrictedValue = true
	end

	if self:AddValue(snapshot, "avoidance", _G.STAT_AVOIDANCE or "闪避", GetAvoidance(), percentText) then
		hasRestrictedValue = true
	end

	if self:AddValue(snapshot, "speed", _G.STAT_SPEED or "速度", GetSpeed(), percentText) then
		hasRestrictedValue = true
	end

	if self:AddValue(snapshot, "dodge", _G.DODGE or "躲闪", GetDodgeChance(), percentText) then
		hasRestrictedValue = true
	end

	if self:AddValue(snapshot, "parry", _G.PARRY or "招架", GetParryChance(), percentText) then
		hasRestrictedValue = true
	end

	return snapshot, hasRestrictedValue
end

function Stats:UpdateProfile()
	if not self.view or not self.view.profile then
		return
	end

	local name = HTF:SafeString(UnitName("player"), "—")
	local localizedClass = HTF:SafeString(UnitClass("player"), "")
	local level = UnitLevel("player")
	local levelText = HTF:IsSafeNumber(level) and tostring(level) or "—"
	local itemLevelText = "—"
	if type(GetAverageItemLevel) == "function" then
		-- 12.1 的第二返回值是已装备平均装等，与暴雪 PaperDollFrame 的显示口径一致。
		local _, equippedItemLevel = GetAverageItemLevel()
		if HTF:IsSafeNumber(equippedItemLevel) then
			itemLevelText = string.format("%.1f", equippedItemLevel)
		end
	end

	self.view.profile:SetText(string.format("%s  |cff8994a8%s · 等级 %s · 装等 %s|r", name, localizedClass, levelText, itemLevelText))
end

function Stats:RenderSnapshot(snapshot, hasRestrictedValue)
	if not self.view then
		return
	end

	for key, value in pairs(snapshot) do
		local row = self.view.rows[key]
		if row then
			row.label:SetText(value.label or row.defaultLabel)
			row.value:SetText(value.text or HTF.L.STAT_UNAVAILABLE)
			if value.restricted then
				row.value:SetTextColor(0.95, 0.72, 0.42)
			else
				row.value:SetTextColor(0.88, 0.94, 1.00)
			end
		end
	end

	self:UpdateProfile()
	local timestamp = date and date("%H:%M:%S") or "--:--:--"
	if hasRestrictedValue then
		self.view.status:SetText(HTF.L.STATS_PARTIALLY_RESTRICTED)
		self.view.status:SetTextColor(0.95, 0.72, 0.42)
	else
		self.view.status:SetText(string.format(HTF.L.STATS_UPDATED, timestamp))
		self.view.status:SetTextColor(0.43, 0.91, 0.72)
	end
end

function Stats:ShowCombatRestriction()
	if self.view and self:IsVisible() and HTF:GetSetting("showStats") then
		self.view.status:SetText(HTF.L.STATS_IN_COMBAT)
		self.view.status:SetTextColor(0.95, 0.72, 0.42)
	end
end

function Stats:ShowDisabledState()
	if not self.view then
		return
	end

	for _, row in pairs(self.view.rows) do
		row.value:SetText(HTF.L.STAT_UNAVAILABLE)
		row.value:SetTextColor(0.46, 0.51, 0.60)
	end
	self.view.status:SetText(HTF.L.STATS_DISABLED)
	self.view.status:SetTextColor(0.65, 0.69, 0.76)
end

function Stats:Refresh()
	if not self.view then
		return
	end
	if not self:IsVisible() then
		return
	end
	if not HTF:GetSetting("showStats") then
		self:ShowDisabledState()
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		self:ShowCombatRestriction()
		return
	end

	local snapshot, hasRestrictedValue = self:BuildSnapshot()
	self:RenderSnapshot(snapshot, hasRestrictedValue)
	HTF:Debug("角色属性已刷新。")
end
