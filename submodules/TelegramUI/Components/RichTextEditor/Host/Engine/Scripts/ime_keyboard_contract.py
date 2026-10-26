#!/usr/bin/env python3

import argparse
import json
import pathlib
import re
import subprocess
from collections import namedtuple


PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
EXPECTED_LANGUAGES = [
    "japanese-romaji",
    "simplified-chinese-pinyin",
]
EXPECTED_IDENTIFIERS = [
    "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
    "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
]
EXPECTED_PRIMARY_LANGUAGES = ["ja-JP", "zh-Hans"]
FIXED_FALLBACK_IDENTIFIER = "en_AU@sw=QWERTY;hw=Automatic"

CommandResult = namedtuple("CommandResult", "returncode stdout stderr")


class ContractError(AssertionError):
    pass


def _exact_keys(value, expected, context):
    if not isinstance(value, dict):
        raise ContractError(f"{context} must be an object")
    actual = set(value)
    expected = set(expected)
    if actual != expected:
        raise ContractError(
            f"{context} keys differ: missing={sorted(expected - actual)} "
            f"extra={sorted(actual - expected)}"
        )


def _nonempty_string(value, context):
    if not isinstance(value, str) or not value:
        raise ContractError(f"{context} must be a nonempty string")


def validate_contract(payload):
    _exact_keys(
        payload,
        ["schema", "runtime", "preferenceContract", "inputModes"],
        "contract",
    )
    if isinstance(payload["schema"], bool) or payload["schema"] != 1:
        raise ContractError("contract.schema must be integer 1")

    runtime = payload["runtime"]
    _exact_keys(runtime, ["osVersion", "osBuild"], "contract.runtime")
    if runtime != {"osVersion": "26.5", "osBuild": "23F73"}:
        raise ContractError("contract.runtime must equal iOS 26.5 (23F73)")

    preference = payload["preferenceContract"]
    _exact_keys(
        preference,
        [
            "owner",
            "readerSelector",
            "preferencesControllerSelector",
            "fixedHostFallbackIdentifier",
            "postRebootAllowedIdentifiers",
            "preferenceDomain",
            "preferenceKey",
            "expandedPreferenceKey",
            "dataShape",
            "changeNotification",
            "serviceRefresh",
        ],
        "contract.preferenceContract",
    )
    expected_preference = {
        "owner": "UIKeyboardInputModeController",
        "readerSelector": "enabledInputModeIdentifiers:",
        "preferencesControllerSelector": "sharedPreferencesController",
        "fixedHostFallbackIdentifier": FIXED_FALLBACK_IDENTIFIER,
        "postRebootAllowedIdentifiers": [
            "ru_RU@sw=Russian;hw=Automatic",
            "en_AU@sw=QWERTY;hw=Automatic",
        ],
        "preferenceDomain": "NSGlobalDomain",
        "preferenceKey": "AppleKeyboards",
        "expandedPreferenceKey": "AppleKeyboardsExpanded",
        "dataShape": "array<string>",
        "changeNotification": "AppleKeyboardsPreferencesChangedNotification",
        "serviceRefresh":
            "simulator-reboot-then-live-preference-notification-and-"
            "keyboard-service-restart",
    }
    if preference != expected_preference:
        raise ContractError("contract.preferenceContract differs from evidence")

    modes = payload["inputModes"]
    if not isinstance(modes, list) or len(modes) != 2:
        raise ContractError("contract.inputModes must contain exactly two modes")
    actual_languages = []
    actual_identifiers = []
    actual_primary_languages = []
    for index, mode in enumerate(modes):
        _exact_keys(
            mode,
            ["language", "inputModeIdentifier", "primaryLanguage"],
            f"contract.inputModes[{index}]",
        )
        for key in ["language", "inputModeIdentifier", "primaryLanguage"]:
            _nonempty_string(mode[key], f"contract.inputModes[{index}].{key}")
        actual_languages.append(mode["language"])
        actual_identifiers.append(mode["inputModeIdentifier"])
        actual_primary_languages.append(mode["primaryLanguage"])
    if actual_languages != EXPECTED_LANGUAGES:
        raise ContractError("contract input-mode languages differ from evidence")
    if actual_identifiers != EXPECTED_IDENTIFIERS:
        raise ContractError("contract input-mode identifiers differ from evidence")
    if actual_primary_languages != EXPECTED_PRIMARY_LANGUAGES:
        raise ContractError("contract primary languages differ from evidence")
    return payload


def load_contract(path):
    try:
        payload = json.loads(pathlib.Path(path).read_text())
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ContractError(f"cannot load keyboard contract: {error}") from error
    return validate_contract(payload)


def validate_simulator_metadata(contract, metadata):
    _exact_keys(metadata, ["udid", "osVersion", "osBuild"], "metadata")
    if metadata["udid"] != PINNED_UDID:
        raise ContractError(
            f"simulator UDID must equal pinned K3 {PINNED_UDID}"
        )
    runtime = contract["runtime"]
    if metadata["osVersion"] != runtime["osVersion"]:
        raise ContractError("simulator OS version differs from contract")
    if metadata["osBuild"] != runtime["osBuild"]:
        raise ContractError("simulator OS build differs from contract")


def provisioning_plan(contract, udid):
    validate_contract(contract)
    if udid != PINNED_UDID:
        raise ContractError(f"refusing non-K3 simulator {udid}")
    preference = contract["preferenceContract"]
    identifiers = [
        mode["inputModeIdentifier"] for mode in contract["inputModes"]
    ] + [preference["fixedHostFallbackIdentifier"]]
    simctl = ["xcrun", "simctl"]
    write_inventory = simctl + [
        "spawn", udid, "defaults", "write",
        preference["preferenceDomain"], preference["preferenceKey"],
        "-array",
    ] + identifiers
    return [
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_VERSION"],
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_BUILD_VERSION"],
        write_inventory,
        simctl + [
            "spawn", udid, "defaults", "write",
            preference["preferenceDomain"],
            preference["expandedPreferenceKey"], "-bool", "YES",
        ],
        simctl + ["shutdown", udid],
        simctl + ["boot", udid],
        simctl + ["bootstatus", udid, "-b"],
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_VERSION"],
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_BUILD_VERSION"],
        write_inventory,
        simctl + [
            "spawn", udid, "notifyutil", "-p",
            preference["changeNotification"],
        ],
        simctl + [
            "spawn", udid, "launchctl", "kickstart", "-k",
            "user/501/com.apple.TextInput.kbd",
        ],
        simctl + [
            "spawn", udid, "defaults", "read",
            preference["preferenceDomain"], preference["preferenceKey"],
        ],
    ]


def live_provisioning_plan(contract, udid):
    validate_contract(contract)
    if udid != PINNED_UDID:
        raise ContractError(f"refusing non-K3 simulator {udid}")
    preference = contract["preferenceContract"]
    identifiers = [
        mode["inputModeIdentifier"] for mode in contract["inputModes"]
    ] + [preference.get(
        "fixedHostFallbackIdentifier",
        preference["postRebootAllowedIdentifiers"][-1],
    )]
    simctl = ["xcrun", "simctl"]
    return [
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_VERSION"],
        simctl + ["getenv", udid, "SIMULATOR_RUNTIME_BUILD_VERSION"],
        simctl + [
            "spawn", udid, "defaults", "write",
            preference["preferenceDomain"], preference["preferenceKey"],
            "-array", *identifiers,
        ],
        simctl + [
            "spawn", udid, "defaults", "write",
            preference["preferenceDomain"],
            preference["expandedPreferenceKey"], "-bool", "YES",
        ],
        simctl + [
            "spawn", udid, "notifyutil", "-p",
            preference["changeNotification"],
        ],
        simctl + [
            "spawn", udid, "defaults", "read",
            preference["preferenceDomain"], preference["preferenceKey"],
        ],
    ]


def parse_defaults_array(output):
    if not isinstance(output, str):
        raise ContractError("defaults output must be text")
    lines = output.splitlines()
    if len(lines) < 2 or lines[0].strip() != "(" or lines[-1].strip() != ")":
        raise ContractError("defaults output is not an array")
    result = []
    item_pattern = re.compile(r'^\s*"((?:\\.|[^"])*)",?\s*$')
    for line in lines[1:-1]:
        match = item_pattern.match(line)
        if match is None:
            raise ContractError(f"malformed defaults array item: {line!r}")
        try:
            decoded = json.loads(f'"{match.group(1)}"')
        except json.JSONDecodeError as error:
            raise ContractError("invalid escape in defaults array") from error
        if not decoded:
            raise ContractError("defaults array contains an empty identifier")
        result.append(decoded)
    if not result:
        raise ContractError("defaults array must not be empty")
    return result


def verify_inventory(contract, inventory):
    validate_contract(contract)
    if not isinstance(inventory, list) or any(
        not isinstance(item, str) for item in inventory
    ):
        raise ContractError("inventory must be an array of strings")
    expected = [
        mode["inputModeIdentifier"] for mode in contract["inputModes"]
    ] + [
        contract["preferenceContract"]["fixedHostFallbackIdentifier"]
    ]
    if inventory != expected:
        raise ContractError(
            f"enabled input-mode inventory differs after post-reboot "
            f"normalization: expected={expected!r} actual={inventory!r}"
        )


def _default_runner(command):
    completed = subprocess.run(
        command, text=True, capture_output=True, check=False
    )
    return CommandResult(
        completed.returncode, completed.stdout, completed.stderr
    )


def _write_json_atomic(path, value):
    temporary = path.with_name(f".{path.name}.partial")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def live_provision(contract, udid, output, runner=_default_runner):
    output = pathlib.Path(output)
    if output.exists():
        raise ContractError(f"refusing existing evidence path: {output}")
    plan = live_provisioning_plan(contract, udid)
    output.mkdir(parents=True)

    records = []
    results = []
    for command in plan:
        result = runner(command)
        if not isinstance(result, CommandResult):
            raise ContractError("command runner returned the wrong result type")
        results.append(result)
        records.append({
            "argv": command,
            "exitCode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        })
        _write_json_atomic(output / "commands.json", records)
        if result.returncode != 0:
            raise ContractError(
                f"live provisioning command failed ({result.returncode}): "
                f"{command!r}"
            )

    metadata = {
        "udid": udid,
        "osVersion": results[0].stdout.strip(),
        "osBuild": results[1].stdout.strip(),
    }
    validate_simulator_metadata(contract, metadata)
    inventory = parse_defaults_array(results[5].stdout)
    verify_inventory(contract, inventory)
    summary = {
        "schema": 1,
        "udid": udid,
        "runtime": {
            "osVersion": metadata["osVersion"],
            "osBuild": metadata["osBuild"],
        },
        "inventory": inventory,
        "primaryLanguages": [
            mode["primaryLanguage"] for mode in contract["inputModes"]
        ],
        "mode": "live-no-reboot",
        "commandCount": len(plan),
    }
    _write_json_atomic(output / "summary.json", summary)
    return summary


def provision(contract, udid, output, runner=_default_runner):
    output = pathlib.Path(output)
    if output.exists():
        raise ContractError(f"refusing existing evidence path: {output}")
    output.mkdir(parents=True)

    plan = provisioning_plan(contract, udid)
    records = []
    results = []
    for command in plan:
        result = runner(command)
        if not isinstance(result, CommandResult):
            raise ContractError("command runner returned the wrong result type")
        results.append(result)
        records.append({
            "argv": command,
            "exitCode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        })
        (output / "commands.json").write_text(
            json.dumps(records, indent=2, sort_keys=True) + "\n"
        )
        if result.returncode != 0:
            raise ContractError(
                f"provisioning command failed ({result.returncode}): "
                f"{command!r}"
            )

    before = {
        "udid": udid,
        "osVersion": results[0].stdout.strip(),
        "osBuild": results[1].stdout.strip(),
    }
    after = {
        "udid": udid,
        "osVersion": results[7].stdout.strip(),
        "osBuild": results[8].stdout.strip(),
    }
    validate_simulator_metadata(contract, before)
    validate_simulator_metadata(contract, after)
    inventory = parse_defaults_array(results[12].stdout)
    verify_inventory(contract, inventory)
    summary = {
        "schema": 1,
        "udid": udid,
        "runtime": {
            "osVersion": after["osVersion"],
            "osBuild": after["osBuild"],
        },
        "inventory": inventory,
        "primaryLanguages": [
            mode["primaryLanguage"] for mode in contract["inputModes"]
        ],
        "commandCount": len(plan),
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n"
    )
    return summary


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--contract", required=True, type=pathlib.Path)

    plan_parser = subparsers.add_parser("plan")
    plan_parser.add_argument("--contract", required=True, type=pathlib.Path)
    plan_parser.add_argument("--udid", required=True)

    provision_parser = subparsers.add_parser("provision")
    provision_parser.add_argument(
        "--contract", required=True, type=pathlib.Path
    )
    provision_parser.add_argument("--udid", required=True)
    provision_parser.add_argument("--output", required=True, type=pathlib.Path)

    arguments = parser.parse_args()
    contract = load_contract(arguments.contract)
    if arguments.command == "validate":
        print(json.dumps(contract, indent=2, sort_keys=True))
    elif arguments.command == "plan":
        print(json.dumps(
            provisioning_plan(contract, arguments.udid),
            indent=2,
        ))
    else:
        print(json.dumps(
            provision(contract, arguments.udid, arguments.output),
            indent=2,
            sort_keys=True,
        ))


if __name__ == "__main__":
    main()
