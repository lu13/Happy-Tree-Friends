local _, HTF = ...

local Merchant = {}
HTF.Merchant = Merchant

function Merchant:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("MERCHANT_SHOW")
	self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.eventFrame:SetScript("OnEvent", function(_, event)
		self:OnEvent(event)
	end)
end

function Merchant:OnEvent(event)
	if event == "MERCHANT_CLOSED" then
		self.merchantOpen = false
		self.pendingRun = false
		self.runToken = (self.runToken or 0) + 1
		HTF:Debug("商人窗口已关闭。")
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		if self.merchantOpen and self.pendingRun then
			self.pendingRun = false
			HTF:Debug("已脱离战斗，补跑被延后的商人操作。")
			self:ScheduleRun(0)
		end
		return
	end

	self.merchantOpen = true
	self.pendingRun = false
	self.runToken = (self.runToken or 0) + 1
	HTF:Debug("检测到商人窗口，准备执行已启用的日常操作。")
	self:ScheduleRun(0.1)
end

function Merchant:ScheduleRun(delay)
	local token = self.runToken

	local function runWhenReady()
		if self.merchantOpen and token == self.runToken then
			self:RunMerchantActions()
		end
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(delay or 0, runWhenReady)
	else
		runWhenReady()
	end
end

function Merchant:TryAutoRepair()
	if type(CanMerchantRepair) ~= "function" or type(GetRepairAllCost) ~= "function" or type(RepairAllItems) ~= "function" then
		HTF:Debug("自动修理跳过：修理 API 不可用。")
		return nil
	end

	local merchantCanRepair = CanMerchantRepair()
	if HTF:IsSecretValue(merchantCanRepair) or not merchantCanRepair then
		HTF:Debug("自动修理跳过：当前商人不提供修理。")
		return nil
	end

	local repairCost, canRepair = GetRepairAllCost()
	if HTF:IsSecretValue(repairCost) or HTF:IsSecretValue(canRepair) then
		HTF:Debug("自动修理跳过：修理费用在当前场景受限。")
		return nil
	end
	if not canRepair or not HTF:IsSafeNumber(repairCost) or repairCost <= 0 then
		HTF:Debug("自动修理跳过：没有需要修理的装备。")
		return nil
	end

	local useGuild = false
	local guildAvailable = 0
	if HTF:GetSetting("repairFromGuild") then
		if type(CanGuildBankRepair) == "function" then
			local canGuildRepair = CanGuildBankRepair()
			if not HTF:IsSecretValue(canGuildRepair) and canGuildRepair then
				local withdrawAmount
				local bankAmount
				if type(GetGuildBankWithdrawMoney) == "function" then
					withdrawAmount = GetGuildBankWithdrawMoney()
				end
				if type(GetGuildBankMoney) == "function" then
					bankAmount = GetGuildBankMoney()
				end
				if HTF:IsSafeNumber(withdrawAmount) and HTF:IsSafeNumber(bankAmount) then
					if withdrawAmount == -1 then
						guildAvailable = math.max(0, bankAmount)
					else
						guildAvailable = math.max(0, math.min(withdrawAmount, bankAmount))
					end
					useGuild = guildAvailable > 0
					if not useGuild then
						HTF:Debug("公会修理回退：当前可用公会维修额度为 0，改用个人金币。")
					end
				else
					HTF:Debug("公会修理回退：公会维修额度当前不可读取，改用个人金币。")
				end
			else
				HTF:Debug("公会修理回退：角色当前没有公会维修权限，改用个人金币。")
			end
		else
			HTF:Debug("公会修理回退：公会维修权限 API 不可用，改用个人金币。")
		end
	end

	local personalNeeded = useGuild and math.max(0, repairCost - guildAvailable) or repairCost
	if personalNeeded > 0 then
		local money
		if type(GetMoney) == "function" then
			money = GetMoney()
		end
		if not HTF:IsSafeNumber(money) or money < personalNeeded then
			HTF:Debug("自动修理跳过：可用的公会维修额度与个人金币合计不足。")
			return false
		end
	end

	if useGuild then
		RepairAllItems(true)
		local source = guildAvailable >= repairCost and "guild" or "mixed"
		HTF:Debugf("已执行自动修理，费用：%s，资金来源：%s。", HTF:FormatMoney(repairCost), source == "guild" and "公会银行" or "公会银行 + 个人金币")
		return { cost = repairCost, source = source }
	end

	RepairAllItems()
	HTF:Debugf("已执行自动修理，费用：%s，资金来源：个人金币。", HTF:FormatMoney(repairCost))
	return { cost = repairCost, source = "personal" }
end

function Merchant:TryAutoSellJunk()
	if type(C_MerchantFrame) ~= "table"
		or type(C_MerchantFrame.GetNumJunkItems) ~= "function"
		or type(C_MerchantFrame.SellAllJunkItems) ~= "function" then
		HTF:Debug("自动售卖跳过：C_MerchantFrame API 不可用。")
		return nil
	end

	local junkCount = C_MerchantFrame.GetNumJunkItems()
	if not HTF:IsSafeNumber(junkCount) then
		HTF:Debug("自动售卖跳过：灰色物品数量在当前场景受限。")
		return nil
	end
	if junkCount <= 0 then
		HTF:Debug("自动售卖跳过：背包中没有可售卖的灰色物品。")
		return nil
	end

	C_MerchantFrame.SellAllJunkItems()
	HTF:Debugf("已调用 C_MerchantFrame.SellAllJunkItems，处理数量：%d。", junkCount)
	return junkCount
end

function Merchant:RunMerchantActions()
	if not self.merchantOpen then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		self.pendingRun = true
		HTF:Debug("商人操作跳过：战斗锁定中。")
		return
	end
	self.pendingRun = false

	local summary = {}
	if HTF:GetSetting("autoRepair") then
		local repairResult = self:TryAutoRepair()
		if repairResult == false then
			table.insert(summary, HTF.L.NOT_ENOUGH_MONEY)
		elseif repairResult then
			local message = HTF.L.REPAIRED_PERSONAL
			if repairResult.source == "guild" then
				message = HTF.L.REPAIRED_GUILD
			elseif repairResult.source == "mixed" then
				message = HTF.L.REPAIRED_MIXED
			end
			table.insert(summary, string.format(message, HTF:FormatMoney(repairResult.cost)))
		end
	end

	if HTF:GetSetting("autoSellJunk") then
		local junkCount = self:TryAutoSellJunk()
		if junkCount then
			table.insert(summary, string.format(HTF.L.SOLD_JUNK, junkCount))
		end
	end

	if #summary > 0 and HTF:GetSetting("showNotifications") then
		HTF:Notify(table.concat(summary, " |cff697386·|r "))
	end
end
