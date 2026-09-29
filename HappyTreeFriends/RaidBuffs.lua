local _, HTF = ...

-- Loaded immediately after RaidDebuffs, before either module is initialized.
-- Copy the implementation so runtime state and settings remain independent.
local RaidBuffs = {}
for key, value in pairs(HTF.RaidDebuffs) do
	RaidBuffs[key] = value
end
HTF.RaidBuffs = RaidBuffs

RaidBuffs.settingPrefix = "raidBuffs"
RaidBuffs.noticePrefix = "RAID_BUFFS"
RaidBuffs.defaultAnchor = "TOPLEFT"
RaidBuffs.defaultOffsetX = 2
RaidBuffs.defaultOffsetY = -2
RaidBuffs.DEFAULT_ICON_SIZE = 18
RaidBuffs.highlightColor = { 1, 0.82, 0.2 }
RaidBuffs.GROUPS = {
	{
		key = "beaconOfVirtue",
		settingKey = "raidBuffsEnabled",
		filterString = "HELPFUL|PLAYER",
		candidateFilters = { includeSpellIDs = { [200025] = true } },
	},
}
RaidBuffs.MAX_PER_CATEGORY = 1
RaidBuffs.SETTING_KEYS = {}
for _, suffix in ipairs({ "Enabled", "Anchor", "OffsetX", "OffsetY", "IconSize", "Highlight", "Countdown" }) do
	RaidBuffs.SETTING_KEYS["raidBuffs" .. suffix] = true
end
