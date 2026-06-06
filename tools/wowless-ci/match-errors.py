#!/usr/bin/env python3
"""
Wowless error matcher for ArcUI CI.

Reads the output of a wowless run and compares against the version-bound
accepted-errors.yaml baseline.  Exits non-zero (with actionable messages)
when any of the three invariants are violated:

  1. Unexpected error  — observed signature not in the baseline
  2. Stale acceptance  — baseline entry stamped to a different build
  3. Vanished acceptance — baseline entry absent from the observed output

Also fails if the positive-assertion sentinel ARCTEST_OK is missing, or
if any ARCTEST_FAIL sentinel appears.
"""

import argparse
import re
import sys
import yaml  # pip install pyyaml


# ---------------------------------------------------------------------------
# Build info
# ---------------------------------------------------------------------------

def parse_build_lua(path):
    """
    Parse the WowlessData build.lua file and return (build_number, version).
    Expected format (subset):
        WowlessData.Build = { version = "12.0.5", build = "67823", ... }
    """
    with open(path) as fh:
        content = fh.read()

    build_match = re.search(r'\bbuild\s*=\s*["\'](\d+)["\']', content)
    version_match = re.search(r'\bversion\s*=\s*["\']([^"\']+)["\']', content)

    if not build_match:
        sys.exit("ERROR: Could not parse build number from " + path)

    return build_match.group(1), (version_match.group(1) if version_match else "unknown")


# ---------------------------------------------------------------------------
# Output parsing
# ---------------------------------------------------------------------------

# Matches an error line produced by wowless.
# Formats seen in practice:
#   [TIMESTAMP] /mount/path/to/File.lua:LINE: message
#   /mount/path/to/File.lua:LINE: message
_ERROR_LINE = re.compile(
    r'^(?:\[\d+\]\s*)?'          # optional [timestamp]
    r'((?:[^\s\[\]]+[/\\])?'     # optional directory prefix
    r'[A-Za-z_][^/\\\s:]*\.lua)' # lua filename (no spaces)
    r':(\d+):\s*'                # :LINE:
    r'(.+)$'                     # message
)


def _normalize_path(raw_path, addon_mount):
    """
    Strip the container addon-mount prefix from a path and return the
    repo-relative path (forward-slash normalised), or None when the path is
    outside the mounted addon.
    """
    raw_path = raw_path.replace('\\', '/')
    mount = addon_mount.rstrip('/') + '/'
    if raw_path.startswith(mount):
        return raw_path[len(mount):]
    # Fallback: strip everything up to the first addon-recognisable segment.
    # This handles unexpected mount paths gracefully.
    for marker in ('/ArcUI/', 'ArcUI/', '/addon/', 'addon/'):
        idx = raw_path.find(marker)
        if idx != -1:
            return raw_path[idx + len(marker):]
    return None


def _normalize_message(msg):
    """Apply the spec normalisation rules to an error message."""
    # Replace hex addresses.
    msg = re.sub(r'0x[0-9a-fA-F]+', '0xADDR', msg)
    return msg.strip()


def parse_wowless_output(output_text, addon_mount):
    """
    Parse wowless output into:
      observed  — set of (file, signature) tuples (non-ARCTEST errors)
      arctest_ok — True if ARCTEST_OK sentinel was seen
      arctest_fails — list of ARCTEST_FAIL messages
    """
    observed = set()
    arctest_ok = False
    arctest_fails = []

    for raw_line in output_text.splitlines():
        if raw_line[:1].isspace():
            continue

        line = raw_line.strip()
        if not line:
            continue

        m = _ERROR_LINE.match(line)
        if not m:
            continue

        raw_path, _lineno, msg = m.group(1), m.group(2), m.group(3)
        rel_file = _normalize_path(raw_path, addon_mount)
        if rel_file is None:
            continue

        sig = _normalize_message(msg)

        if 'ARCTEST_OK' in sig:
            arctest_ok = True
            continue
        if 'ARCTEST_FAIL' in sig:
            arctest_fails.append(sig)
            continue

        observed.add((rel_file, sig))

    return observed, arctest_ok, arctest_fails


# ---------------------------------------------------------------------------
# Invariant checking
# ---------------------------------------------------------------------------

def check(output_path, build_lua_path, baseline_path, addon_mount):
    current_build, current_version = parse_build_lua(build_lua_path)
    print(f"WoW client build: {current_build} ({current_version})")

    with open(output_path) as fh:
        output_text = fh.read()

    with open(baseline_path) as fh:
        baseline = yaml.safe_load(fh) or []

    observed, arctest_ok, arctest_fails = parse_wowless_output(output_text, addon_mount)

    failures = []

    # -- ARCTEST sentinels --------------------------------------------------
    if not arctest_ok:
        failures.append(
            "ARCTEST_OK sentinel absent from wowless output.\n"
            "  The fork test file (tools/wowless-ci/ArcUI_ForkTest.lua) did not emit\n"
            "  ARCTEST_OK.  Either the test assertions failed silently, PLAYER_LOGIN\n"
            "  never fired, or the test file was not loaded.  Check wowless output."
        )
    for fail_msg in arctest_fails:
        failures.append(f"Positive assertion failed: {fail_msg}")

    # -- Build accepted-set from baseline -----------------------------------
    accepted = {}  # (file, sig) -> entry
    for entry in baseline:
        key = (entry['file'], entry['signature'])
        accepted[key] = entry

    # -- Invariant 1: unexpected errors (in OBS but not in accepted) --------
    for (rel_file, sig) in sorted(observed):
        if (rel_file, sig) not in accepted:
            failures.append(
                f"Unexpected error (not in baseline) — triage and add to accepted-errors.yaml,\n"
                f"or fix the regression:\n"
                f"  file: {rel_file}\n"
                f"  signature: {sig!r}"
            )

    # -- Invariant 2: stale acceptances (acceptedOnBuild != current build) --
    for (key, entry) in sorted(accepted.items(), key=lambda kv: kv[0]):
        if entry['acceptedOnBuild'] != current_build:
            failures.append(
                f"Stale acceptance — stamped to build {entry['acceptedOnBuild']!r} "
                f"but current build is {current_build!r}.\n"
                f"  Re-run wowless, verify the error still reproduces on build {current_build},\n"
                f"  then update acceptedOnBuild/acceptedOnVersion and commit:\n"
                f"  file: {entry['file']}\n"
                f"  signature: {entry['signature']!r}"
            )

    # -- Invariant 3: vanished acceptances (in accepted but not in OBS) -----
    for (key, entry) in sorted(accepted.items(), key=lambda kv: kv[0]):
        if entry['acceptedOnBuild'] == current_build and key not in observed:
            failures.append(
                f"Vanished acceptance — error no longer observed, remove or investigate:\n"
                f"  file: {entry['file']}\n"
                f"  signature: {entry['signature']!r}\n"
                f"  (If the underlying bug was fixed, remove the entry and note it in the PR.)"
            )

    # -- Report -------------------------------------------------------------
    if failures:
        print(f"\n{'='*70}")
        print(f"WOWLESS CI FAILED — {len(failures)} issue(s):\n")
        for i, msg in enumerate(failures, 1):
            print(f"[{i}] {msg}\n")
        print('='*70)
        sys.exit(1)
    else:
        print(f"Wowless CI passed: {len(observed)} accepted error(s), ARCTEST_OK confirmed.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',      required=True, help='Path to captured wowless output file')
    ap.add_argument('--build-lua',   required=True, help='Path to wowless WowlessData/build.lua')
    ap.add_argument('--baseline',    required=True, help='Path to accepted-errors.yaml')
    ap.add_argument('--addon-mount', default='/addon',
                    help='Container path where the addon was mounted (default: /addon)')
    args = ap.parse_args()
    check(args.output, args.build_lua, args.baseline, args.addon_mount)
