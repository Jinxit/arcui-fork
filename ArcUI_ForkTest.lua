-- [FORK] ArcUI_ForkTest.lua
-- Positive-assertion test suite for the wowless CI harness.
--
-- Defers all checks to PLAYER_LOGIN (+ C_Timer.After(0, ...)) so the full
-- addon lifecycle has completed before assertions run.
--
-- Sentinels emitted via error() so they appear in wowless's error channel:
--   ARCTEST_OK              — all assertions passed
--   ARCTEST_FAIL: <msg>     — an assertion failed (CI fails on any occurrence)
--
-- Do NOT assert on known-broken paths (C_Traits.GetNodeInfo, minimap SetText)
-- — those are accepted wowless gaps recorded in tools/wowless-ci/accepted-errors.yaml.

local _, ns = ...

local function fail(msg)
    error("ARCTEST_FAIL: " .. tostring(msg))
end

local function assert_true(cond, msg)
    if not cond then fail(msg) end
end

local function assert_type(val, expected_type, label)
    if type(val) ~= expected_type then
        fail(label .. ": expected " .. expected_type .. ", got " .. type(val))
    end
end

local function assert_callable(val, label)
    if type(val) ~= "function" then
        fail(label .. ": expected function, got " .. type(val))
    end
end

local function run_tests()
    -- ns is the shared addon namespace table.
    assert_type(ns, "table", "ns")

    -- ns.API must be a populated table with the expected getter functions.
    assert_type(ns.API, "table", "ns.API")

    local expected_api_fns = {
        "GetDB",
        "GetGlobalDB",
        "GetMaxStacks",
        "GetCurrentStacks",
        "IsBuffActive",
        "RefreshDisplay",
        "RefreshAll",
        "GetBarState",
        "GetBarConfig",
        "GetActiveBars",
        "GetCatalogEntries",
    }
    for _, name in ipairs(expected_api_fns) do
        assert_callable(ns.API[name], "ns.API." .. name)
    end

    -- ns.db must have been initialised by AceDB (Options loads it on PLAYER_LOGIN).
    assert_true(ns.db ~= nil, "ns.db should be initialised after PLAYER_LOGIN")

    -- Core module tables must be present.
    assert_type(ns.CooldownBars, "table", "ns.CooldownBars")
    assert_type(ns.Display, "table", "ns.Display")

    -- The public global API alias must be wired up.
    assert_true(_G.ArcUI_API ~= nil, "_G.ArcUI_API should be set")
    assert_true(_G.ArcUI_API == ns.API, "_G.ArcUI_API should equal ns.API")

    -- ns.API.GetCatalogEntries() must return a table (may be empty, but not nil).
    local catalog = ns.API.GetCatalogEntries()
    assert_type(catalog, "table", "ns.API.GetCatalogEntries() return value")

    -- All checks passed.
    error("ARCTEST_OK")
end

-- Register on PLAYER_LOGIN so the full init lifecycle has run.
local testFrame = CreateFrame("Frame")
testFrame:RegisterEvent("PLAYER_LOGIN")
testFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then return end
    -- Defer one more tick so everything registered on PLAYER_LOGIN has fired.
    C_Timer.After(0, run_tests)
end)
