#!/usr/bin/env python3
"""
Wowless error matcher for ArcUI CI.

Parses wowless run output, normalises error signatures, and compares them
against tools/wowless-ci/accepted-errors.yaml.  Three invariants are enforced:

  1. Unexpected error   — a signature in the observed output with no accepted entry.
  2. Stale acceptance   — an accepted entry stamped to a different build than current.
  3. Vanished acceptance — an accepted entry stamped to the current build but absent
                          from the observed output.

Also checks for ARCTEST_OK / ARCTEST_FAIL sentinels emitted by ArcUI_ForkTest.lua.

Usage:
  python3 matcher.py \\
    --output   /tmp/wowless-output.txt \\
    --baseline tools/wowless-ci/accepted-errors.yaml \\
    --build-lua wowless/build/products/wow/WowlessData/build.lua \\
    --addon-root /abs/path/to/arcui-in-wowless
"""

import argparse
import re
import sys
from pathlib import Path

import yaml


# ── output parsing ─────────────────────────────────────────────────────────────

# Matches a wowless error line containing an absolute Lua file path.
# Handles several prefix formats wowless may emit:
#   [2026-05-26 12:00:00] /workspaces/.../ArcUI/Foo.lua:12: bad arg
#   error: /workspaces/.../ArcUI/Foo.lua:12: bad arg
#   /workspaces/.../ArcUI/Foo.lua:12: bad arg
_LINE_RE = re.compile(
    r"(?:\[\S+\s+\S+\]\s+)?"           # optional [date time]
    r"(?:error:\s*)?"                   # optional "error: " prefix
    r"((?:/[^:\n]+|[A-Za-z]:[^:\n]+)"  # absolute path (Unix or Windows)
    r"\.lua)"                           # must end in .lua
    r":\d+"                             # :line_number
    r":\s*(.*)"                         # : message
)

# Stack-traceback continuation lines — skip them for signature extraction.
_TRACEBACK_RE = re.compile(r"^\s+")
_TRACEBACK_HEADER_RE = re.compile(r"^stack traceback:")


def _normalise_message(msg: str, addon_root_prefix: str = "") -> str:
    """Apply normalisation rules from the issue spec."""
    # Collapse any embedded container paths to repo-relative (e.g. in
    # nested error strings: "/abs/path/ArcUI/CDM_Module/Foo.lua:12: ...")
    if addon_root_prefix:
        msg = msg.replace(addon_root_prefix, "")
        msg = msg.replace(addon_root_prefix.replace("/", "\\"), "")
    # Replace hex addresses.
    msg = re.sub(r"0x[0-9a-fA-F]+", "0xADDR", msg)
    # Strip :NNN line-number references embedded within the message text.
    msg = re.sub(r"\.lua:\d+", ".lua", msg)
    return msg.strip()


def parse_errors(output_text: str, addon_root: str):
    """Return (sentinels, regular_errors) where each item is (file, signature)."""
    # Normalise the addon root to a consistent slash-terminated form.
    root = addon_root.rstrip("/\\") + "/"
    # Also accept the backslash variant (Windows paths inside the container).
    root_bs = root.replace("/", "\\")

    sentinels = []
    regular = []

    for line in output_text.splitlines():
        if _TRACEBACK_HEADER_RE.match(line) or _TRACEBACK_RE.match(line):
            continue

        m = _LINE_RE.match(line)
        if not m:
            continue

        raw_file, raw_msg = m.group(1), m.group(2)

        # Collapse container path to repo-relative.
        rel = raw_file
        for prefix in (root, root_bs):
            if rel.startswith(prefix):
                rel = rel[len(prefix):]
                break
            if rel.lower().startswith(prefix.lower()):
                rel = rel[len(prefix):]
                break
        # Normalise Windows separators.
        rel = rel.replace("\\", "/")

        sig = _normalise_message(raw_msg, root)
        entry = (rel, sig)

        if "ARCTEST_OK" in sig or "ARCTEST_FAIL" in sig:
            sentinels.append(entry)
        else:
            regular.append(entry)

    return sentinels, regular


# ── build-number extraction ────────────────────────────────────────────────────

_BUILD_RE = re.compile(r'build\s*=\s*["\'](\d+)["\']')
_VERSION_RE = re.compile(r'version\s*=\s*["\']([^"\']+)["\']')


def read_build(build_lua: str):
    """Return (build_number, version) from WowlessData/build.lua."""
    text = Path(build_lua).read_text()
    b = _BUILD_RE.search(text)
    v = _VERSION_RE.search(text)
    if not b:
        sys.exit(f"ERROR: could not extract build number from {build_lua}")
    return b.group(1), (v.group(1) if v else "unknown")


# ── baseline loading ───────────────────────────────────────────────────────────

def load_baseline(baseline_path: str):
    """Return list of accepted-error dicts from YAML."""
    with open(baseline_path) as fh:
        data = yaml.safe_load(fh)
    return data or []


# ── invariant checks ──────────────────────────────────────────────────────────

def check_sentinels(sentinels):
    """Return list of failure strings for ARCTEST sentinel violations."""
    failures = []
    ok_seen = any("ARCTEST_OK" in sig for _, sig in sentinels)
    fail_entries = [(f, s) for f, s in sentinels if "ARCTEST_FAIL" in s]

    if not ok_seen:
        failures.append(
            "ARCTEST_OK sentinel not found in wowless output.\n"
            "  → The fork test file (ArcUI_ForkTest.lua) did not run to completion,\n"
            "    or all its assertions failed before reaching the OK sentinel.\n"
            "    Check wowless output for ARCTEST_FAIL lines."
        )

    for f, s in fail_entries:
        failures.append(
            f"ARCTEST_FAIL detected in {f}:\n"
            f"  → {s}\n"
            f"    Fix the assertion in ArcUI_ForkTest.lua."
        )

    return failures


def check_baseline(observed, baseline, current_build):
    """
    Apply the three invariants.  Returns list of failure strings.

    observed  : list of (file, signature) tuples  (already deduplicated)
    baseline  : list of accepted-error dicts
    current_build : str — _G.WowlessData.Build.build
    """
    failures = []

    # Build lookup sets.
    obs_set = set(observed)
    acc_map = {}  # (file, sig) → entry dict
    for entry in baseline:
        key = (entry["file"], entry["signature"])
        acc_map[key] = entry

    # Invariant 1 — Unexpected errors.
    for key in obs_set:
        if key not in acc_map:
            f, s = key
            failures.append(
                f"UNEXPECTED error in {f}:\n"
                f"  signature: {s!r}\n"
                "  → Triage: if this is a new wowless gap, add an accepted entry with\n"
                "    category: wowless-bug and acceptedOnBuild set to the current build.\n"
                "    If it is a regression in our code, fix the code."
            )

    # Invariant 2 & 3 — Stale and vanished acceptances.
    for key, entry in acc_map.items():
        accepted_build = str(entry.get("acceptedOnBuild", ""))

        if accepted_build != current_build:
            # Invariant 2: stale.
            failures.append(
                f"STALE acceptance in {entry['file']}:\n"
                f"  signature: {entry['signature']!r}\n"
                f"  acceptedOnBuild={accepted_build!r}  current build={current_build!r}\n"
                "  → Re-validate: does this error still reproduce on the current build?\n"
                "    If yes: update acceptedOnBuild (and acceptedOnVersion) to the current\n"
                "    build and re-run.  If no: remove the entry."
            )
        else:
            # Invariant 3: vanished (only check when build matches).
            if key not in obs_set:
                failures.append(
                    f"VANISHED acceptance in {entry['file']}:\n"
                    f"  signature: {entry['signature']!r}\n"
                    "  → This error no longer reproduces on build "
                    f"{current_build!r}.\n"
                    "    Remove the accepted entry and understand why it disappeared\n"
                    "    (upstream wowless fix? upstream addon change? our patch?)."
                )

    return failures


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Match wowless errors against baseline.")
    ap.add_argument("--output",    required=True, help="Path to captured wowless stdout+stderr")
    ap.add_argument("--baseline",  required=True, help="Path to accepted-errors.yaml")
    ap.add_argument("--build-lua", required=True, help="Path to WowlessData/build.lua")
    ap.add_argument("--addon-root", required=True,
                    help="Absolute path where ArcUI was staged inside wowless "
                         "(used to strip container prefix from error paths)")
    args = ap.parse_args()

    output_text = Path(args.output).read_text(errors="replace")
    current_build, current_version = read_build(args.build_lua)
    baseline = load_baseline(args.baseline)

    print(f"Current WoW build: {current_version} / {current_build}")

    sentinels, regular = parse_errors(output_text, args.addon_root)

    # Deduplicate regular errors (same file+sig may appear multiple times).
    regular_deduped = list(dict.fromkeys(regular))

    print(f"Observed errors (deduplicated): {len(regular_deduped)}")
    print(f"Accepted entries in baseline:   {len(baseline)}")
    print(f"Test sentinels found:           {len(sentinels)}")
    print()

    all_failures = []
    all_failures.extend(check_sentinels(sentinels))
    all_failures.extend(check_baseline(regular_deduped, baseline, current_build))

    if all_failures:
        print(f"{'='*60}")
        print(f"CI FAILED — {len(all_failures)} issue(s) found:")
        print(f"{'='*60}")
        for i, msg in enumerate(all_failures, 1):
            print(f"\n[{i}] {msg}")
        sys.exit(1)
    else:
        print("All checks passed.")
        print(f"  ✓ ARCTEST_OK received")
        print(f"  ✓ No unexpected errors")
        print(f"  ✓ No stale acceptances")
        print(f"  ✓ No vanished acceptances")


if __name__ == "__main__":
    main()
