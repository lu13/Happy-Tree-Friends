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
		HTF:Debug(HTF.L.DEBUG_MERCHANT_CLOSED)
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		if self.merchantOpen and self.pendingRun then
			self.pendingRun = false
			HTF:Debug(HTF.L.DEBUG_MERCHANT_RESUMED)
			self:ScheduleRun(0)
		end
		return
	end

	self.merchantOpen = true
	self.pendingRun = false
	self.runToken = (self.runToken or 0) + 1
	HTF:Debug(HTF.L.DEBUG_MERCHANT_OPENED)
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
		HTF:Debug(HTF.L.DEBUG_REPAIR_API_UNAVAILABLE)
		return nil
	end

	local merchantCanRepair = CanMerchantRepair()
	if HTF:IsSecretValue(merchantCanRepair) or not merchantCanRepair then
		HTF:Debug(HTF.L.DEBUG_REPAIR_UNSUPPORTED)
		return nil
	end

	local repairCost, canRepair = GetRepairAllCost()
	if HTF:IsSecretValue(repairCost) or HTF:IsSecretValue(canRepair) then
		HTF:Debug(HTF.L.DEBUG_REPAIR_COST_RESTRICTED)
		return nil
	end
	if not canRepair or not HTF:IsSafeNumber(repairCost) or repairCost <= 0 then
		HTF:Debug(HTF.L.DEBUG_REPAIR_NOT_NEEDED)
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
						HTF:Debug(HTF.L.DEBUG_GUILD_FUNDS_EMPTY)
					end
				else
					HTF:Debug(HTF.L.DEBUG_GUILD_FUNDS_RESTRICTED)
				end
			else
				HTF:Debug(HTF.L.DEBUG_GUILD_PERMISSION_DENIED)
			end
		else
			HTF:Debug(HTF.L.DEBUG_GUILD_PERMISSION_API_UNAVAILABLE)
		end
	end

	local personalNeeded = useGuild and math.max(0, repairCost - guildAvailable) or repairCost
	if personalNeeded > 0 then
		local money
		if type(GetMoney) == "function" then
			money = GetMoney()
		end
		if not HTF:IsSafeNumber(money) or money < personalNeeded then
			HTF:Debug(HTF.L.DEBUG_REPAIR_INSUFFICIENT_FUNDS)
			return false
		end
	end

	if useGuild then
		RepairAllItems(true)
		local source = guildAvailable >= repairCost and "guild" or "mixed"
		local sourceLabel = source == "guild" and HTF.L.DEBUG_SOURCE_GUILD or HTF.L.DEBUG_SOURCE_MIXED
		HTF:Debugf(HTF.L.DEBUG_REPAIR_COMPLETED, HTF:FormatMoney(repairCost), sourceLabel)
		return { cost = repairCost, source = source }
	end

	RepairAllItems()
	HTF:Debugf(HTF.L.DEBUG_REPAIR_COMPLETED, HTF:FormatMoney(repairCost), HTF.L.DEBUG_SOURCE_PERSONAL)
	return { cost = repairCost, source = "personal" }
end

function Merchant:TryAutoSellJunk()
	if type(C_MerchantFrame) ~= "table"
		or type(C_MerchantFrame.GetNumJunkItems) ~= "function"
		or type(C_MerchantFrame.SellAllJunkItems) ~= "function" then
		HTF:Debug(HTF.L.DEBUG_JUNK_API_UNAVAILABLE)
		return nil
	end

	local junkCount = C_MerchantFrame.GetNumJunkItems()
	if not HTF:IsSafeNumber(junkCount) then
		HTF:Debug(HTF.L.DEBUG_JUNK_COUNT_RESTRICTED)
		return nil
	end
	if junkCount <= 0 then
		HTF:Debug(HTF.L.DEBUG_JUNK_EMPTY)
		return nil
	end

	C_MerchantFrame.SellAllJunkItems()
	HTF:Debugf(HTF.L.DEBUG_JUNK_SOLD, junkCount)
	return junkCount
end

function Merchant:RunMerchantActions()
	if not self.merchantOpen then
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		self.pendingRun = true
		HTF:Debug(HTF.L.DEBUG_MERCHANT_COMBAT_LOCKED)
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
