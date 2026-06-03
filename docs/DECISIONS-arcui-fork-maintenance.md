# Grill: ArcUI Fork Maintenance Strategy

> Fully autonomous agent fleet that maintains a private fork of ArcUI (WoW addon) with persistent custom changes, synced from upstream CurseForge releases, deployed via GitHub Releases to WowUp.

## Decisions

### 1. Upstream sync model: download-and-diff, not git-merge
- **Decision:** Confirmed. ArcUI has no public git repo — it's distributed via CurseForge. Agent downloads new zips and diffs against the repo.
- **Implications:** Prompt must describe the download-and-diff workflow, not git-merge. Conflicts are file-level overlays, not git-level merges.

### 2. Version check mechanism: Wago Inertia API
- **Decision:** Confirmed. `GET /addons/arcui/versions?stability=stable` with `X-Inertia: true` header returns clean JSON with version labels, signed download URLs, and changelogs. No auth required. Note: the official Wago API (`docs.wago.io`) is publisher-only (upload releases); the Inertia endpoint is the consumer-facing data layer.
- **Implications:** Agent sends `X-Inertia` and `X-Inertia-Version` headers. Download URLs are time-limited signed links — must download immediately. **If the Wago API fails for any reason, the entire cron run aborts. No fallback, no scraping, no guessing. A clean failure is better than a wrong import.**

### 3. Upstream version tracking: read from ArcUI.toc
- **Decision:** Confirmed. Parse `## Version:` from `ArcUI.toc`. Compare against Wago's `releases.data[0].label` (strip `ArcUI-` prefix).
- **Implications:** No extra files, tags, or conventions. TOC is the canonical version source.

### 4. Import model: two-branch (upstream + main)
- **Decision:** Confirmed. `upstream` branch mirrors CurseForge releases exactly. `main` carries custom patches on top. Agent imports to `upstream`, then opens PR merging `upstream → main`.
- **Implications:** Both branches created from ArcUI 3.6.8 baseline. Custom changes go on `main` only. Merge conflicts = "upstream changed something we also patched."

### 5. Conflict resolution: fully autonomous
- **Decision:** Agent must resolve all conflicts itself, understanding the Lua code semantically. No human intervention. If upstream removed a system our patch depends on, agent adapts our patch to the new architecture.
- **Implications:** Prompt must treat conflicts as a code comprehension task. Agent reads both versions, understands intent, produces a working merge. This is the hardest part of the system.

### 6. Merge flow: two-agent review loop with CI gate
- **Decision:** Coder opens PRs, reviewer reviews, fixer addresses feedback. GitHub CI runs `luac -p` syntax checks. Reviewer approval + CI green = auto-merge. Fully autonomous.
- **Implications:** GitHub Actions workflow for Lua syntax validation. Branch protection on `main` requiring CI pass. `upstream` branch has no protection.

### 7. Review loop termination: 3 rounds then loop detector
- **Decision:** After 3 rounds without merge, a loop-judge agent (cheap model) evaluates whether the conversation is stuck. If progressing, loop continues. If stuck, PR stays open as escape hatch.
- **Implications:** Loop-judge reads PR comment history, not code. Fires every 3 rounds after the initial 3.

### 8. Model assignments per agent
- **Decision:** Four agents:
  - `arcui-coder` — claude-sonnet-4-6 — creates PRs, upstream merges, custom changes
  - `arcui-reviewer` — gpt-5.5 (codex) — reviews PRs
  - `arcui-fixer` — claude-opus-4-6 — addresses review feedback (hardest reasoning)
  - `arcui-loop-judge` — haiku — stuck-loop detection
- **Implications:** Coder and fixer are separate roles: initial work is more mechanical, review fixes need deeper reasoning. Primary models only for now; no fallback mechanism.

### 9. Dispatch chain: events + inter-agent dispatch
- **Decision:** Hybrid flow:
  1. **Cron** `0 * * * *` → `arcui-coder` checks Wago, imports upstream, opens PR
  2. **`pull_request.opened` / `pull_request.synchronize`** → `arcui-reviewer` reviews
  3. Reviewer requests changes → **dispatches** `arcui-fixer`
  4. Fixer pushes fixes → `pull_request.synchronize` re-triggers reviewer
  5. Round 3+ → reviewer **dispatches** `arcui-loop-judge`
  6. Judge: continue → **dispatches** `arcui-fixer`; stuck → labels PR, stops
  7. Reviewer approves → auto-merge
- **Implications:** Coder binds to cron + `issues.labeled`. Reviewer binds to PR events. Fixer and loop-judge have NO repo bindings — dispatch only. Wiring: reviewer `can_dispatch: [arcui-fixer, arcui-loop-judge]`; loop-judge `can_dispatch: [arcui-fixer]`. Default `MAX_DEPTH=3` is fine — webhook events reset depth.

### 10. Cron frequency: hourly
- **Decision:** `0 * * * *`. 24 checks/day. No-op runs are cheap.

### 11. Custom change trigger: `ai ready` label
- **Decision:** `ai ready` label on issues. Coder binds to `issues.labeled`. Prompt distinguishes cron (upstream sync) from label (custom change) by event type. Same review loop applies.

### 12. Deployment: GitHub Releases → WowUp
- **Decision:** On merge to `main`, GitHub Actions zips addon files (excluding `.git`, `.github`, `docs/`, `.mcp.json`) into an `ArcUI/` top-level folder, creates a GitHub Release tagged with the TOC version, attaches the zip. WowUp watches the repo for releases and auto-installs.

## Open Items
- **Fallback mechanism:** Daemon doesn't support native model fallback or usage-limit detection. Primary models only for now. Potential future PR to the agents project.
- **Infra blockers:** `GITHUB_TOKEN` (PAT with `repo` scope), `GITHUB_WEBHOOK_SECRET`, webhook on repo → `https://agents.machine.army/webhooks/github`, `ai ready` label on repo, GitHub Actions CI for `luac -p`, GitHub Actions release workflow. All deferred to implementation phase.
- **WowUp release format:** Need to verify exact tag format and zip structure WowUp expects from GitHub releases. Likely `v3.6.8` tag with `ArcUI/` folder in zip containing `.toc`.

## Risk Register
- **Conflict resolution quality:** The hardest decision. Agent must semantically merge Lua code it's never seen before. Mitigation: reviewer agent catches bad merges, CI catches syntax errors. Remaining risk: logic bugs that pass syntax check and reviewer.
- **Wago API stability:** The Inertia endpoint is an internal SPA API, not a documented public API (the official `docs.wago.io` API is publisher-only). It could change without notice. Mitigation: if it breaks, the cron run aborts cleanly — no fallback. Fix the agent prompt to use whatever the new endpoint is.
- **Codex auth token refresh:** The `CODEX_AUTH_JSON_BASE64` contains a refresh token that expires. Ephemeral runner containers can't persist refreshed tokens. Risk of Codex backend dying silently. Mitigation: monitor backend health via the daemon status endpoint.
- **Review loop cost:** A multi-round review with opus-tier fixer could get expensive. Mitigation: loop-judge caps runaway loops; most upstream syncs should be clean merges with no conflicts.
