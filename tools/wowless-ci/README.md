# Wowless CI harness

This directory contains the headless-test infrastructure for ArcUI.

ArcUI is run inside [wowless](https://github.com/wowless/wowless) — a
headless WoW client Lua/FrameXML interpreter — to catch load-time and runtime
regressions without the game client.

---

## How it works

The CI workflow (`.github/workflows/wowless.yml`) runs on every PR that
touches `.lua`, `.xml`, or `.toc` files:

1. Pulls the fleet runner image (`ghcr.io/jinxit/agents-runner:latest`),
   which contains a pre-built `wowless_wow` binary, sqlite databases, and
   live retail TACT data at `/opt/wowless/`.
2. Mounts the repo into the container and runs:
   ```
   docker run --rm --workdir /opt/wowless \
     -v "$PWD:/addon:ro" \
     ghcr.io/jinxit/agents-runner:latest \
     ./wowless_wow run -p wow \
       --addondir build/products/wow/WowlessData \
       --addondir /addon
   ```
   The `--workdir /opt/wowless` is required because wowless resolves all
   runtime data via hardcoded `build/...` paths relative to CWD.
   Two `--addondir` args load the WowlessData addon (provides
   `_G.WowlessData.Build`) and our ArcUI addon.
3. Captures stdout+stderr into `wowless-output.txt`.
4. Reads the WoW client build from `/opt/wowless/products/wow/WowlessData/build.lua`.
5. Runs `match-errors.py` (on the GH Actions host) against the captured
   output and the `accepted-errors.yaml` baseline.

CI also runs `ArcUI_ForkTest.lua` (appended to `ArcUI.toc`) which asserts
against the live addon surface and emits `ARCTEST_OK` / `ARCTEST_FAIL`
sentinels detected by the matcher.

---

## Baseline invariants

`match-errors.py` enforces three invariants on each run:

| Condition | Meaning | Action |
|---|---|---|
| **Unexpected error** | Observed error not in baseline | Triage: is it a new bug or a wowless gap? Add entry or fix regression. |
| **Stale acceptance** | `acceptedOnBuild` != current build | Re-validate (see below). |
| **Vanished acceptance** | Accepted error absent from output | Remove the entry and understand why (bug fixed, wowless updated, etc.). |

---

## Re-validating the baseline when the WoW client build changes

The runner image is rebuilt daily to track the latest wowless HEAD and WoW
client build.  When the build number changes, **every** entry in
`accepted-errors.yaml` is stale and CI will fail until re-validated.

### Steps

1. **Find the new build number.**

   ```bash
   docker run --rm ghcr.io/jinxit/agents-runner:latest \
     cat /opt/wowless/products/wow/WowlessData/build.lua
   ```

   Note the `build` and `version` values.

2. **Run wowless locally against the addon.**

   ```bash
   docker run --rm --workdir /opt/wowless \
     -v "$(pwd):/addon:ro" \
     ghcr.io/jinxit/agents-runner:latest \
     ./wowless_wow run -p wow \
       --addondir build/products/wow/WowlessData \
       --addondir /addon \
     > wowless-output.txt 2>&1
   ```

3. **Extract build info for the matcher.**

   ```bash
   docker run --rm ghcr.io/jinxit/agents-runner:latest \
     cat /opt/wowless/products/wow/WowlessData/build.lua \
     > wowless-build.lua
   ```

4. **Run the matcher** (it will report stale/vanished/unexpected entries):

   ```bash
   python3 tools/wowless-ci/match-errors.py \
     --output wowless-output.txt \
     --build-lua wowless-build.lua \
     --baseline tools/wowless-ci/accepted-errors.yaml \
     --addon-mount /addon
   ```

5. **For each stale entry that still reproduces:** update `acceptedOnBuild`
   and `acceptedOnVersion` to the new values.

6. **For each vanished entry:** remove it.  Note in the PR what changed
   (wowless fix, upstream patch, etc.).

7. **For each unexpected entry:** decide:
   - **wowless gap** -> add a new entry with `category: wowless-bug`.
   - **Our regression** -> fix it instead of accepting it.
   - **Upstream addon bug** -> add with `category: addon-upstream-bug`, file
     an upstream report, and plan a fix.

8. Commit updated `accepted-errors.yaml` and push.

---

## Error entry format

```yaml
- file: ArcUI_SomeFile.lua          # repo-relative path of the originating file
  signature: "error message text"   # normalised message (no timestamp, no line number)
  category: wowless-bug             # wowless-bug | addon-upstream-bug | addon-fork-bug
  acceptedOnBuild: "67823"          # must equal current _G.WowlessData.Build.build
  acceptedOnVersion: "12.0.5"       # human-readable companion to build number
  note: >
    Short rationale and root cause.
  upstreamRef: ""                   # link to upstream issue if any
```

**Signature normalisation** (applied by `match-errors.py`):
- Leading `[timestamp]` prefix stripped.
- `file.lua:LINE:` prefix stripped (file captured separately; line number excluded
  so cosmetic edits don't churn the baseline).
- `0x[0-9a-fA-F]+` replaced with `0xADDR`.
- Container mount prefix stripped to produce a repo-relative file path.
