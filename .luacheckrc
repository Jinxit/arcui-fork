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
  "111",  -- setting globals is normal for slash commands and addon namespaces
  "112",  -- mutating global tables is normal for WoW UI mixins/namespaces
  "212",  -- unused argument 'self' — normal in OOP callbacks
  "213",  -- unused loop variable — e.g. 'for k, _ in pairs(...)'
  "211",  -- existing unused locals in upstream addon code
  "221",  -- existing locals intentionally read through WoW-side state
  "231",  -- existing assigned values kept for debugging/instrumentation
  "241",  -- existing mutated values kept for debugging/instrumentation
  "311",  -- existing overwritten assignments in upstream addon code
  "314",  -- existing overwritten values in upstream addon code
  "411",  -- existing repeated local names in large option modules
  "412",  -- existing repeated argument names in callbacks
  "421",  -- existing shadowed local names in callbacks
  "431",  -- existing shadowed upvalues in callbacks
  "432",  -- existing shadowed callback arguments
  "511",  -- existing unreachable fallback branches
  "512",  -- existing single-pass loops used as structured early-exit blocks
  "542",  -- empty if branch — guard stubs common during dev
  "581",  -- existing negated condition style in upstream addon code
  "611",  -- line contains only whitespace
  "612",  -- existing trailing whitespace in upstream addon code
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
  "SLASH_ARCUIFC1",
  "SLASH_CRDEBUG1",
  "SLASH_ARCUIIMPORTSTATUS1",
  "SLASH_ARCINTEGRATION1",
  "SLASH_ARCUIPLACEHOLDER1",
  "SLASH_ARCUICDMSTATE1",
  "ArcUIDB",
  "ArcUI_CDMEnhance_Debug",
  "ArcUI_DB",
  "ArcUI_DEBUG_MASQUE",
  "ArcUI_NS",

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
  "UnitAffectingCombat",
  "UnitIsDeadOrGhost",
  "UnitIsPVP",
  "UnitIsPVPFreeForAll",
  "UnitOnTaxi",
  "UnitPowerBarID",
  "UnitPowerPercent",
  "UnitStagger",

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
  "C_Spell",
  "C_SpellActivationOverlay",
  "C_SpellBook",
  "CastSpellByName",
  "GetActionInfo",
  "GetActionTexture",
  "GetHaste",
  "GetMacroItem",
  "GetMacroSpell",
  "GetPowerRegenForPowerType",
  "GetRuneCooldown",
  "GetTotemDuration",
  "GetTotemInfo",
  "GetNumTotemSlots",
  "GetUnitChargedPowerPoints",
  "GetUnitEmpowerHoldAtMaxTime",
  "GetUnitEmpowerStageDuration",
  "HasAction",
  "UnitCastingInfo",
  "UnitChannelInfo",

  -- Talent / trait API
  "GetSpecialization",
  "GetSpecializationInfo",
  "GetActiveSpecGroup",
  "C_ClassTalents",
  "C_Traits",
  "C_SpecializationInfo",
  "GetClassInfo",
  "GetNumSpecializations",
  "GetNumSpecializationsForClassID",
  "GetSpecializationInfoForClassID",

  -- Aura utils
  "AuraUtil",
  "C_UnitAuras",

  -- Item API
  "GetItemInfo",
  "GetItemIcon",
  "GetItemCount",
  "GetContainerItemCooldown",
  "GetInventoryItemCooldown",
  "GetInventoryItemID",
  "GetInventoryItemTexture",
  "GetItemInfoInstant",
  "GetItemSpell",
  "IsEquippableItem",
  "IsEquippedItem",
  "C_Item",
  "Item",
  "C_Container",
  "C_PetBattles",

  -- Timer / scheduler
  "C_Timer",
  "C_StringUtil",
  "GetTime",
  "debugprofilestop",
  "date",
  "debugstack",
  "time",

  -- Minimap / LDB
  "Minimap",

  -- Tooltip
  "GameTooltip",
  "GameTooltipTextLeft1",
  "GameTooltip_Hide",
  "TooltipDataProcessor",
  "C_TooltipInfo",

  -- UI widgets
  "UIParent",
  "WorldFrame",
  "InterfaceOptionsFrame",
  "InterfaceOptionsFramePanelContainer",
  "SlashCmdList",
  "UISpecialFrames",
  "ColorPickerFrame",
  "CreateColor",
  "CreateTexturePool",
  "CreateVector2D",
  "GameFontNormal",
  "ChatFontNormal",
  "GetCursorPosition",
  "GetMouseFoci",
  "GetMouseFocus",
  "GetPhysicalScreenSize",
  "GetScreenHeight",
  "GetScreenWidth",
  "IsMouseButtonDown",
  "IsShiftKeyDown",
  "MenuUtil",
  "Mixin",
  "NineSliceUtil",
  "PixelUtil",
  "STANDARD_TEXT_FONT",
  "Settings",
  "SearchBoxTemplate_OnTextChanged",
  "ToggleEditModeManager",
  "UIDropDownMenu_AddButton",
  "UIDropDownMenu_CreateInfo",
  "UIDropDownMenu_Initialize",
  "UIDropDownMenu_SetText",
  "UIDropDownMenu_SetWidth",

  -- Cooldown frame
  "CooldownFrame_Set",
  "CooldownFrame_Clear",
  "AbbreviateNumbers",
  "PlayerCastingBarFrame",
  "ActionButtonSpellAlertManager",
  "AssistedCombatManager",
  "C_ActionBar",
  "C_AssistedCombat",
  "C_CooldownViewer",
  "C_CurveUtil",
  "C_DurationUtil",
  "C_Texture",
  "CooldownManagerLayout_GetName",
  "CooldownViewerConstants",
  "CooldownViewerDataProvider",
  "CooldownViewerItemDataMixin",
  "CooldownViewerMixin",
  "CooldownViewerSettings",
  "CooldownViewerVisualAlertsManager",
  "CurveConstants",
  "PullFrameBackToSlot",
  "SetupChargeText",
  "SetupCooldownText",

  -- Blizzard event constants
  "COMBATLOG_OBJECT_TYPE_PLAYER",
  "COMBATLOG_OBJECT_REACTION_HOSTILE",
  "COMBATLOG_OBJECT_AFFILIATION_OUTSIDER",
  "Constants",
  "Enum",

  -- String / format helpers in WoW
  "format",
  "strsplit",
  "strjoin",
  "strtrim",
  "tContains",
  "tinsert",
  "tremove",
  "wipe",
  "CopyTable",
  "DeepCopy",
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
  "max",

  -- WoW-specific globals used by ArcUI
  "AceGUIWidgetLSMlists",
  "BINDING_HEADER_ARCUI",
  "DEFAULT_CHAT_FRAME",
  "StaticPopupDialogs",
  "StaticPopup_Show",
  "FCF_GetCurrentChatFrame",
  "C_AddOns",
  "C_CombatAudioAlert",
  "C_CreatureInfo",
  "C_EncodingUtil",
  "C_RestrictedActions",
  "C_TTSSettings",
  "C_VoiceChat",
  "ElvUI",
  "GetAddOnMetadata",
  "GetBindingKey",
  "GetBonusBarIndex",
  "GetBonusBarOffset",
  "GetBuildInfo",
  "GetCVarBool",
  "GetInstanceInfo",
  "GetNetStats",
  "GetNumShapeshiftForms",
  "GetRealmName",
  "GetShapeshiftForm",
  "GetShapeshiftFormID",
  "GetShapeshiftFormInfo",
  "IsInInstance",
  "IsInGroup",
  "IsInRaid",
  "GetNumGroupMembers",
  "InCombatLockdown",
  "IsMounted",
  "IsFlying",
  "IsResting",
  "IsStealthed",
  "IsSwimming",
  "UnitLevel",
  "UnitEffectiveLevel",
  "GetPlayerFacing",
  "PlaySound",
  "PlaySoundFile",
  "SOUNDKIT",
  "RAID_CLASS_COLORS",
  "ReloadUI",
  "SendChatMessage",
  "SetCVar",
  "SetDesaturation",
  "StopSound",
  "TextToSpeech_GetSelectedVoice",
  "arg2",
  "hasanysecretvalues",
  "hooksecurefunc",
  "importedProfileName",
  "interp",
  "isGCDTracker",
  "issecretvalue",
  "ok",

  -- Secure frame API
  "SecureHandlerWrapScript",
  "RegisterAttributeDriver",
  "UnregisterAttributeDriver",

  -- Edit mode
  "EditModeManagerFrame",
  "C_EditMode",
  "EventRegistry",

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
  "LE_PARTY_CATEGORY_INSTANCE",
  "MAX_ACCOUNT_MACROS",
  "MAX_CHARACTER_MACROS",

  -- Macro API / upstream kick assist helpers
  "CreateMacro",
  "EditMacro",
  "GetMacroIndexByName",
  "GetMacroInfo",
  "GetNumMacros",
  "PickupMacro",
  "KickAssist_Show",
  "KickAssist_ShowMacroEditor",

  -- Wowless-only (CI test guard)
  "WowlessData",
}
