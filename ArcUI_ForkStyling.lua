-- ===================================================================
-- [FORK] ArcUI_ForkStyling.lua
-- Mask texture system and 8-slice LSM border overlays for resource bars.
--
-- Hooks ns.Resources.ApplyAppearance post-execution (hooksecurefunc).
-- Injects options into the Appearance options table post-build.
-- No upstream files modified; only one line appended to ArcUI.toc.
--
-- New cfg.display fields (nil = default, no schema entry needed):
--   maskStyle      string  "none" | "blizzard-classic" | "blizzard-classic-thin"
--   borderType     string  "drawn" (default) | "texture"
--   borderTexture  string  LSM border name (used when borderType = "texture")
--   borderEdgeSize number  8-slice corner/edge thickness in px (default 12)
-- ===================================================================

local ADDON, ns = ...

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Register standard Blizzard borders so the dropdown is populated on a
-- clean install with no other border-registering addons installed.
if LSM then
  LSM:Register("border", "UI Tooltip Border",    [[Interface\Tooltips\UI-Tooltip-Border]])
  LSM:Register("border", "UI Dialog Box Border", [[Interface\DialogFrame\UI-DialogBox-Border]])
end

-- Mask texture paths (WoW Interface-relative). TGA files ship in the
-- addon under Textures/Masks/ so every dropdown choice has a backing
-- file at install time.
local MASK_STYLES = {
  ["blizzard-classic"]      = [[Interface\AddOns\ArcUI\Textures\Masks\blizzard-classic-mask.tga]],
  ["blizzard-classic-thin"] = [[Interface\AddOns\ArcUI\Textures\Masks\blizzard-classic-thin-mask.tga]],
}

-- Sensei full-frame border names. These were authored as single whole-frame
-- images paired with matching masks, not 8-slice edge files. Existing saved
-- configs referencing these names are auto-reset to "drawn" on first
-- ApplyAppearance so users don't see a broken render after upgrading.
local SENSEI_FULLFRAME_BORDERS = {
  ["SCRB Border Blizzard Classic"]      = true,
  ["SCRB Border Blizzard Classic Thin"] = true,
}

-- ===================================================================
-- FORK BACKDROP MIXIN
-- Adapted from M33kAuras/BackdropTemplateM33kAuras.lua (m33shoq/M33kAuras).
-- Implements an 8-slice edge-file border renderer via NineSliceUtil.
-- SetupTextureCoordinates() guards all size/scale math with
-- hasanysecretvalues() to prevent combat taint on resource frames under
-- 12.0 (Midnight). This is the key fix over stock BackdropTemplate, which
-- performs the same math without the guard.
-- ===================================================================
local ForkBackdropMixin = {}

local _coordStart = 0.0625
local _coordEnd   = 1 - _coordStart

-- UV mapping for each 8-slice piece, compatible with the standard Blizzard
-- edge file format used by all default LSM border entries.
local _textureUVs = {
  TopLeftCorner     = { setWidth = true, setHeight = true,
    ULx = 0.5078125, ULy = _coordStart, LLx = 0.5078125, LLy = _coordEnd,
    URx = 0.6171875, URy = _coordStart, LRx = 0.6171875, LRy = _coordEnd },
  TopRightCorner    = { setWidth = true, setHeight = true,
    ULx = 0.6328125, ULy = _coordStart, LLx = 0.6328125, LLy = _coordEnd,
    URx = 0.7421875, URy = _coordStart, LRx = 0.7421875, LRy = _coordEnd },
  BottomLeftCorner  = { setWidth = true, setHeight = true,
    ULx = 0.7578125, ULy = _coordStart, LLx = 0.7578125, LLy = _coordEnd,
    URx = 0.8671875, URy = _coordStart, LRx = 0.8671875, LRy = _coordEnd },
  BottomRightCorner = { setWidth = true, setHeight = true,
    ULx = 0.8828125, ULy = _coordStart, LLx = 0.8828125, LLy = _coordEnd,
    URx = 0.9921875, URy = _coordStart, LRx = 0.9921875, LRy = _coordEnd },
  TopEdge    = { setHeight = true,
    ULx = 0.2578125, ULy = "repeatX", LLx = 0.3671875, LLy = "repeatX",
    URx = 0.2578125, URy = _coordStart, LRx = 0.3671875, LRy = _coordStart },
  BottomEdge = { setHeight = true,
    ULx = 0.3828125, ULy = "repeatX", LLx = 0.4921875, LLy = "repeatX",
    URx = 0.3828125, URy = _coordStart, LRx = 0.4921875, LRy = _coordStart },
  LeftEdge   = { setWidth = true,
    ULx = 0.0078125, ULy = _coordStart, LLx = 0.0078125, LLy = "repeatY",
    URx = 0.1171875, URy = _coordStart, LRx = 0.1171875, LRy = "repeatY" },
  RightEdge  = { setWidth = true,
    ULx = 0.1328125, ULy = _coordStart, LLx = 0.1328125, LLy = "repeatY",
    URx = 0.2421875, URy = _coordStart, LRx = 0.2421875, LRy = "repeatY" },
  Center = {
    ULx = 0, ULy = 0, LLx = 0, LLy = "repeatY",
    URx = "repeatX", URy = 0, LRx = "repeatX", LRy = "repeatY" },
}

local function _GetCoordValue(coord, pieceSetup, repeatX, repeatY)
  local v = pieceSetup[coord]
  if v == "repeatX" then return repeatX
  elseif v == "repeatY" then return repeatY
  else return v end
end

local function _SetPieceTexCoord(region, pieceSetup, repeatX, repeatY)
  region:SetTexCoord(
    _GetCoordValue("ULx", pieceSetup, repeatX, repeatY),
    _GetCoordValue("ULy", pieceSetup, repeatX, repeatY),
    _GetCoordValue("LLx", pieceSetup, repeatX, repeatY),
    _GetCoordValue("LLy", pieceSetup, repeatX, repeatY),
    _GetCoordValue("URx", pieceSetup, repeatX, repeatY),
    _GetCoordValue("URy", pieceSetup, repeatX, repeatY),
    _GetCoordValue("LRx", pieceSetup, repeatX, repeatY),
    _GetCoordValue("LRy", pieceSetup, repeatX, repeatY))
end

function ForkBackdropMixin:GetEdgeSize()
  if self.backdropInfo and self.backdropInfo.edgeSize and self.backdropInfo.edgeSize > 0 then
    return self.backdropInfo.edgeSize
  end
  return 12
end

function ForkBackdropMixin:SetupTextureCoordinates()
  local width  = self:GetWidth()
  local height = self:GetHeight()
  local effectiveScale = self:GetEffectiveScale()
  local edgeSize = self:GetEdgeSize()
  -- Guard: abort if any operand is a secret (12.0 Midnight combat lockdown).
  -- Without this guard, the division below taints the frame and blocks
  -- secure API calls for the rest of the combat.
  if hasanysecretvalues(width, height, effectiveScale, edgeSize) then return end
  local edgeRepeatX = max(0, (width  / edgeSize) * effectiveScale - 2 - _coordStart)
  local edgeRepeatY = max(0, (height / edgeSize) * effectiveScale - 2 - _coordStart)
  for pieceName, pieceSetup in pairs(_textureUVs) do
    local region = self[pieceName]
    if region then
      if pieceName == "Center" then
        _SetPieceTexCoord(region, pieceSetup, 1, 1)
      else
        _SetPieceTexCoord(region, pieceSetup, edgeRepeatX, edgeRepeatY)
      end
    end
  end
end

function ForkBackdropMixin:SetupPieceVisuals(piece, setupInfo, pieceLayout)
  local textureInfo = _textureUVs[setupInfo.pieceName]
  local tileVerts   = false
  local file
  if setupInfo.pieceName == "Center" then
    file      = self.backdropInfo.bgFile
    tileVerts = self.backdropInfo.tile
  else
    if self.backdropInfo.tileEdge ~= false then tileVerts = true end
    file = self.backdropInfo.edgeFile
  end
  piece:SetTexture(file, tileVerts, tileVerts)
  local cornerWidth  = textureInfo.setWidth  and self:GetEdgeSize() or 0
  local cornerHeight = textureInfo.setHeight and self:GetEdgeSize() or 0
  piece:SetSize(cornerWidth, cornerHeight)
end

function ForkBackdropMixin:ApplyBackdrop()
  local layout = {
    TopLeftCorner     = {},
    TopRightCorner    = {},
    BottomLeftCorner  = {},
    BottomRightCorner = {},
    TopEdge           = {},
    BottomEdge        = {},
    LeftEdge          = {},
    RightEdge         = {},
    Center            = { layer = "BACKGROUND" },
    setupPieceVisualsFunction = ForkBackdropMixin.SetupPieceVisuals,
  }
  NineSliceUtil.ApplyLayout(self, layout)
  self:SetBackdropBorderColor(1, 1, 1, 1)
  self:SetupTextureCoordinates()
end

function ForkBackdropMixin:SetBackdrop(backdropInfo)
  if backdropInfo then
    self.backdropInfo = backdropInfo
    self:ApplyBackdrop()
  else
    self:ClearBackdrop()
  end
end

function ForkBackdropMixin:ClearBackdrop()
  if self.backdropInfo then
    for pieceName in pairs(_textureUVs) do
      local region = self[pieceName]
      if region then region:SetTexture(nil) end
    end
    self.backdropInfo = nil
  end
end

function ForkBackdropMixin:SetBackdropBorderColor(r, g, b, a)
  if not self.backdropInfo then return end
  for pieceName in pairs(_textureUVs) do
    local region = self[pieceName]
    if region and pieceName ~= "Center" then
      region:SetVertexColor(r, g, b, a or 1)
    end
  end
end

-- ===================================================================
-- APPLYAPPEARANCE HOOK
-- Runs after the upstream function. Applies mask textures and 8-slice
-- LSM backdrop border overlays on top of whatever upstream already set up.
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
    -- "none", unrecognised style, or the chosen mask file failed to
    -- load: remove any existing fork mask so the bar returns to its
    -- native rectangular appearance.
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

  -- ── 8-SLICE BORDER SYSTEM ────────────────────────────────────────
  local borderOverlay = mainFrame.borderOverlay
  if not borderOverlay then return end

  local borderType = cfg.display.borderType or "drawn"

  -- Migration: configs that referenced a Sensei full-frame border are
  -- reset to "drawn". Sensei borders are whole-frame images, not 8-slice
  -- edge files, and would render incorrectly under this renderer.
  if borderType == "texture" then
    local texName = cfg.display.borderTexture
    if texName and SENSEI_FULLFRAME_BORDERS[texName] then
      cfg.display.borderType   = "drawn"
      cfg.display.borderTexture = nil
      borderType = "drawn"
    end
  end

  -- Suppress any forkTexture from the previous single-quad renderer that
  -- may persist in saved frames from an older session.
  if borderOverlay.forkTexture then borderOverlay.forkTexture:Hide() end

  if borderType == "texture" then
    -- Hide the four upstream drawn-pixel border edges.
    if borderOverlay.top    then borderOverlay.top:Hide()    end
    if borderOverlay.bottom then borderOverlay.bottom:Hide() end
    if borderOverlay.left   then borderOverlay.left:Hide()   end
    if borderOverlay.right  then borderOverlay.right:Hide()  end

    local texPath = LSM and cfg.display.borderTexture
                    and LSM:Fetch("border", cfg.display.borderTexture)
    if texPath then
      -- Lazy-create a child frame with ForkBackdropMixin mixed in.
      -- borderOverlay is a plain Frame (no BackdropTemplate), so we create
      -- a child rather than patching it directly.
      if not borderOverlay._forkBackdrop then
        local bd = CreateFrame("Frame", nil, borderOverlay)
        bd:SetAllPoints(mainFrame)
        bd:SetFrameLevel(borderOverlay:GetFrameLevel() + 1)
        Mixin(bd, ForkBackdropMixin)
        borderOverlay._forkBackdrop = bd
      end

      local bd      = borderOverlay._forkBackdrop
      local edgeSize = cfg.display.borderEdgeSize or 12
      local bc      = cfg.display.borderColor or { r = 0, g = 0, b = 0, a = 1 }
      bd:SetBackdrop({
        edgeFile = texPath,
        edgeSize = edgeSize,
        tileEdge = true,
      })
      bd:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
      bd:Show()
    else
      -- No texture configured or LSM lookup failed: hide the backdrop.
      if borderOverlay._forkBackdrop then
        borderOverlay._forkBackdrop:Hide()
      end
    end
  else
    -- "drawn" (default): hide and clear our 8-slice backdrop if present.
    if borderOverlay._forkBackdrop then
      borderOverlay._forkBackdrop:ClearBackdrop()
      borderOverlay._forkBackdrop:Hide()
    end
  end
end)

-- ===================================================================
-- OPTIONS INJECTION
-- Wraps ns.AppearanceOptions.GetOptionsTable to add mask/border
-- controls into the existing FRAME BORDER section (orders 51.5-51.75).
--
-- Selection state is derived from the existing barSelector.get(), which
-- is the same source the rest of the Appearance panel uses. We do not
-- track it ourselves — the previous SetSelectedBar wrapper missed the
-- dropdown's auto-pick and direct-set paths, leaving the fork controls
-- targeting nil or a stale right-click selection.
-- ===================================================================
do
  local origGetOptionsTable = ns.AppearanceOptions and ns.AppearanceOptions.GetOptionsTable
  if origGetOptionsTable then
    ns.AppearanceOptions.GetOptionsTable = function(...)
      local opts = origGetOptionsTable(...)
      if not (opts and opts.args) then return opts end

      -- Read the selected bar key the same way the AppearanceOptions
      -- module does. barSelector.get() is the canonical source and
      -- honours both the dropdown's set handler and its auto-pick
      -- fallback when selectedAppearanceBar is nil.
      local function GetSelectedKey()
        local sel = opts.args.barSelector
        if not (sel and sel.get) then return nil end
        return sel.get()
      end

      -- Returns the resource bar config the user is currently editing,
      -- or nil if the selection isn't a resource bar.
      local function ForkGetSelectedConfig()
        local key = GetSelectedKey()
        if not key then return nil end
        local barType, barNum = key:match("^(%w+)_(%d+)$")
        if barType == "resource" and barNum then
          return ns.API.GetResourceBarConfig(tonumber(barNum))
        end
        return nil
      end

      local function ForkRefreshSelectedBar()
        local key = GetSelectedKey()
        if not key then return end
        local barType, barNum = key:match("^(%w+)_(%d+)$")
        if barType == "resource" and barNum then
          ns.Resources.ApplyAppearance(tonumber(barNum))
        end
      end

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
            ForkRefreshSelectedBar()
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
        desc    = "Drawn (Pixel) = upstream pixel edges. Texture (LSM) = 8-slice LSM border.",
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
            ForkRefreshSelectedBar()
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
        desc    = "LSM-registered border texture used as the 8-slice overlay.",
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
            ForkRefreshSelectedBar()
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

      -- Border Edge Size: only visible when borderType = "texture".
      -- LSM does not store the edgeSize an author intended, so this must
      -- be set by the user. Standard Blizzard edge files use 8, 12, 16,
      -- 32, or 64; the default of 12 matches most tooltip-style borders.
      opts.args.forkBorderEdgeSize = {
        type  = "range",
        name  = "Border Edge Size",
        desc  = "Corner and edge slice thickness in pixels (4–64). Match to the border texture's authored edge size.",
        min   = 4,
        max   = 64,
        step  = 1,
        get   = function()
          local cfg = ForkGetSelectedConfig()
          return (cfg and cfg.display.borderEdgeSize) or 12
        end,
        set   = function(info, value)
          local cfg = ForkGetSelectedConfig()
          if cfg then
            cfg.display.borderEdgeSize = value
            ForkRefreshSelectedBar()
          end
        end,
        order  = 51.75,
        width  = "full",
        hidden = function()
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
