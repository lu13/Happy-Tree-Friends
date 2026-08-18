local _, HTF = ...

local Merchant = {}
HTF.Merchant = Merchant

Merchant.MAX_LEDGER_SKIPPED_ITEMS = 6

local function isPositiveInteger(value)
	return HTF:IsSafeNumber(value) and value > 0 and value == math.floor(value)
end

function Merchant:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self:NormalizeSettings()
	self:ResetSessionLedger()
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("MERCHANT_SHOW")
	self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.eventFrame:SetScript("OnEvent", function(_, event)
		self:OnEvent(event)
	end)
end

function Merchant:NormalizeSettings()
	if not HTF.db then
		return
	end

	local normalized = {}
	if type(HTF.db.protectedJunkItems) == "table" then
		for rawItemID, enabled in pairs(HTF.db.protectedJunkItems) do
			local itemID = tonumber(rawItemID)
			if isPositiveInteger(itemID) and enabled == true then
				normalized[itemID] = true
			end
		end
	end

	HTF.db.protectedJunkItems = normalized
	self.protectedJunkItems = normalized
end

function Merchant:ResetSessionLedger()
	self.sessionLedger = {
		repairTotal = 0,
		repairPersonal = 0,
		repairGuild = 0,
		junkItemsSold = 0,
		junkIncome = 0,
		junkIncomeKnown = true,
		skippedItems = {},
		skippedItemOrder = {},
		skippedOverflow = 0,
	}
	self:RefreshLedger()
end

function Merchant:GetSessionLedger()
	if not self.sessionLedger then
		self:ResetSessionLedger()
	end
	return self.sessionLedger
end

function Merchant:RefreshLedger()
	if HTF.Options and HTF.Options.RefreshMerchantLedger then
		HTF.Options:RefreshMerchantLedger()
	end
end

function Merchant:GetProtectedJunkItemCount()
	local count = 0
	for _ in pairs(self.protectedJunkItems or {}) do
		count = count + 1
	end
	return count
end

function Merchant:GetProtectedJunkItemIDs()
	local itemIDs = {}
	for itemID in pairs(self.protectedJunkItems or {}) do
		table.insert(itemIDs, itemID)
	end
	table.sort(itemIDs)
	return itemIDs
end

function Merchant:IsJunkItemProtected(itemID)
	return isPositiveInteger(itemID) and self.protectedJunkItems and self.protectedJunkItems[itemID] == true
end

function Merchant:SetJunkItemProtected(itemID, protected)
	if not isPositiveInteger(itemID) or not HTF.db then
		return false
	end

	if not self.protectedJunkItems then
		self:NormalizeSettings()
	end
	if protected then
		self.protectedJunkItems[itemID] = true
	else
		self.protectedJunkItems[itemID] = nil
	end
	HTF.db.protectedJunkItems = self.protectedJunkItems
	self:RefreshLedger()
	return true
end

function Merchant:ExtractItemID(value)
	if type(value) ~= "string" then
		return nil
	end

	local rawItemID = value:match("item:(%d+)") or value:match("^%s*(%d+)%s*$")
	local itemID = tonumber(rawItemID)
	return isPositiveInteger(itemID) and itemID or nil
end

function Merchant:GetItemStackCount(item)
	local count = item and item.stackCount
	if HTF:IsSafeNumber(count) and count > 0 then
		return math.max(1, math.floor(count))
	end
	return 1
end

function Merchant:GetItemDisplayText(item)
	local hyperlink = item and HTF:SafeString(item.hyperlink)
	if hyperlink and hyperlink ~= "" then
		return hyperlink
	end

	local itemID = item and item.itemID
	if isPositiveInteger(itemID) then
		local name
		if type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function" then
			name = C_Item.GetItemInfo(itemID)
		elseif type(GetItemInfo) == "function" then
			name = GetItemInfo(itemID)
		end
		name = HTF:SafeString(name)
		if name ~= "" then
			return name
		end
		return "#" .. tostring(itemID)
	end

	return HTF.L.LEDGER_UNKNOWN_ITEM
end

function Merchant:GetItemSellPrice(item)
	local itemID = item and item.itemID
	if not isPositiveInteger(itemID) then
		return nil
	end

	local sellPrice
	if type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function" then
		local _, _, _, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(itemID)
		sellPrice = price
	elseif type(GetItemInfo) == "function" then
		local _, _, _, _, _, _, _, _, _, _, price = GetItemInfo(itemID)
		sellPrice = price
	end

	if HTF:IsSafeNumber(sellPrice) and sellPrice >= 0 then
		return sellPrice
	end
	return nil
end

function Merchant:RecordRepair(result)
	if type(result) ~= "table" or not HTF:IsSafeNumber(result.cost) or result.cost <= 0 then
		return
	end

	local ledger = self:GetSessionLedger()
	local guildCost = HTF:IsSafeNumber(result.guildCost) and math.max(0, result.guildCost) or 0
	local personalCost = HTF:IsSafeNumber(result.personalCost) and math.max(0, result.personalCost) or 0
	ledger.repairTotal = ledger.repairTotal + result.cost
	ledger.repairGuild = ledger.repairGuild + guildCost
	ledger.repairPersonal = ledger.repairPersonal + personalCost
	self:RefreshLedger()
end

function Merchant:RecordSkippedItem(item)
	local itemID = item and item.itemID
	if not isPositiveInteger(itemID) then
		return
	end

	local ledger = self:GetSessionLedger()
	local count = self:GetItemStackCount(item)
	local key = tostring(itemID)
	local existing = ledger.skippedItems[key]
	if existing then
		existing.count = existing.count + count
		return
	end

	if #ledger.skippedItemOrder >= self.MAX_LEDGER_SKIPPED_ITEMS then
		ledger.skippedOverflow = ledger.skippedOverflow + count
		return
	end

	ledger.skippedItems[key] = {
		text = self:GetItemDisplayText(item),
		count = count,
	}
	table.insert(ledger.skippedItemOrder, key)
end

function Merchant:RecordSkippedItems(items)
	if type(items) ~= "table" or #items == 0 then
		return
	end

	for _, item in ipairs(items) do
		self:RecordSkippedItem(item)
	end
	self:RefreshLedger()
end

function Merchant:RecordJunkSale(result)
	if type(result) ~= "table" or not HTF:IsSafeNumber(result.count) or result.count <= 0 then
		return
	end

	local ledger = self:GetSessionLedger()
	ledger.junkItemsSold = ledger.junkItemsSold + result.count
	if result.valueKnown and HTF:IsSafeNumber(result.value) and result.value >= 0 then
		ledger.junkIncome = ledger.junkIncome + result.value
	else
		ledger.junkIncomeKnown = false
	end
	self:RefreshLedger()
end

function Merchant:GetSessionLedgerText()
	local ledger = self:GetSessionLedger()
	local lines = {}
	local repairTotal = HTF:FormatMoney(ledger.repairTotal)
	local personal = HTF:FormatMoney(ledger.repairPersonal)
	local guild = HTF:FormatMoney(ledger.repairGuild)
	table.insert(lines, string.format(HTF.L.LEDGER_REPAIR_TOTAL, repairTotal, personal, guild))

	local income = ledger.junkIncomeKnown and HTF:FormatMoney(ledger.junkIncome) or HTF.L.LEDGER_VALUE_UNAVAILABLE
	table.insert(lines, string.format(HTF.L.LEDGER_JUNK_TOTAL, ledger.junkItemsSold, income))

	if #ledger.skippedItemOrder == 0 then
		table.insert(lines, HTF.L.LEDGER_SKIPPED_EMPTY)
	else
		table.insert(lines, HTF.L.LEDGER_SKIPPED_TITLE)
		for _, key in ipairs(ledger.skippedItemOrder) do
			local item = ledger.skippedItems[key]
			if item then
				table.insert(lines, string.format(HTF.L.LEDGER_SKIPPED_ITEM, item.text, item.count))
			end
		end
		if ledger.skippedOverflow > 0 then
			table.insert(lines, string.format(HTF.L.LEDGER_SKIPPED_MORE, ledger.skippedOverflow))
		end
	end

	return table.concat(lines, "\n")
end

function Merchant:CollectJunkItems()
	if type(C_Container) ~= "table"
		or type(C_Container.GetContainerNumSlots) ~= "function"
		or type(C_Container.GetContainerItemInfo) ~= "function" then
		return nil
	end

	local firstBag = HTF:IsSafeNumber(BACKPACK_CONTAINER) and BACKPACK_CONTAINER or 0
	local lastBag = HTF:IsSafeNumber(NUM_BAG_SLOTS) and NUM_BAG_SLOTS or 4
	local result = {
		sellable = {},
		protected = {},
		count = 0,
		value = 0,
		valueKnown = true,
	}

	for bag = firstBag, lastBag do
		local slots = C_Container.GetContainerNumSlots(bag)
		if not HTF:IsSafeNumber(slots) then
			return nil
		end
		for slot = math.floor(slots), 1, -1 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if type(info) == "table" then
				local itemID = info.itemID
				local quality = info.quality
				local hasNoValue = info.hasNoValue
				if isPositiveInteger(itemID)
					and HTF:IsSafeNumber(quality)
					and quality == 0
					and not HTF:IsSecretValue(hasNoValue)
					and hasNoValue ~= true then
					local item = {
						bag = bag,
						slot = slot,
						itemID = itemID,
						stackCount = info.stackCount,
						hyperlink = HTF:SafeString(info.hyperlink),
					}
					local count = self:GetItemStackCount(item)
					if self:IsJunkItemProtected(itemID) then
						table.insert(result.protected, item)
					else
						table.insert(result.sellable, item)
						result.count = result.count + count
						local sellPrice = self:GetItemSellPrice(item)
						if sellPrice then
							result.value = result.value + sellPrice * count
						else
							result.valueKnown = false
						end
					end
				end
			end
		end
	end

	return result
end

function Merchant:CanUseNativeJunkSale()
	return type(C_MerchantFrame) == "table"
		and type(C_MerchantFrame.GetNumJunkItems) == "function"
		and type(C_MerchantFrame.SellAllJunkItems) == "function"
end

function Merchant:SellJunkItemsIndividually(items)
	if type(C_Container) ~= "table" or type(C_Container.UseContainerItem) ~= "function" then
		return false
	end

	for _, item in ipairs(items) do
		C_Container.UseContainerItem(item.bag, item.slot)
	end
	return true
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

	local result = {
		cost = repairCost,
		guildCost = useGuild and math.min(guildAvailable, repairCost) or 0,
		personalCost = personalNeeded,
	}
	if useGuild then
		RepairAllItems(true)
		result.source = guildAvailable >= repairCost and "guild" or "mixed"
		local sourceLabel = result.source == "guild" and HTF.L.DEBUG_SOURCE_GUILD or HTF.L.DEBUG_SOURCE_MIXED
		HTF:Debugf(HTF.L.DEBUG_REPAIR_COMPLETED, HTF:FormatMoney(repairCost), sourceLabel)
	else
		RepairAllItems()
		result.source = "personal"
		HTF:Debugf(HTF.L.DEBUG_REPAIR_COMPLETED, HTF:FormatMoney(repairCost), HTF.L.DEBUG_SOURCE_PERSONAL)
	end

	self:RecordRepair(result)
	return result
end

function Merchant:TryAutoSellJunk()
	local scan = self:CollectJunkItems()
	if not scan then
		if self:GetProtectedJunkItemCount() > 0 then
			HTF:Debug(HTF.L.DEBUG_JUNK_PROTECTION_SCAN_UNAVAILABLE)
			return nil
		end
		if not self:CanUseNativeJunkSale() then
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
		local fallbackResult = { count = junkCount, value = 0, valueKnown = false }
		self:RecordJunkSale(fallbackResult)
		HTF:Debugf(HTF.L.DEBUG_JUNK_SOLD, junkCount)
		return fallbackResult
	end

	self:RecordSkippedItems(scan.protected)
	if scan.count <= 0 then
		HTF:Debug(HTF.L.DEBUG_JUNK_EMPTY)
		return { count = 0, value = 0, valueKnown = true }
	end

	local sold = false
	if self:GetProtectedJunkItemCount() > 0 then
		sold = self:SellJunkItemsIndividually(scan.sellable)
	else
		if self:CanUseNativeJunkSale() then
			C_MerchantFrame.SellAllJunkItems()
			sold = true
		else
			sold = self:SellJunkItemsIndividually(scan.sellable)
		end
	end
	if not sold then
		HTF:Debug(HTF.L.DEBUG_JUNK_API_UNAVAILABLE)
		return nil
	end

	local result = {
		count = scan.count,
		value = scan.value,
		valueKnown = scan.valueKnown,
	}
	self:RecordJunkSale(result)
	HTF:Debugf(HTF.L.DEBUG_JUNK_SOLD, result.count)
	return result
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
		local junkResult = self:TryAutoSellJunk()
		if junkResult and junkResult.count > 0 then
			table.insert(summary, string.format(HTF.L.SOLD_JUNK, junkResult.count))
		end
	end

	if #summary > 0 and HTF:GetSetting("showNotifications") then
		HTF:Notify(table.concat(summary, " |cff697386·|r "))
	end
end
