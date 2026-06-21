---@diagnostic disable: undefined-field, undefined-global
-- ArcUI_BarGroupAlign.lua
-- Shared pixel-perfect bar alignment for CDM group anchoring.
-- Used by ArcUI_Resources, ArcUI_CooldownBars, ArcUI_Display, and any future bar type.
-- See ArcUI_BarAlignment.md for the full explanation of every drift source fixed here.

local _, ns = ...
ns.BarGroupAlign = ns.BarGroupAlign or {}
local BGA = ns.BarGroupAlign

-- ===================================================================
-- PIXEL SNAP
-- ===================================================================

-- SnapToGroupPx: identical formula to CDMGroups Layout() snapPx.
-- Uses UIParent:GetScale() — NOT container:GetEffectiveScale() — to match CDMGroups exactly.
-- Always use this when sizing a bar to match _slotAreaW / _slotAreaH.
local function SnapToGroupPx(n)
  local _, h = GetPhysicalScreenSize()
  local s = UIParent:GetScale()
  if h and h > 0 and s and s > 0 then
    local ppu = (h / 768) * s
    return math.floor(n * ppu + 0.5) / ppu
  end
  return math.floor(n + 0.5)
end
BGA.SnapToGroupPx = SnapToGroupPx

-- PixelSnap: for dimensions NOT derived from CDMGroups (bar height, etc.).
-- Accepts explicit effectiveScale for callers that already have it.
function BGA.PixelSnap(n, effectiveScale)
  local _, h = GetPhysicalScreenSize()
  local s = effectiveScale or UIParent:GetScale()
  if h and h > 0 and s and s > 0 then
    local ppu = (h / 768) * s
    return math.floor(n * ppu + 0.5) / ppu
  end
  return math.floor(n + 0.5)
end

-- ===================================================================
-- ACTUAL ICON INSET READERS
-- These read live frame positions instead of computing from rawBase.
-- GetLeft()/GetTop() and SetPoint offsets share the same WoW coordinate
-- space, so the difference is directly usable as a SetPoint offset.
-- ===================================================================

-- X inset: container BOTTOMLEFT → leftmost visible icon left edge.
local function GetIconInsetX(group)
  local rawBase = group and group._slotInsetPx or 0
  if not group or not group.members or not group.container then return rawBase end
  local containerLeft = group.container:GetLeft()
  if not containerLeft then return rawBase end
  local minLeft = math.huge
  for _, member in pairs(group.members) do
    local frame = member.frame
    if frame and frame:IsShown() then
      local fL = frame:GetLeft()
      if fL and fL < minLeft then minLeft = fL end
    end
  end
  if minLeft < math.huge then
    return SnapToGroupPx(minLeft - containerLeft)
  end
  return rawBase
end
BGA.GetIconInsetX = GetIconInsetX

-- Y inset (top): downward inset from container top edge to topmost icon top edge.
-- WoW Y is inverted: containerTop - iconTop = positive downward value.
local function GetIconInsetY(group)
  local rawBase = group and group._slotInsetPx or 0
  if not group or not group.members or not group.container then return rawBase end
  local containerTop = group.container:GetTop()
  if not containerTop then return rawBase end
  local maxTop = -math.huge
  for _, member in pairs(group.members) do
    local frame = member.frame
    if frame and frame:IsShown() then
      local fT = frame:GetTop()
      if fT and fT > maxTop then maxTop = fT end
    end
  end
  if maxTop > -math.huge then
    return SnapToGroupPx(containerTop - maxTop)
  end
  return rawBase
end
BGA.GetIconInsetY = GetIconInsetY

-- Y inset (bottom): distance in WoW units from container bottom edge UP to the
-- bottom edge of the lowest visible icon. Use as positive Y offset in a TOPLEFT
-- anchor so the bar sits flush against the icon area bottom, not the container edge.
local function GetIconInsetBottom(group)
  local rawBase = group and group._slotInsetPx or 0
  if not group or not group.members or not group.container then return rawBase end
  local containerBottom = group.container:GetBottom()
  if not containerBottom then return rawBase end
  local minBottom = math.huge
  for _, member in pairs(group.members) do
    local frame = member.frame
    if frame and frame:IsShown() then
      local fB = frame:GetBottom()
      if fB and fB < minBottom then minBottom = fB end
    end
  end
  if minBottom < math.huge then
    return SnapToGroupPx(minBottom - containerBottom)  -- positive = icon bottom above container bottom
  end
  return rawBase
end
BGA.GetIconInsetBottom = GetIconInsetBottom

-- ===================================================================
-- [FORK] begin: Legacy migration + 9-point source/dest anchor system (issue #14)
-- ===================================================================

local LEGACY_ANCHOR_MAP = {
  TOP    = { "BOTTOM", "TOP"    },
  BOTTOM = { "TOP",    "BOTTOM" },
  LEFT   = { "RIGHT",  "LEFT"   },
  RIGHT  = { "LEFT",   "RIGHT"  },
}

--- Returns sourcePoint, destPoint from a display config, migrating legacy anchorPoint if needed.
--- @param display table cfg.display table
--- @return string sourcePoint, string destPoint
function BGA.GetAnchorPoints(display)
  local src = display.anchorSourcePoint
  local dst = display.anchorDestPoint
  if not src or not dst then
    local m = LEGACY_ANCHOR_MAP[display.anchorPoint or "BOTTOM"] or LEGACY_ANCHOR_MAP.BOTTOM
    src, dst = m[1], m[2]
  end
  return src, dst
end

-- [FORK] end
-- ===================================================================

-- ===================================================================
-- DIMENSION HELPERS
-- ===================================================================

--- Returns the matched bar dimension in WoW units.
--- For horizontal bars (isVertical=false) matches group WIDTH (_slotAreaW).
--- For vertical bars (isVertical=true) matches group HEIGHT (_slotAreaH).
--- Size formula: baseDim * (1 + sizeAdjustPct/100) + sizeAdjust
--- @param group table CDMGroups group object
--- @param isVertical boolean true when the bar's primary axis is vertical -- [FORK] replaces isSideAnchor (issue #14)
--- @param sizeAdjust number? pixel offset (cfg.display.matchWidthAdjust)
--- @param sizeAdjustPct number? percentage offset, -100..200 (cfg.display.matchWidthAdjustPct) -- [FORK] new param (issue #14)
--- @return number? dimension in WoW units, or nil if group not ready
function BGA.GetMatchedDimension(group, isVertical, sizeAdjust, sizeAdjustPct) -- [FORK] signature change (issue #14)
  if not group then return nil end
  local dim
  if isVertical then -- [FORK] was: isFragVertical with isSideAnchor branch (issue #14)
    dim = group._slotAreaHRaw or group._slotAreaH
  else
    dim = group._slotAreaWRaw or group._slotAreaW
  end
  if not dim or dim <= 0 then return nil end
  local pct = sizeAdjustPct or 0 -- [FORK] new percentage adjustment (issue #14)
  local px  = sizeAdjust or 0
  return SnapToGroupPx(dim * (1 + pct / 100) + px)
end

-- ===================================================================
-- ANCHOR APPLICATION
-- ===================================================================

--- Apply group-aligned anchor to a bar frame using explicit 9-point anchor names.
--- When applyIconEdges is true, an automatic Y inset aligns the bar flush with
--- icon edges when destPoint is a top/bottom container edge (resource bars only).
--- @param frame table WoW frame to anchor
--- @param container table CDMGroups container frame
--- @param group table CDMGroups group object
--- @param sourcePoint string WoW anchor point on the bar (e.g. "TOP", "BOTTOMLEFT") -- [FORK] replaces anchorPoint+barWidth+matchSlots (issue #14)
--- @param destPoint string WoW anchor point on the container -- [FORK] new param (issue #14)
--- @param offsetX number cfg.display.anchorOffsetX
--- @param offsetY number cfg.display.anchorOffsetY
--- @param applyIconEdges boolean? auto Y icon-edge inset for resource bars -- [FORK] new param (issue #14)
function BGA.ApplyAnchor(frame, container, group, sourcePoint, destPoint, offsetX, offsetY, applyIconEdges) -- [FORK] signature change (issue #14)
  local ox = offsetX or 0
  local oy = offsetY or 0
  -- [FORK] begin: icon-edge Y inset applied via destPoint matching, not via anchorPoint branch (issue #14)
  if applyIconEdges then
    if destPoint == "TOP" or destPoint == "TOPLEFT" or destPoint == "TOPRIGHT" then
      oy = oy - GetIconInsetY(group)
    elseif destPoint == "BOTTOM" or destPoint == "BOTTOMLEFT" or destPoint == "BOTTOMRIGHT" then
      oy = oy + GetIconInsetBottom(group)
    end
  end
  -- [FORK] end
  frame:ClearAllPoints()
  frame:SetPoint(sourcePoint, container, destPoint, ox, oy)
end

-- ===================================================================
-- HIGH-LEVEL HELPERS (convenience wrappers using groupName string)
-- ===================================================================

--- Returns matched dimension by group name.
--- @param groupName string
--- @param isVertical boolean -- [FORK] replaces isFragVertical+isSideAnchor (issue #14)
--- @param sizeAdjust number?
--- @param sizeAdjustPct number? -- [FORK] new param (issue #14)
--- @return number?
function BGA.GetMatchedDimensionByName(groupName, isVertical, sizeAdjust, sizeAdjustPct) -- [FORK] signature change (issue #14)
  local group = ns.CDMGroups and ns.CDMGroups.groups and ns.CDMGroups.groups[groupName]
  return BGA.GetMatchedDimension(group, isVertical, sizeAdjust, sizeAdjustPct)
end

--- Returns X icon inset by group name.
--- @param groupName string
--- @return number
function BGA.GetIconInsetXByName(groupName)
  local group = ns.CDMGroups and ns.CDMGroups.groups and ns.CDMGroups.groups[groupName]
  return GetIconInsetX(group)
end

--- Returns Y icon inset by group name.
--- @param groupName string
--- @return number
function BGA.GetIconInsetYByName(groupName)
  local group = ns.CDMGroups and ns.CDMGroups.groups and ns.CDMGroups.groups[groupName]
  return GetIconInsetY(group)
end

--- Returns bottom Y icon inset by group name.
--- @param groupName string
--- @return number
function BGA.GetIconInsetBottomByName(groupName)
  local group = ns.CDMGroups and ns.CDMGroups.groups and ns.CDMGroups.groups[groupName]
  return GetIconInsetBottom(group)
end

--- Full size + anchor in one call. Main entry point for all bar types.
---
--- Size: when matchGroupWidth is true, the bar's primary-axis dimension is matched to the group.
---   isVertical=false → match group WIDTH; isVertical=true → match group HEIGHT.
---   Formula: matched = baseDim * (1 + sizeAdjustPct/100) + sizeAdjust
---   matchSlotsOnly=true uses _slotAreaW/H; falls back to container dimensions if unavailable.
---
--- Anchor: frame:SetPoint(sourcePoint, container, destPoint, ox, oy).
---   applyIconEdges adds Y inset when destPoint is a top/bottom edge (resource bars).
---
--- @param frame table bar's root frame
--- @param groupName string cfg.display.anchorGroupName
--- @param sourcePoint string WoW anchor point on the bar -- [FORK] replaces anchorPoint (issue #14)
--- @param destPoint string WoW anchor point on the container -- [FORK] new param (issue #14)
--- @param barHeight number the bar's non-matched dimension (cfg.display.height * scale)
--- @param offsetX number cfg.display.anchorOffsetX
--- @param offsetY number cfg.display.anchorOffsetY
--- @param matchGroupWidth boolean cfg.display.matchGroupWidth
--- @param matchSlotsOnly boolean cfg.display.matchSlotsOnly
--- @param isVertical boolean true when the bar's primary axis is vertical -- [FORK] replaces isFragVertical (issue #14)
--- @param sizeAdjust number? cfg.display.matchWidthAdjust (pixel offset, applied after pct)
--- @param sizeAdjustPct number? cfg.display.matchWidthAdjustPct (percentage, -100..200) -- [FORK] new param (issue #14)
--- @param needsSwap boolean? swap SetSize width/height arguments (vertical bars)
--- @param applyIconEdges boolean? auto Y icon-edge inset, resource bars only -- [FORK] new param (issue #14)
--- @return number? barWidth the resolved matched dimension, or nil if not matched
function BGA.ApplySizeAndAnchor(frame, groupName, sourcePoint, destPoint, barHeight, offsetX, offsetY, -- [FORK] signature change (issue #14)
    matchGroupWidth, matchSlotsOnly, isVertical, sizeAdjust, sizeAdjustPct, needsSwap, applyIconEdges)

  local group = ns.CDMGroups and ns.CDMGroups.groups and ns.CDMGroups.groups[groupName]
  if not group or not group.container then return nil end
  local container = group.container

  local barWidth

  if matchGroupWidth then
    -- [FORK] begin: try slots first, fall back to container dims; add pct formula (issue #14)
    local dim
    if matchSlotsOnly then
      dim = BGA.GetMatchedDimension(group, isVertical, sizeAdjust, sizeAdjustPct)
    end
    if not dim then
      local cW, cH = container:GetWidth(), container:GetHeight()
      local base = isVertical and cH or cW
      if base > 0 then
        local pct = sizeAdjustPct or 0
        local px  = sizeAdjust or 0
        dim = SnapToGroupPx(base * (1 + pct / 100) + px)
      end
    end
    -- [FORK] end
    if dim and dim > 0 then
      barWidth = dim
      if needsSwap then
        frame:SetSize(barHeight, barWidth)
      else
        frame:SetSize(barWidth, barHeight)
      end
    end
  end

  BGA.ApplyAnchor(frame, container, group, sourcePoint, destPoint, offsetX, offsetY, applyIconEdges) -- [FORK] 9-point anchor (issue #14)

  return barWidth
end