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
- Upstream sync: new releases are imported to `upstream`, then merged into `main` via a `upstream-sync/X.Y.Z` branch and PR.

## Agent Fleet

This repo is managed by an autonomous agent fleet via the [agents](https://github.com/eloylp/agents) daemon:

| Agent | Role | Trigger |
|---|---|---|
| `arcui-syncer` | Checks CurseForge twice daily for new upstream versions, imports to `upstream` branch, merges into `main` via sync branch PR | Cron `0 5,17 * * *` |
| `arcui-coder` | Implements custom changes from issues | `ai ready` label |
| `arcui-reviewer` | Reviews PRs for correctness | `pull_request.opened`, `pull_request.synchronize` |
| `arcui-fixer` | Addresses review feedback | Dispatched by reviewer |
| `arcui-loop-judge` | Detects stuck review loops | Dispatched by reviewer after 3+ rounds |

### Runner Image

Fleet agents run inside a custom Docker image built from [`Jinxit/agents-runner`](https://github.com/Jinxit/agents-runner). It layers on top of the upstream [`ghcr.io/eloylp/agents-runner`](https://github.com/eloylp/agents) base image and adds:

- **Lua 5.1 toolchain** (`lua5.1`, `luac`, `luacheck`) — WoW runs Lua 5.1, so `luac -p` matches the in-game parser exactly. `luacheck` should be configured with `std = "lua51"` in `.luacheckrc`.
- **tweakcc** — patches the Claude Code binary to unlock the full model list in `/model`.
- **wowless** — headless WoW client Lua/FrameXML interpreter for CI testing. Pre-built binary with TACT client data at `/opt/wowless/`. Invocation:
  ```bash
  /opt/wowless/wowless_wow run -p wow --addondir /path/to/addon
  ```
  The TACT data (live retail WoW interface files) is at `/opt/wowless/products/`. The WoW client build info is at `/opt/wowless/products/wow/WowlessData/build.lua`. The image is rebuilt daily to track the latest wowless HEAD and WoW client build.

The image is published to `ghcr.io/jinxit/agents-runner` with immutable `sha-<shortsha>` tags. After each build, the fleet workspace runtime is automatically updated to the new tag. The base image digest is pinned in the Dockerfile for reproducibility; a base-image sync agent bumps it via PR when upstream advances.

CI workflows that need wowless should pull the image and run it via `docker run`, mounting the repo as the addon directory. The runner image does NOT include Python — write matcher/harness scripts in bash, Lua, or Node.js, or run them on the GitHub Actions host outside the container.

## Upstream Version Check

The syncer agent checks upstream via the CurseForge public API:
```
GET https://www.curseforge.com/api/v1/mods/1391614/files?pageSize=1
```
Project ID `1391614` is ArcUI. The response is JSON with the latest file's `displayName` (e.g. `ArcUI-3.7.0.zip`) and `id` (used to construct the download URL). Current version is read from `## Version:` in `ArcUI.toc`. If the CurseForge API fails, the run aborts — no fallback.

## CI

- **Lua syntax check** — `luac -p` on all `.lua` files for PRs to `main`
- **Wowless test** — runs ArcUI under the headless wowless interpreter inside the fleet runner image; error matcher enforces a version-bound accepted-error baseline (see `tools/wowless-ci/`)
- **luacheck** — static analysis with WoW-API-aware `.luacheckrc`, excludes `Libs/`
- **Release workflow** — on merge to `main`, zips addon files and creates a GitHub Release for WowUp

## This Is a Fork

This is NOT an original project. The upstream addon is actively developed by someone else and we regularly merge their releases. Every custom change you make will need to survive the next upstream merge. Write code accordingly:

- **Never modify upstream files in-place if you can avoid it.** Prefer hooks, wrappers, and post-load overrides that layer on top of existing code rather than editing it directly. If upstream rewrites the function you edited, you get a conflict. If you hooked it from a separate block, the hook still works or fails cleanly.
- **Isolate custom code.** When possible, put custom functionality in clearly marked blocks (`-- [FORK]` comment prefix) or in separate files that are appended to the TOC after upstream files. A new file never conflicts with upstream.
- **Don't reorganize, rename, or reformat upstream code.** Cosmetic changes create diff noise that turns every future merge into a nightmare. Touch only what you need to touch.
- **Minimal surface area.** The fewer lines you change in upstream files, the fewer conflicts you'll face. One surgical edit beats a refactor.
- **Document every upstream file modification.** If you must edit an upstream file, add a `-- [FORK] reason` comment at the change site so the merge agent (and future humans) can tell what's ours vs what's upstream.

## WoW API Constraints

### Taint
The WoW UI uses a **taint** system. Blizzard ("secure") code can do privileged things (cast spells, target units, use protected frames). The moment addon ("insecure") code touches a secure variable, function, or frame, it becomes **tainted** and those privileged operations break — often silently, sometimes with "action blocked" errors. This applies transitively: if your code writes to a table that secure code later reads, the entire chain taints.

- Never overwrite or hook Blizzard global functions that are called from secure code paths. Use `hooksecurefunc()` which runs your code *after* the original without tainting it.
- Never modify secure frames (action buttons, unit frames) from insecure code during combat. Use `RegisterAttributeDriver` / `SecureHandlerWrapScript` for combat-time frame changes.
- Be especially careful with the Cooldown Manager integration (`CDM_Module/`). CDM icons are action buttons — they are secure frames. Styling, positioning, and text overlays are fine, but never call `:SetAttribute()` on them from insecure code during combat.
- If something works out of combat but breaks in combat with "action blocked by an addon," taint is the cause.

### 12.0.0 (Midnight) Addon Restrictions
The Midnight expansion (Interface 120000+) added significant combat restrictions for addons:

- **Cooldown API changes** — `GetSpellCooldown` and related APIs behave differently. The addon already adapted in v3.6.2e+, but be aware when writing new cooldown-related code.
- **Protected cooldown info** — some cooldown data is now restricted during combat. Code that queries cooldowns must handle `nil` returns gracefully during combat lockdown.
- **Secret auras** — certain buffs/debuffs are now flagged as "secret" and are hidden from addon API queries (`UnitAura`, `AuraUtil`). Code that tracks auras must handle missing data for secret auras without erroring or showing stale state. Don't assume every active buff/debuff will appear in the aura scan.
- **Frame restrictions** — additional frames are now protected during combat. Test any frame manipulation code in combat, not just out of combat.

When writing custom features, always test in combat. A feature that works at a target dummy but breaks in a dungeon is worse than no feature.

## Rules

- Never push directly to `main` — always use branches and PRs.
- Never commit custom changes to the `upstream` branch.
- When resolving merge conflicts between upstream and our patches, preserve our custom behavior while incorporating upstream improvements.
- Keep custom changes minimal and well-documented.

### Local development workflow

- **Always `git fetch origin && git checkout -b <branch> origin/main`** before starting work. Never branch from a stale local `main`. The fleet agents push to `main` autonomously — your local copy is outdated the moment you look away.
- **Never merge PRs from the CLI.** Always create a PR and let the user merge via GitHub. You are not authorized to merge.
- **Never commit directly to `main`.** Every change goes through a branch and PR, no exceptions, no "it's just a small fix."
- **Never create a PR without explicit user approval.** Commit and push to a branch, then ask the user before running `gh pr create`. The user decides when and whether to open PRs.

### Agent-aware workflow

This repo has autonomous agents that work on issues and PRs **between and during your turns**. Assume any PR or issue you looked at 5 minutes ago has changed.

- **Before acting on a PR or issue, always re-read its current state** — comments, reviews, commits, CI status. Do not rely on what you read earlier in the conversation. The fleet may have pushed commits, posted reviews, or closed the PR while you were working.
- **Before posting comments or triggering agents, check what's already happened.** A reviewer may have already reviewed. A fixer may have already pushed. Don't duplicate work or create loops.
- **Do not open PRs that depend on unmerged upstream work.** If a PR can't pass CI until another repo's PR is merged and deployed, don't create it yet — push to the branch and wait. Opening it prematurely wastes reviewer agent cycles on guaranteed failures.
