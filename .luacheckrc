-- luacheck configuration for ArcUI (WoW retail addon, Lua 5.1 / WoW API)

std = "lua51"
max_line_length = false

-- Third-party libraries are not ours — don't report issues there.
exclude_files = {
    "Libs/",
}

-- Allow setting globals at file top level (WoW addon load-order pattern).
allow_defined_top = true

-- Silence common WoW addon patterns that are not real defects.
ignore = {
    "212",  -- unused argument (self in WoW frame methods / event handlers)
    "213",  -- unused argument (event name in generic handlers)
    "542",  -- empty block (common in stub/placeholder frames)
}

-- WoW globals that luacheck doesn't know about.
-- read_globals: we read but do not define these ourselves.
read_globals = {
    -- Core WoW API
    "C_Timer",
    "C_Spell",
    "C_Traits",
    "C_UnitAuras",
    "C_Item",
    "C_Container",
    "C_CooldownSystem",
    "C_TooltipInfo",
    "C_Texture",
    "C_ActionBar",
    "C_NewItems",

    -- Unit / player
    "UnitAura",
    "UnitAuraSlots",
    "UnitBuff",
    "UnitDebuff",
    "UnitIsUnit",
    "UnitExists",
    "UnitClass",
    "UnitRace",
    "UnitName",
    "UnitGUID",
    "UnitHealth",
    "UnitHealthMax",
    "UnitPower",
    "UnitPowerMax",
    "UnitPowerType",
    "UnitIsPlayer",
    "UnitInVehicle",

    -- Spell / cooldown
    "GetSpellInfo",
    "GetSpellTexture",
    "GetSpellCooldown",
    "GetSpellCharges",
    "GetSpellBaseCooldown",
    "FindSpellOverrideByID",
    "IsSpellKnown",
    "IsSpellKnownOrOverridesKnown",
    "GetSpecialization",
    "GetSpecializationInfo",
    "GetActiveSpecGroup",
    "GetTalentInfoByID",
    "GetNumTalentTabs",
    "GetNumTalents",

    -- Inventory / item
    "GetInventoryItemID",
    "GetInventoryItemTexture",
    "GetInventoryItemCooldown",
    "GetItemInfo",
    "GetItemCooldown",
    "GetContainerItemCooldown",
    "GetContainerNumSlots",
    "GetContainerItemInfo",
    "PickupInventoryItem",
    "EquipItemByName",

    -- UI / Frame
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "GameFont_Huge1",
    "DEFAULT_CHAT_FRAME",
    "FCFManager_GetCurrentChatFrame",
    "InterfaceOptions_AddCategory",
    "IsAddOnLoaded",

    -- Minimap / data broker
    "Minimap",
    "MinimapCluster",

    -- AceAddon / LibStub (loaded via Libs/)
    "LibStub",

    -- String/math/table WoW extensions
    "format",
    "tinsert",
    "tremove",
    "tContains",
    "wipe",
    "strsplit",
    "strtrim",
    "strfind",
    "strmatch",
    "strupper",
    "strlower",
    "strsub",
    "strlen",
    "strrep",
    "strbyte",
    "strchar",
    "strrev",
    "tostring",
    "tonumber",
    "type",
    "pairs",
    "ipairs",
    "next",
    "select",
    "unpack",
    "table",
    "math",
    "string",
    "error",
    "assert",
    "pcall",
    "xpcall",
    "rawget",
    "rawset",
    "rawequal",
    "setmetatable",
    "getmetatable",
    "print",

    -- WoW enums / constants
    "BOOKTYPE_SPELL",
    "COMBATLOG_OBJECT_TYPE_PLAYER",
    "NUM_BAG_SLOTS",
    "NUM_INVENTORY_SLOTS",
    "Enum",
    "LE_UNIT_STAT_STRENGTH",
    "LE_UNIT_STAT_AGILITY",
    "LE_UNIT_STAT_INTELLECT",

    -- AuraUtil (Blizzard helper)
    "AuraUtil",

    -- Combat / event helpers
    "CombatLogGetCurrentEventInfo",
    "GetTime",
    "GetServerTime",
    "UnitGUID",
    "InCombatLockdown",
    "IsInInstance",
    "IsInGroup",
    "IsInRaid",

    -- Slash / binding globals are set by our code (listed in globals below).

    -- Texture / sound
    "PlaySoundFile",
    "PlaySound",
    "StopSound",
}

-- globals: we define these ourselves (WoW pattern globals).
globals = {
    "SlashCmdList",
    "SLASH_ARCBARS1",
    "SLASH_ARCBARS2",

    -- Functions set as globals by Core (called by external code / CDM hooks).
    "ForceHideCDMFrame",
    "ClearBarState",
    "UpdateBarBuffInfo",
    "UpdateAllBars",
}
