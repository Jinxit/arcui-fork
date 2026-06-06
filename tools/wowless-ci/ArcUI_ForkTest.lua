-- [FORK] Wowless CI positive-assertion test
-- Appended to ArcUI.toc last so it never conflicts with upstream merges.
-- Guards on _G.WowlessData so it is a no-op in the live game client.
--
-- Emits machine-detectable sentinels via error() (print() has no stdout in wowless):
--   ARCTEST_OK            — all assertions passed
--   ARCTEST_FAIL <reason> — an assertion failed

local _, ns = ...

-- No-op outside wowless.
if not _G.WowlessData then return end

local function FAIL(msg)
  error("ARCTEST_FAIL " .. tostring(msg))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  -- Defer one tick so all other PLAYER_LOGIN handlers have finished.
  C_Timer.After(0, function()
    -- ns is a table (addon namespace populated by all files).
    if type(ns) ~= "table" then
      FAIL("ns is not a table: " .. type(ns))
      return
    end

    -- ns.API is a table with the expected getters.
    if type(ns.API) ~= "table" then
      FAIL("ns.API is not a table")
      return
    end
    for _, getter in ipairs({"GetDB", "GetMaxStacks", "GetCatalogEntries"}) do
      if type(ns.API[getter]) ~= "function" then
        FAIL("ns.API." .. getter .. " is not a function (got " .. type(ns.API[getter]) .. ")")
        return
      end
    end

    -- ns.db was initialised by AceDB.
    if ns.db == nil then
      FAIL("ns.db is nil (AceDB did not initialise)")
      return
    end

    -- Key modules are present.
    if type(ns.CooldownBars) ~= "table" then
      FAIL("ns.CooldownBars not present")
      return
    end
    if type(ns.Display) ~= "table" then
      FAIL("ns.Display not present")
      return
    end

    -- Global API surface is exported.
    if _G.ArcUI_API == nil then
      FAIL("_G.ArcUI_API is nil")
      return
    end

    -- ns.API.GetCatalogEntries() returns a table without throwing.
    local ok, result = pcall(ns.API.GetCatalogEntries)
    if not ok then
      FAIL("GetCatalogEntries threw: " .. tostring(result))
      return
    end
    if type(result) ~= "table" then
      FAIL("GetCatalogEntries returned non-table: " .. type(result))
      return
    end

    -- All assertions passed.
    error("ARCTEST_OK")
  end)
end)
