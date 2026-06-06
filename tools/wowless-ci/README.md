# Wowless CI harness

ArcUI is tested under [wowless](https://github.com/wowless/wowless) — a headless WoW Lua/FrameXML interpreter — to catch load-time and runtime regressions without a game client.

## How CI works

1. The workflow clones and builds the **latest** wowless (no pinning), downloads the live retail client data via TACT, and runs ArcUI through the simulated client.
2. `matcher.py` parses the captured output, normalises error signatures, and checks them against `accepted-errors.yaml`.
3. `ArcUI_ForkTest.lua` runs positive assertions and emits `ARCTEST_OK` / `ARCTEST_FAIL` sentinels (surfaced via wowless's error channel).

CI fails if:
- **Unexpected error** — a new error appears with no accepted entry.
- **Stale acceptance** — an entry is stamped to a different WoW build than the one wowless downloaded.
- **Vanished acceptance** — an entry is stamped to the current build but the error no longer occurs.
- **ARCTEST_OK missing** or **ARCTEST_FAIL present**.

## Re-validating when the WoW build changes

When Blizzard ships a new patch, `_G.WowlessData.Build.build` changes.  Every accepted entry becomes *stale* and CI fails until re-validated.

**Steps:**

1. Trigger a CI run (or reproduce locally — see below) to get the new build number from the output:
   ```
   Current WoW build: 12.0.6 / 68001
   ```

2. For each stale entry, check whether the error still reproduces on the new build:
   - If **yes** (same error, new build): update `acceptedOnBuild` and `acceptedOnVersion`.
   - If **no** (error disappeared): remove the entry.  Understand why — upstream wowless fix, Blizzard API change, or our own patch?

3. If a **new** unexpected error appears, triage it:
   - `wowless-bug`: add an entry with `category: wowless-bug` and the current build number.
   - `addon-upstream-bug` / `addon-fork-bug`: fix the code or add an entry with the appropriate category.

4. Commit the updated `accepted-errors.yaml` together with any code fixes.

## Reproducing locally

```bash
# From repo root — adjust paths as needed.

# 1. Clone and build wowless (once; re-use the checkout for subsequent runs).
git clone https://github.com/wowless/wowless.git /tmp/wowless
cd /tmp/wowless
git submodule update --init --depth 1
cmake --preset default
cmake --build build

# 2. Stage ArcUI (lua/xml/toc only; textures and sounds are skipped).
rsync -a \
  --exclude='.git/' --exclude='.github/' --exclude='tools/' \
  --exclude='Textures/' --exclude='Sounds/' --exclude='CustomTextures/' \
  /path/to/arcui-fork/ /tmp/wowless/addons/ArcUI/

# 3. Run wowless and capture output.
cd /tmp/wowless
bin/run.sh wow --addondir addons 2>&1 | tee /tmp/wowless-output.txt

# 4. Run the matcher.
cd /path/to/arcui-fork
python3 tools/wowless-ci/matcher.py \
  --output /tmp/wowless-output.txt \
  --baseline tools/wowless-ci/accepted-errors.yaml \
  --build-lua /tmp/wowless/build/products/wow/WowlessData/build.lua \
  --addon-root /tmp/wowless/addons/ArcUI
```

## Accepted-error entry format

```yaml
- file: ArcUI_CooldownBars.lua       # repo-relative path of originating Lua file
  signature: "bad argument ..."       # normalised message (no timestamp, no line numbers,
                                      # 0x... → 0xADDR)
  category: wowless-bug               # wowless-bug | addon-upstream-bug | addon-fork-bug
  acceptedOnBuild: "67823"            # must equal current _G.WowlessData.Build.build
  acceptedOnVersion: "12.0.5"         # human-readable version (informational)
  note: >
    Short rationale and root cause.
  upstreamRef: ""                     # upstream issue URL, if any
```

`acceptedOnBuild` is the WoW **build number** (most precise) because schema changes land there, including hotfixes.  If build-number churn becomes too noisy, consider relaxing to `acceptedOnVersion` and updating `matcher.py` accordingly.
