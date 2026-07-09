-- ===================================================================
-- [FORK] ArcUI_TrackerAnchors.lua
-- Tracker-to-tracker icon anchoring (issue #40)
--
-- Allows buff-bar icons and arc aura icons to be anchored on top of
-- other icon trackers (buff bar icons, arc auras, CDM cooldown icons).
-- CDM icons are target-only because they are Blizzard secure frames.
--
-- Anchor strategy:
--   source:SetFrameStrata(targetStrata)            -- match, not boost
--   source:SetFrameLevel(targetLevel + subOffset + LEVEL_HEADROOM)
-- where subOffset covers the highest sub-frame on the target and
-- LEVEL_HEADROOM = 5 puts the source clearly above it.
--
-- Position: SafeAnchor (screen-coordinate passthrough) so the CDM icon
-- target is never touched, preventing taint.
-- ===================================================================

local ADDON_NAME, ns = ...

ns.TrackerAnchors = ns.TrackerAnchors or {}
local TA = ns.TrackerAnchors

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════

local LEVEL_HEADROOM = 5

-- How many levels above the base the topmost child sits per target kind.
-- Source ends up at targetBase + subOffset + LEVEL_HEADROOM.
local SUB_OFFSET = {
    buffBarIcon = 10,  -- trackingFailOverlay at base+10 (HIGH strata so won't conflict)
    arcAura     = 10,  -- FRAME_LEVEL_COUNT = 10
    cdmIcon     =  5,  -- Blizzard child levels are small
}

local MAX_CHAIN_DEPTH = 4

-- ═══════════════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════════════

-- [sourceKey] = { sourceFrame, anchorCfg }
-- sourceKey = kind .. "|" .. tostring(key)
local activeSources = {}

-- Frames we've already hooked with OnShow/OnHide to avoid double-hooking
local hookedTargetFrames = {}

-- Re-entry guard when our own SetPoint triggers a hook
local isApplying = false

-- ═══════════════════════════════════════════════════════════════════════════
-- RESOLVER
-- ═══════════════════════════════════════════════════════════════════════════

--- Returns (frame, subOffset) for the given tracker kind and key.
--- Returns (nil, 0) when the target doesn't exist or isn't available yet.
function TA.Resolve(kind, key)
    if not kind or kind == "" or not key or key == "" then return nil, 0 end
    local sub = SUB_OFFSET[kind] or 0

    if kind == "buffBarIcon" then
        local frame = _G["ArcUIIconFrame" .. tostring(key)]
        return frame, sub

    elseif kind == "arcAura" then
        if ns.ArcAuras and ns.ArcAuras.GetFrame then
            return ns.ArcAuras.GetFrame(tostring(key)), sub
        end
        return nil, sub

    elseif kind == "cdmIcon" then
        if ns.CDMEnhance and ns.CDMEnhance.GetEnhancedFrames then
            local frames = ns.CDMEnhance.GetEnhancedFrames()
            local numKey = tonumber(key)
            local data = numKey and frames[numKey]
            if data and (data.viewerType == "cooldown" or data.viewerType == "utility") then
                return data.frame, sub
            end
        end
        return nil, sub
    end

    return nil, 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CYCLE DETECTION
-- Walks the anchor chain up to MAX_CHAIN_DEPTH steps.
-- Returns true if sourceKind/sourceKey appears as a target anywhere in chain.
-- ═══════════════════════════════════════════════════════════════════════════
local function WalkCycleCheck(sourceKind, sourceKey, curKind, curKey, depth)
    if depth >= MAX_CHAIN_DEPTH then return true end
    if curKind == sourceKind and tostring(curKey) == tostring(sourceKey) then
        return true
    end
    -- Follow the next hop only for non-CDM targets (CDM icons can't be sources)
    if curKind == "buffBarIcon" then
        local barNum = tonumber(curKey)
        local barConfig = barNum and ns.API and ns.API.GetBarConfig and ns.API.GetBarConfig(barNum)
        if barConfig and barConfig.display and barConfig.display.anchorToTracker then
            return WalkCycleCheck(sourceKind, sourceKey,
                barConfig.display.anchorTargetKind, barConfig.display.anchorTargetKey, depth + 1)
        end
    elseif curKind == "arcAura" then
        if ns.ArcAuras and ns.ArcAuras.GetAnchorConfig then
            local cfg = ns.ArcAuras.GetAnchorConfig(tostring(curKey))
            if cfg and cfg.anchorToTracker then
                return WalkCycleCheck(sourceKind, sourceKey,
                    cfg.anchorTargetKind, cfg.anchorTargetKey, depth + 1)
            end
        end
    end
    return false
end

function TA.HasCycle(sourceKind, sourceKey, targetKind, targetKey)
    return WalkCycleCheck(sourceKind, sourceKey, targetKind, targetKey, 0)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- APPLY: Anchor sourceFrame according to anchorCfg.
-- Returns true when it handled positioning (caller should skip normal path).
-- ═══════════════════════════════════════════════════════════════════════════
function TA.Apply(sourceFrame, anchorCfg)
    if not sourceFrame or not anchorCfg then return false end
    if not anchorCfg.anchorToTracker then return false end

    local targetKind = anchorCfg.anchorTargetKind
    local targetKey  = anchorCfg.anchorTargetKey
    if not targetKind or targetKind == "" or not targetKey or targetKey == "" then
        return false
    end

    local targetFrame, subOffset = TA.Resolve(targetKind, targetKey)

    if not targetFrame or not targetFrame:IsShown() then
        -- Target missing or invisible — hide source until it returns
        sourceFrame:Hide()
        sourceFrame._trackerAnchorHidden = true
        return true
    end

    -- Target exists; clear the hidden-by-anchor flag so normal
    -- update logic can re-show the source on the next cycle.
    sourceFrame._trackerAnchorHidden = nil

    -- Match strata; boost level so we sit above target's top child.
    local targetStrata = targetFrame:GetFrameStrata()
    local targetLevel  = targetFrame:GetFrameLevel() + subOffset
    sourceFrame:SetFrameStrata(targetStrata)
    sourceFrame:SetFrameLevel(targetLevel + LEVEL_HEADROOM)

    -- Position via SafeAnchor (breaks taint chain for CDM secure targets).
    local srcPoint  = anchorCfg.anchorSourcePoint or "CENTER"
    local dstPoint  = anchorCfg.anchorTargetPoint or "CENTER"
    local offsetX   = anchorCfg.anchorOffsetX or 0
    local offsetY   = anchorCfg.anchorOffsetY or 0

    local SafeAnchor = ns.CDMGroupsAnchors and ns.CDMGroupsAnchors.SafeAnchor
    local anchored = SafeAnchor and SafeAnchor(sourceFrame, srcPoint, targetFrame, dstPoint, offsetX, offsetY)

    if not anchored then
        -- Fallback direct anchor (safe for insecure targets out of combat).
        if InCombatLockdown() and targetFrame.IsProtected and targetFrame:IsProtected() then
            sourceFrame:Hide()
            sourceFrame._trackerAnchorHidden = true
            return true
        end
        sourceFrame:ClearAllPoints()
        sourceFrame:SetPoint(srcPoint, targetFrame, dstPoint, offsetX, offsetY)
    end

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REGISTER SOURCE: Remember a source frame so ReapplyAll can update it.
-- Called by Display.lua (buff bar icon) and ArcAuras.LoadFramePosition.
-- ═══════════════════════════════════════════════════════════════════════════
function TA.RegisterSource(kind, key, sourceFrame, anchorCfg)
    local sourceKey = kind .. "|" .. tostring(key)
    activeSources[sourceKey] = { kind = kind, key = key, frame = sourceFrame, cfg = anchorCfg }

    -- Hook target visibility so source hides/re-shows when target appears/disappears.
    local targetFrame = TA.Resolve(anchorCfg.anchorTargetKind, anchorCfg.anchorTargetKey)
    if targetFrame then
        TA.HookTarget(targetFrame, sourceFrame, anchorCfg)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UNREGISTER SOURCE: Remove source from tracking (e.g., anchor disabled).
-- ═══════════════════════════════════════════════════════════════════════════
function TA.UnregisterSource(kind, key)
    local sourceKey = kind .. "|" .. tostring(key)
    activeSources[sourceKey] = nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOK TARGET: Watch target frame visibility changes.
-- One hook per (targetFrame, sourceFrame) pair — guards against re-hooking.
-- ═══════════════════════════════════════════════════════════════════════════
function TA.HookTarget(targetFrame, sourceFrame, anchorCfg)
    if not targetFrame or not sourceFrame then return end

    -- Key by both frames to allow multiple sources watching the same target.
    local hookKey = tostring(targetFrame) .. "|" .. tostring(sourceFrame)
    if hookedTargetFrames[hookKey] then return end
    hookedTargetFrames[hookKey] = true

    targetFrame:HookScript("OnShow", function()
        if isApplying then return end
        isApplying = true
        if sourceFrame and sourceFrame:GetParent() then  -- still alive
            TA.Apply(sourceFrame, anchorCfg)
            -- If the source was hidden by us, let normal tracker logic re-show it.
            -- We only position/strata here; visibility is the tracker's job.
        end
        isApplying = false
    end)

    targetFrame:HookScript("OnHide", function()
        if isApplying then return end
        isApplying = true
        if sourceFrame and sourceFrame:GetParent() then
            TA.Apply(sourceFrame, anchorCfg)
        end
        isApplying = false
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REAPPLY ALL: Refresh all known anchored sources.
-- Called after combat, vehicle, edit-mode events, and spec switch.
-- ═══════════════════════════════════════════════════════════════════════════
function TA.ReapplyAll()
    if isApplying then return end
    isApplying = true

    -- Iterate buff-bar icon sources via the DB (handles frames not yet registered).
    local db = ns.API and ns.API.GetDB and ns.API.GetDB()
    if db and db.bars then
        for barNumber, barConfig in pairs(db.bars) do
            if barConfig and barConfig.display and barConfig.display.anchorToTracker then
                local iconFrame = _G["ArcUIIconFrame" .. tostring(barNumber)]
                if iconFrame then
                    TA.Apply(iconFrame, barConfig.display)
                    local targetFrame = TA.Resolve(
                        barConfig.display.anchorTargetKind, barConfig.display.anchorTargetKey)
                    if targetFrame then
                        TA.HookTarget(targetFrame, iconFrame, barConfig.display)
                    end
                end
            end
        end
    end

    -- Iterate arc aura sources.
    if ns.ArcAuras and ns.ArcAuras.GetDB then
        local arcDB = ns.ArcAuras.GetDB()
        if arcDB and arcDB.anchorConfigs then
            for arcID, anchorCfg in pairs(arcDB.anchorConfigs) do
                if anchorCfg and anchorCfg.anchorToTracker then
                    local frame = ns.ArcAuras.GetFrame and ns.ArcAuras.GetFrame(arcID)
                    if frame then
                        TA.Apply(frame, anchorCfg)
                        local targetFrame = TA.Resolve(
                            anchorCfg.anchorTargetKind, anchorCfg.anchorTargetKey)
                        if targetFrame then
                            TA.HookTarget(targetFrame, frame, anchorCfg)
                        end
                    end
                end
            end
        end
    end

    isApplying = false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RESET HOOK STATE: Call before spec/profile switch so hooks re-run cleanly.
-- ═══════════════════════════════════════════════════════════════════════════
function TA.ResetAllHookState()
    wipe(hookedTargetFrames)
    wipe(activeSources)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TARGET PICKER HELPERS: Build values tables for the options UI dropdowns.
-- ═══════════════════════════════════════════════════════════════════════════

--- Returns { key = label } for all available icon targets.
--- excludeKind/excludeKey: the source itself (prevents self-selection).
function TA.BuildTargetValues(excludeKind, excludeKey)
    local values  = {}
    local sorting = {}

    -- Buff bar icons
    local db = ns.API and ns.API.GetDB and ns.API.GetDB()
    if db and db.bars then
        for barNumber, barConfig in pairs(db.bars) do
            local barKey = "buffBarIcon|" .. tostring(barNumber)
            if not (excludeKind == "buffBarIcon" and tostring(excludeKey) == tostring(barNumber)) then
                local label
                if barConfig and barConfig.tracking then
                    local spellName = barConfig.tracking.buffName or barConfig.tracking.spellName or ""
                    label = spellName ~= "" and
                        ("Buff Bar " .. barNumber .. " (" .. spellName .. ")") or
                        ("Buff Bar " .. barNumber)
                else
                    label = "Buff Bar " .. barNumber
                end
                values[barKey]  = label
                sorting[#sorting + 1] = barKey
            end
        end
    end

    -- Arc Auras
    if ns.ArcAuras and ns.ArcAuras.GetDB then
        local arcDB = ns.ArcAuras.GetDB()
        if arcDB then
            local function addArcEntry(arcID, config)
                local arcKey = "arcAura|" .. arcID
                if not (excludeKind == "arcAura" and tostring(excludeKey) == arcID) then
                    local label
                    if config then
                        local name = config.displayName or config.spellName or config.itemName or arcID
                        label = "Arc Aura: " .. name
                    else
                        label = "Arc Aura: " .. arcID
                    end
                    values[arcKey]  = label
                    sorting[#sorting + 1] = arcKey
                end
            end
            if arcDB.trackedItems then
                for arcID, cfg in pairs(arcDB.trackedItems) do addArcEntry(arcID, cfg) end
            end
            if arcDB.trackedSpells then
                for arcID, cfg in pairs(arcDB.trackedSpells) do addArcEntry(arcID, cfg) end
            end
        end
    end

    -- CDM icons (cooldown + utility viewer types only — target-only role)
    if ns.CDMEnhance and ns.CDMEnhance.GetEnhancedFrames then
        local frames = ns.CDMEnhance.GetEnhancedFrames()
        for cooldownID, data in pairs(frames) do
            if type(cooldownID) == "number" and
               (data.viewerType == "cooldown" or data.viewerType == "utility") then
                local cdKey = "cdmIcon|" .. tostring(cooldownID)
                local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(cooldownID)
                local spellName = spellInfo and spellInfo.name or ("Spell " .. cooldownID)
                local label = "CDM Icon: " .. spellName ..
                              " (" .. (data.viewerType == "utility" and "Utility" or "Cooldown") .. ")"
                values[cdKey]  = label
                sorting[#sorting + 1] = cdKey
            end
        end
    end

    table.sort(sorting, function(a, b) return (values[a] or a) < (values[b] or b) end)
    return values, sorting
end

-- Decode a combined "kind|key" dropdown value back to (kind, key).
function TA.DecodeTargetValue(combined)
    if not combined or combined == "" then return "", "" end
    local sep = combined:find("|", 1, true)
    if not sep then return "", "" end
    return combined:sub(1, sep - 1), combined:sub(sep + 1)
end

-- Encode (kind, key) to the combined dropdown key.
function TA.EncodeTargetValue(kind, key)
    if not kind or kind == "" or not key or key == "" then return "" end
    return kind .. "|" .. tostring(key)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENT-DRIVEN REAPPLY
-- Matches the event set used by ArcUI_CDMGroupsAnchors.lua.
-- ═══════════════════════════════════════════════════════════════════════════
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("CINEMATIC_STOP")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and arg1 ~= "player" then
        return
    end
    C_Timer.After(0.1, TA.ReapplyAll)
end)
if C_EditMode then
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
end

-- ===================================================================
-- END OF ArcUI_TrackerAnchors.lua
