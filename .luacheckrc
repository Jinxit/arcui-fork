-- luacheck configuration for ArcUI
-- WoW addons run Lua 5.1; use that standard.
std = "lua51"
max_line_length = false

-- Third-party libraries — not our code, skip.
exclude_files = {
  "Libs/",
  ".luacheckrc",
}

-- Warnings to suppress for standard WoW addon patterns.
ignore = {
  "212",  -- unused argument 'self' — normal in OOP callbacks
  "213",  -- unused loop variable — e.g. 'for k, _ in pairs(...)'
  "542",  -- empty if branch — guard stubs common during dev
  "611",  -- line contains only whitespace
  "614",  -- trailing whitespace
}

-- WoW API globals and commonly used Blizzard/Ace3 symbols.
-- This list covers what ArcUI and the Ace3 suite actually use.
globals = {
  -- Addon loading
  "LibStub",
  "AceLibrary",

  -- Lua 5.1 compat shims present in WoW
  "table.wipe",
  "table.move",
  "string.trim",
  "bit",
  "bit.band",
  "bit.bor",
  "bit.bxor",
  "bit.bnot",
  "bit.lshift",
  "bit.rshift",

  -- WoW global namespace
  "SLASH_ARCUI1",
  "SLASH_ARCUI2",

  -- Frame creation / management
  "CreateFrame",
  "CreateFontString",

  -- Unit queries
  "UnitGUID",
  "UnitName",
  "UnitClass",
  "UnitHealth",
  "UnitHealthMax",
  "UnitPower",
  "UnitPowerMax",
  "UnitPowerType",
  "UnitAura",
  "UnitBuff",
  "UnitDebuff",
  "UnitExists",
  "UnitIsUnit",
  "UnitIsDead",
  "UnitIsGhost",
  "UnitIsPlayer",
  "UnitIsEnemy",
  "UnitCanAttack",
  "UnitInParty",
  "UnitInRaid",
  "UnitInVehicle",
  "UnitHasVehiclePlayerFrameUI",

  -- Spell / cooldown API
  "GetSpellInfo",
  "GetSpellCooldown",
  "GetSpellCharges",
  "GetSpellTexture",
  "GetSpellBaseCooldown",
  "GetSpellCount",
  "FindSpellOverrideByID",
  "IsSpellKnown",
  "IsSpellKnownOrOverridesKnown",
  "IsPlayerSpell",
  "IsUsableSpell",

  -- Talent / trait API
  "GetSpecialization",
  "GetSpecializationInfo",
  "GetActiveSpecGroup",
  "C_ClassTalents",
  "C_Traits",
  "C_SpecializationInfo",

  -- Aura utils
  "AuraUtil",
  "C_UnitAuras",

  -- Item API
  "GetItemInfo",
  "GetItemIcon",
  "GetItemCount",
  "GetContainerItemCooldown",
  "C_Item",

  -- Timer / scheduler
  "C_Timer",
  "GetTime",
  "debugprofilestop",

  -- Minimap / LDB
  "Minimap",

  -- Tooltip
  "GameTooltip",
  "GameTooltipTextLeft1",

  -- UI widgets
  "UIParent",
  "WorldFrame",
  "InterfaceOptionsFrame",
  "InterfaceOptionsFramePanelContainer",
  "SlashCmdList",

  -- Cooldown frame
  "CooldownFrame_Set",
  "CooldownFrame_Clear",

  -- Blizzard event constants
  "COMBATLOG_OBJECT_TYPE_PLAYER",
  "COMBATLOG_OBJECT_REACTION_HOSTILE",
  "COMBATLOG_OBJECT_AFFILIATION_OUTSIDER",

  -- String / format helpers in WoW
  "format",
  "strsplit",
  "strjoin",
  "strtrim",
  "tContains",
  "tinsert",
  "tremove",
  "wipe",
  "pairs",
  "ipairs",
  "next",
  "select",
  "unpack",
  "print",
  "error",
  "assert",
  "pcall",
  "xpcall",
  "type",
  "tostring",
  "tonumber",
  "setmetatable",
  "getmetatable",
  "rawget",
  "rawset",
  "rawequal",
  "math",
  "string",
  "table",

  -- WoW-specific globals used by ArcUI
  "BINDING_HEADER_ARCUI",
  "DEFAULT_CHAT_FRAME",
  "StaticPopupDialogs",
  "StaticPopup_Show",
  "FCF_GetCurrentChatFrame",
  "IsInInstance",
  "IsInGroup",
  "IsInRaid",
  "GetNumGroupMembers",
  "InCombatLockdown",
  "IsMounted",
  "IsFlying",
  "UnitLevel",
  "UnitEffectiveLevel",
  "GetPlayerFacing",

  -- Secure frame API
  "SecureHandlerWrapScript",
  "RegisterAttributeDriver",
  "UnregisterAttributeDriver",

  -- Edit mode
  "EditModeManagerFrame",
  "C_EditMode",

  -- WoW data tables
  "PowerBarColor",
  "POWER_TYPE_MANA",
  "POWER_TYPE_RAGE",
  "POWER_TYPE_FOCUS",
  "POWER_TYPE_ENERGY",
  "POWER_TYPE_COMBO_POINTS",
  "POWER_TYPE_RUNES",
  "POWER_TYPE_RUNIC_POWER",
  "POWER_TYPE_SOUL_SHARDS",
  "POWER_TYPE_LUNAR_POWER",
  "POWER_TYPE_HOLY_POWER",
  "POWER_TYPE_MAELSTROM",
  "POWER_TYPE_CHI",
  "POWER_TYPE_INSANITY",
  "POWER_TYPE_FURY",
  "POWER_TYPE_PAIN",
  "POWER_TYPE_ESSENCE",
  "NUM_STANCE_SLOTS",
  "BOOKTYPE_SPELL",

  -- Wowless-only (CI test guard)
  "WowlessData",
}
