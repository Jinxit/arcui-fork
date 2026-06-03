-- ===================================================================
-- [FORK] ArcUI_ForkStyling.lua
-- Mask texture system and texture-based border overlays for resource bars.
--
-- Hooks ns.Resources.ApplyAppearance post-execution (hooksecurefunc).
-- Injects options into the Appearance options table post-build.
-- No upstream files modified; only one line appended to ArcUI.toc.
--
-- New cfg.display fields (nil = default, no schema entry needed):
--   maskStyle     string  "none" | "blizzard-classic" | "blizzard-classic-thin"
--   borderType    string  "drawn" (default) | "texture"
--   borderTexture string  LSM border name (used when borderType = "texture")
--
-- Mask texture files must be placed at:
--   Interface\AddOns\ArcUI\Textures\Masks\blizzard-classic-mask.png
--   Interface\AddOns\ArcUI\Textures\Masks\blizzard-classic-thin-mask.png
-- Source them from SenseiClassResourceBar (MIT licensed).
-- Without the files the mask styles fall back to rectangular (no error).
-- ===================================================================

local ADDON, ns = ...

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Mask texture paths (WoW Interface-relative)
local MASK_STYLES = {
  ["blizzard-classic"]      = [[Interface\AddOns\ArcUI\Textures\Masks\blizzard-classic-mask.png]],
  ["blizzard-classic-thin"] = [[Interface\AddOns\ArcUI\Textures\Masks\blizzard-classic-thin-mask.png]],
}

-- ===================================================================
-- TRACK SELECTED BAR FOR OPTIONS INJECTION
-- Wraps ns.AppearanceOptions.SetSelectedBar to capture the currently
-- selected bar type/number, needed by our injected option closures.
-- ===================================================================
local _selectedBarType, _selectedBarNum

do
  local orig = ns.AppearanceOptions and ns.AppearanceOptions.SetSelectedBar
  if orig then
    ns.AppearanceOptions.SetSelectedBar = function(barType, barNum, ...)
      _selectedBarType = barType
      _selectedBarNum  = barNum
      return orig(barType, barNum, ...)
    end
  end
end

local function ForkGetSelectedConfig()
  if _selectedBarType == "resource" and _selectedBarNum then
    return ns.API.GetResourceBarConfig(_selectedBarNum)
  end
  return nil
end

local function ForkRefreshBar()
  if _selectedBarType == "resource" and _selectedBarNum then
    ns.Resources.ApplyAppearance(_selectedBarNum)
  end
end

-- ===================================================================
-- APPLYAPPEARANCE HOOK
-- Runs after the upstream function. Applies mask textures and texture
-- border overlays on top of whatever upstream already set up.
-- ===================================================================
hooksecurefunc(ns.Resources, "ApplyAppearance", function(barNumber)
  local cfg = ns.API.GetResourceBarConfig(barNumber)
  if not cfg then return end

  local mainFrame = ns.Resources.GetBarFrame and ns.Resources.GetBarFrame(barNumber)
  if not mainFrame then return end

  -- ── MASK SYSTEM ──────────────────────────────────────────────────
  local maskStyle = cfg.display.maskStyle
  local maskPath  = maskStyle and MASK_STYLES[maskStyle]

  if maskPath then
    if not mainFrame._forkMask then
      mainFrame._forkMask = mainFrame:CreateMaskTexture()
    end
    local mask = mainFrame._forkMask
    mask:SetTexture(maskPath)

    local isVertical = (cfg.display.barOrientation == "vertical")
    local w, h = mainFrame:GetSize()
    mask:ClearAllPoints()
    mask:SetPoint("CENTER", mainFrame, "CENTER")
    mask:SetSize(isVertical and h or w, isVertical and w or h)
    mask:SetRotation(isVertical and math.rad(90) or 0)

    for i = 1, 5 do
      local layer = mainFrame.layers and mainFrame.layers[i]
      if layer then
        local tex = layer:GetStatusBarTexture()
        if tex then
          tex:RemoveMaskTexture(mask)
          tex:AddMaskTexture(mask)
        end
      end
    end
    if mainFrame.bg then
      mainFrame.bg:RemoveMaskTexture(mask)
      mainFrame.bg:AddMaskTexture(mask)
    end
    if mainFrame.predGainBar then
      local tex = mainFrame.predGainBar:GetStatusBarTexture()
      if tex then
        tex:RemoveMaskTexture(mask)
        tex:AddMaskTexture(mask)
      end
    end
    if mainFrame.predCostTex then
      mainFrame.predCostTex:RemoveMaskTexture(mask)
      mainFrame.predCostTex:AddMaskTexture(mask)
    end
  else
    -- "none" or unrecognised style: remove any existing fork mask so
    -- the bar returns to its native rectangular appearance.
    if mainFrame._forkMask then
      local mask = mainFrame._forkMask
      for i = 1, 5 do
        local layer = mainFrame.layers and mainFrame.layers[i]
        if layer then
          local tex = layer:GetStatusBarTexture()
          if tex then tex:RemoveMaskTexture(mask) end
        end
      end
      if mainFrame.bg then mainFrame.bg:RemoveMaskTexture(mask) end
      if mainFrame.predGainBar then
        local tex = mainFrame.predGainBar:GetStatusBarTexture()
        if tex then tex:RemoveMaskTexture(mask) end
      end
      if mainFrame.predCostTex then
        mainFrame.predCostTex:RemoveMaskTexture(mask)
      end
    end
  end

  -- ── TEXTURE BORDER SYSTEM ────────────────────────────────────────
  local borderOverlay = mainFrame.borderOverlay
  if not borderOverlay then return end

  local borderType = cfg.display.borderType or "drawn"

  if borderType == "texture" then
    -- Hide the four drawn-pixel border edges so they don't overlap
    if borderOverlay.top    then borderOverlay.top:Hide()    end
    if borderOverlay.bottom then borderOverlay.bottom:Hide() end
    if borderOverlay.left   then borderOverlay.left:Hide()   end
    if borderOverlay.right  then borderOverlay.right:Hide()  end

    if not borderOverlay.forkTexture then
      borderOverlay.forkTexture = borderOverlay:CreateTexture(nil, "OVERLAY")
    end

    local texPath = LSM and cfg.display.borderTexture
                    and LSM:Fetch("border", cfg.display.borderTexture)
    if texPath then
      local bc = cfg.display.borderColor or { r = 0, g = 0, b = 0, a = 1 }
      local isVertical = (cfg.display.barOrientation == "vertical")
      local w, h = mainFrame:GetSize()
      borderOverlay.forkTexture:SetTexture(texPath)
      borderOverlay.forkTexture:ClearAllPoints()
      borderOverlay.forkTexture:SetPoint("CENTER", mainFrame, "CENTER")
      if isVertical then
        borderOverlay.forkTexture:SetSize(h, w)
        borderOverlay.forkTexture:SetRotation(math.rad(90))
      else
        borderOverlay.forkTexture:SetSize(w, h)
        borderOverlay.forkTexture:SetRotation(0)
      end
      borderOverlay.forkTexture:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
      borderOverlay.forkTexture:Show()
    else
      -- LSM texture not found or not configured: hide overlay
      if borderOverlay.forkTexture then borderOverlay.forkTexture:Hide() end
    end
  else
    -- "drawn" (default): ensure our texture border is hidden
    if borderOverlay.forkTexture then borderOverlay.forkTexture:Hide() end
  end
end)

-- ===================================================================
-- OPTIONS INJECTION
-- Wraps ns.AppearanceOptions.GetOptionsTable to add mask/border
-- controls into the existing FRAME BORDER section (orders 51.5-51.7).
-- ===================================================================
do
  local origGetOptionsTable = ns.AppearanceOptions and ns.AppearanceOptions.GetOptionsTable
  if origGetOptionsTable then
    ns.AppearanceOptions.GetOptionsTable = function(...)
      local opts = origGetOptionsTable(...)
      if not (opts and opts.args) then return opts end

      -- Returns true when the border section is expanded (not collapsed).
      -- Reads the CollapsibleHeader toggle's get() directly so we avoid
      -- needing access to the private collapsedSections upvalue.
      local function IsBorderOpen()
        local bh = opts.args.borderHeader
        return bh and bh.get and bh.get()
      end

      -- Mask Style: independent of showBorder — visible whenever a
      -- resource bar is selected and the border section is open.
      opts.args.forkMaskStyle = {
        type    = "select",
        name    = "Mask Style",
        desc    = "Shape mask applied to bar fill. 'None' = rectangular (default).",
        values  = {
          ["none"]                  = "None (Rectangular)",
          ["blizzard-classic"]      = "Blizzard Classic",
          ["blizzard-classic-thin"] = "Blizzard Classic Thin",
        },
        sorting = { "none", "blizzard-classic", "blizzard-classic-thin" },
        get     = function()
          local cfg = ForkGetSelectedConfig()
          return (cfg and cfg.display.maskStyle) or "none"
        end,
        set     = function(info, value)
          local cfg = ForkGetSelectedConfig()
          if cfg then
            cfg.display.maskStyle = value
            ForkRefreshBar()
          end
        end,
        order   = 51.5,
        width   = "full",
        hidden  = function()
          if not IsBorderOpen() then return true end
          return ForkGetSelectedConfig() == nil
        end,
      }

      -- Border Type: only visible when showBorder is enabled.
      opts.args.forkBorderType = {
        type    = "select",
        name    = "Border Type",
        desc    = "Drawn (Pixel) = upstream pixel edges. Texture (LSM) = full LSM border overlay.",
        values  = {
          ["drawn"]   = "Drawn (Pixel)",
          ["texture"] = "Texture (LSM)",
        },
        get     = function()
          local cfg = ForkGetSelectedConfig()
          return (cfg and cfg.display.borderType) or "drawn"
        end,
        set     = function(info, value)
          local cfg = ForkGetSelectedConfig()
          if cfg then
            cfg.display.borderType = value
            ForkRefreshBar()
          end
        end,
        order   = 51.6,
        width   = "full",
        hidden  = function()
          if not IsBorderOpen() then return true end
          local cfg = ForkGetSelectedConfig()
          return not (cfg and cfg.display.showBorder)
        end,
      }

      -- Border Texture: only visible when borderType = "texture".
      opts.args.forkBorderTexture = {
        type    = "select",
        name    = "Border Texture",
        desc    = "LSM-registered border texture used as the overlay.",
        values  = function()
          return (LSM and LSM:HashTable("border")) or {}
        end,
        get     = function()
          local cfg = ForkGetSelectedConfig()
          return cfg and cfg.display.borderTexture
        end,
        set     = function(info, value)
          local cfg = ForkGetSelectedConfig()
          if cfg then
            cfg.display.borderTexture = value
            ForkRefreshBar()
          end
        end,
        order   = 51.7,
        width   = "full",
        hidden  = function()
          if not IsBorderOpen() then return true end
          local cfg = ForkGetSelectedConfig()
          if not (cfg and cfg.display.showBorder) then return true end
          return (cfg.display.borderType or "drawn") ~= "texture"
        end,
      }

      return opts
    end
  end
end
