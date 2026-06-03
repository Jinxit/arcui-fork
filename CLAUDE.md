# CLAUDE.md

## Project Overview

**arcui-fork** is a private maintained fork of the [ArcUI](https://www.curseforge.com/wow/addons/arc-ui) World of Warcraft addon (retail). The fork carries persistent custom modifications while staying in sync with upstream releases from CurseForge/Wago.

## Codebase

- **Language:** Lua (WoW API + Ace3 framework)
- **Addon type:** Buff/debuff tracking bars, resource bars, cooldown bars, timer bars, and full Cooldown Manager (CDM) integration
- **Entry point:** `ArcUI.toc` defines load order
- **Settings:** `ArcUIDB` SavedVariable via AceDB-3.0
- **Key files:**
  - `ArcUI_Core.lua` — addon initialization, event registration
  - `ArcUI_Display.lua` — frame creation and visual updates
  - `ArcUI_Resources.lua` — mana/rage/energy/etc resource tracking
  - `ArcUI_DB.lua` — database schema and defaults
  - `ArcUI_Options.lua` — AceConfig options panel
  - `ArcUI_CooldownBars.lua` — cooldown charge bar tracking
  - `ArcUI_CooldownReminder.lua` — reminder pulse system
  - `CDM_Module/` — Cooldown Manager integration (groups, enhance, auras)
- **Libraries:** Ace3 suite (AceAddon, AceDB, AceGUI, AceConfig, AceSerializer), LibSharedMedia, LibCustomGlow, LibDeflate, LibSerialize, LibEditModeOverride, LibEQOL

## Branch Model

- **`main`** — our fork with custom patches applied. This is what gets released.
- **`upstream`** — clean mirror of upstream CurseForge releases. Never has custom changes.
- Upstream sync: new releases are imported to `upstream`, then PRd into `main`.

## Agent Fleet

This repo is managed by an autonomous agent fleet via the [agents](https://github.com/eloylp/agents) daemon:

| Agent | Role | Trigger |
|---|---|---|
| `arcui-syncer` | Checks Wago hourly for new upstream versions, imports to `upstream` branch, opens PR to `main` | Cron `0 * * * *` |
| `arcui-coder` | Implements custom changes from issues | `ai ready` label |
| `arcui-reviewer` | Reviews PRs for correctness | `pull_request.opened`, `pull_request.synchronize` |
| `arcui-fixer` | Addresses review feedback | Dispatched by reviewer |
| `arcui-loop-judge` | Detects stuck review loops | Dispatched by reviewer after 3+ rounds |

## Upstream Version Check

The syncer agent checks upstream via the Wago Inertia API:
```
GET https://addons.wago.io/addons/arcui/versions?stability=stable
Headers: X-Inertia: true
```
Current version is read from `## Version:` in `ArcUI.toc`. If the Wago API fails, the run aborts — no fallback.

## CI

- **Lua syntax check** — `luac -p` on all `.lua` files for PRs to `main`
- **Release workflow** — on merge to `main`, zips addon files and creates a GitHub Release for WowUp

## Rules

- Never push directly to `main` — always use branches and PRs.
- Never commit custom changes to the `upstream` branch.
- When resolving merge conflicts between upstream and our patches, preserve our custom behavior while incorporating upstream improvements.
- Keep custom changes minimal and well-documented.
