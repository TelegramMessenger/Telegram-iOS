#!/usr/bin/env python3

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys


PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
EXPECTED_RUNTIME = {"osVersion": "26.5", "osBuild": "23F73"}
EXPECTED_PROFILE = {
    "locale": "en_US",
    "languages": ["en-US"],
    "inputModes": ["en_US@hw=Automatic"],
    "inputModesExpanded": True,
}


class ProfileError(RuntimeError):
    pass


def verification_plan(udid):
    if udid != PINNED_UDID:
        raise ProfileError(f"refusing non-K3 simulator: {udid}")
    simctl = ["xcrun", "simctl"]
    return [
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_VERSION"],
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_BUILD_VERSION"],
        simctl + ["spawn", udid, "defaults", "read", "NSGlobalDomain",
                  "AppleLocale"],
        simctl + ["spawn", udid, "defaults", "read", "NSGlobalDomain",
                  "AppleLanguages"],
        simctl + ["spawn", udid, "defaults", "read", "NSGlobalDomain",
                  "AppleKeyboards"],
        simctl + ["spawn", udid, "defaults", "read", "NSGlobalDomain",
                  "AppleKeyboardsExpanded"],
    ]


def _parse_defaults_array(value, field):
    lines = value.splitlines()
    if len(lines) < 2 or lines[0].strip() != "(" or lines[-1].strip() != ")":
        raise ProfileError(f"{field} output is not an array")
    result = []
    pattern = re.compile(r'^\s*"((?:\\.|[^"\\])*)",?\s*$')
    for line in lines[1:-1]:
        match = pattern.fullmatch(line)
        if match is None:
            raise ProfileError(f"{field} contains a malformed item")
        try:
            item = json.loads(f'"{match.group(1)}"')
        except json.JSONDecodeError as error:
            raise ProfileError(f"{field} contains an invalid escape") from error
        if not item:
            raise ProfileError(f"{field} contains an empty item")
        result.append(item)
    if not result:
        raise ProfileError(f"{field} must not be empty")
    return result


def _parse_expanded(value):
    normalized = value.strip().lower()
    if normalized in {"1", "yes", "true"}:
        return True
    if normalized in {"0", "no", "false"}:
        return False
    raise ProfileError("AppleKeyboardsExpanded output is not a Boolean")


def _write_json(path, value):
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def verify_profile(udid, output, runner=subprocess.run):
    plan = verification_plan(udid)
    output = pathlib.Path(output)
    if output.exists() or output.is_symlink():
        raise ProfileError(f"refusing existing evidence path: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = output.with_name(f".{output.name}.partial-{os.getpid()}")
    if staging.exists() or staging.is_symlink():
        raise ProfileError(f"refusing existing staging path: {staging}")
    staging.mkdir()

    records = []
    results = []
    try:
        for command in plan:
            result = runner(
                command, text=True, capture_output=True, check=False
            )
            if not all(hasattr(result, key) for key in (
                "returncode", "stdout", "stderr"
            )):
                raise ProfileError("command runner returned an invalid result")
            records.append({
                "argv": command,
                "exitCode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
            })
            _write_json(staging / "commands.json", records)
            if result.returncode != 0:
                summary = {
                    "schema": 1,
                    "result": "invalid",
                    "udid": udid,
                    "error": f"command failed ({result.returncode}): {command!r}",
                }
                _write_json(staging / "summary.json", summary)
                staging.replace(output)
                raise ProfileError(summary["error"])
            results.append(result.stdout)

        try:
            runtime = {
                "osVersion": results[0].strip(),
                "osBuild": results[1].strip(),
            }
            profile = {
                "locale": results[2].strip(),
                "languages": _parse_defaults_array(
                    results[3], "AppleLanguages"
                ),
                "inputModes": _parse_defaults_array(
                    results[4], "AppleKeyboards"
                ),
                "inputModesExpanded": _parse_expanded(results[5]),
            }
        except ProfileError as error:
            summary = {
                "schema": 1,
                "result": "invalid",
                "udid": udid,
                "error": str(error),
            }
            _write_json(staging / "summary.json", summary)
            staging.replace(output)
            raise

        fields = [
            ("SIMULATOR_RUNTIME_VERSION", runtime["osVersion"], "26.5"),
            ("SIMULATOR_RUNTIME_BUILD_VERSION", runtime["osBuild"], "23F73"),
            ("AppleLocale", profile["locale"], "en_US"),
            ("AppleLanguages", profile["languages"], ["en-US"]),
            ("AppleKeyboards", profile["inputModes"],
             ["en_US@hw=Automatic"]),
            ("AppleKeyboardsExpanded", profile["inputModesExpanded"], True),
        ]
        mismatches = [
            {"field": field, "actual": actual, "expected": expected}
            for field, actual, expected in fields
            if actual != expected
        ]
        if mismatches:
            summary = {
                "schema": 1,
                "result": "mismatch",
                "udid": udid,
                "runtime": runtime,
                "profile": profile,
                "mismatches": mismatches,
            }
            _write_json(staging / "summary.json", summary)
            staging.replace(output)
            raise ProfileError(
                "English-US profile mismatch: " +
                ", ".join(item["field"] for item in mismatches)
            )

        summary = {
            "schema": 1,
            "result": "verified",
            "udid": udid,
            "runtime": runtime,
            "profile": profile,
        }
        _write_json(staging / "summary.json", summary)
        staging.replace(output)
        return summary
    except Exception:
        if staging.exists() and not output.exists():
            staging.replace(output)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    verify = subparsers.add_parser("verify")
    verify.add_argument("--udid", required=True)
    verify.add_argument("--output", required=True, type=pathlib.Path)
    arguments = parser.parse_args(argv)
    try:
        summary = verify_profile(arguments.udid, arguments.output)
    except ProfileError as error:
        print(str(error), file=sys.stderr)
        return 65
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
