#!/usr/bin/env python3

import argparse
import importlib.util
import json
import os
import pathlib
import plistlib
import re
import subprocess
import sys
import time


PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
RUNTIME = {"osVersion": "26.5", "osBuild": "23F73"}
CUSTOM_BUNDLE = "com.inputdec.demo"
STOCK_BUNDLE = "com.inputdec.stockoracle"
KEYBOARD_SERVICE = "user/501/com.apple.TextInput.kbd"
SCRIPT_ROOT = pathlib.Path(__file__).resolve().parent
CONTRACT_PATH = (
    SCRIPT_ROOT.parent / "UITests" / "Fixtures" /
    "ime-keyboard-modes-ios26.5-v1.json"
)


class BoundaryResetError(RuntimeError):
    pass


def _load_module(name, path):
    specification = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


RESET_MODULE = _load_module(
    "inputdec_reset_text_input_learning",
    SCRIPT_ROOT / "reset-text-input-learning.py",
)
KEYBOARD_MODULE = _load_module(
    "inputdec_ime_keyboard_contract",
    SCRIPT_ROOT / "ime_keyboard_contract.py",
)
BATCH_MODULE = _load_module(
    "inputdec_text_input_batch",
    SCRIPT_ROOT / "text_input_batch.py",
)


def _write_json_atomic(path, value):
    temporary = path.with_name(f".{path.name}.partial")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def _invoke(runner, command, input_text=None):
    try:
        arguments = {
            "text": True,
            "capture_output": True,
            "check": False,
        }
        if input_text is not None:
            arguments["input"] = input_text
        result = runner(command, **arguments)
    except TypeError:
        result = runner(command)
    if not all(hasattr(result, name) for name in (
        "returncode", "stdout", "stderr",
    )):
        raise BoundaryResetError("command runner returned an invalid result")
    return result


def _run_recorded(runner, command, records, input_text=None):
    started = time.monotonic()
    result = _invoke(runner, command, input_text=input_text)
    records.append({
        "argv": command,
        "exitCode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "elapsedSeconds": time.monotonic() - started,
    })
    return result


def _require_result(result, command, accepted=(0,)):
    if result.returncode not in accepted:
        raise BoundaryResetError(
            f"boundary command failed ({result.returncode}): {command!r}"
        )


def _require_clean_post_state(post_state, provisioning):
    expected_counts = {
        "rejections": 0,
        "inline_completion_rejections": 0,
    }
    if post_state.get("rejectionTableCounts") != expected_counts:
        raise BoundaryResetError("text-input rejection learning is not empty")
    if post_state.get("dynamicLexicons") != []:
        raise BoundaryResetError("text-input dynamic lexicons are not empty")
    if (post_state.get("enabledInputModeIdentifiers") !=
            provisioning.get("inventory")):
        raise BoundaryResetError("post-state keyboard inventory differs")


def _load_snapshot_inputs(keyboard_snapshot, identity):
    if (keyboard_snapshot is None) != (identity is None):
        raise BoundaryResetError(
            "keyboard snapshot and identity must be provided together"
        )
    if keyboard_snapshot is None:
        return None, None, None
    keyboard_snapshot = pathlib.Path(keyboard_snapshot).expanduser()
    identity = pathlib.Path(identity).expanduser()
    if (keyboard_snapshot.is_symlink() or
            not keyboard_snapshot.is_dir()):
        raise BoundaryResetError("refusing invalid keyboard snapshot")
    if identity.is_symlink() or not identity.is_file():
        raise BoundaryResetError("refusing invalid keyboard identity")
    try:
        identity_value = json.loads(identity.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise BoundaryResetError(
            f"refusing invalid keyboard identity: {error}"
        ) from error
    if (not isinstance(identity_value, dict) or
            not isinstance(identity_value.get("inputModes"), list) or
            not all(isinstance(value, str)
                    for value in identity_value["inputModes"])):
        raise BoundaryResetError("refusing invalid keyboard identity schema")
    return keyboard_snapshot.resolve(), identity.resolve(), identity_value


def _validate_restore_summary(summary, expected_identity):
    expected_keys = {
        "schema", "result", "identity", "roots",
        "baselineManifestSHA256", "restoredManifestSHA256",
    }
    if not isinstance(summary, dict) or set(summary) != expected_keys:
        raise BoundaryResetError("keyboard restore summary schema differs")
    if summary["schema"] != 1 or summary["result"] != "restored":
        raise BoundaryResetError("keyboard restore did not report success")
    if summary["identity"] != expected_identity:
        raise BoundaryResetError("keyboard restore identity differs")
    if (not isinstance(summary["roots"], list) or
            not summary["roots"] or
            not all(isinstance(root, str) and root
                    for root in summary["roots"])):
        raise BoundaryResetError("keyboard restore roots are invalid")
    baseline = summary["baselineManifestSHA256"]
    restored = summary["restoredManifestSHA256"]
    if (not isinstance(baseline, str) or
            re.fullmatch(r"[0-9a-f]{64}", baseline) is None or
            restored != baseline):
        raise BoundaryResetError("keyboard restore manifest hash differs")


def _snapshot_keyboard_preferences_xml(keyboard_snapshot):
    relative_path = pathlib.Path(
        "tree/Library/Preferences/com.apple.keyboard.preferences.plist"
    )
    preferences = keyboard_snapshot / relative_path
    if preferences.is_symlink() or not preferences.is_file():
        raise BoundaryResetError(
            "keyboard snapshot lacks exact keyboard preferences"
        )
    try:
        value = plistlib.loads(preferences.read_bytes())
    except (OSError, plistlib.InvalidFileException) as error:
        raise BoundaryResetError(
            f"keyboard snapshot preferences are invalid: {error}"
        ) from error
    if not isinstance(value, dict):
        raise BoundaryResetError(
            "keyboard snapshot preferences are not a dictionary"
        )
    return plistlib.dumps(value, fmt=plistlib.FMT_XML).decode("utf-8")


def run_boundary_reset(
        udid, device_root, output, runner=subprocess.run,
        keyboard_snapshot=None, identity=None):
    if udid != PINNED_UDID:
        raise BoundaryResetError(f"refusing non-K3 simulator: {udid}")
    device_root = pathlib.Path(device_root).expanduser()
    if (device_root.is_symlink() or not device_root.exists() or
            not device_root.is_dir()):
        raise BoundaryResetError("refusing invalid simulator device root")
    device_root = device_root.resolve()
    keyboard_snapshot, identity, identity_value = _load_snapshot_inputs(
        keyboard_snapshot, identity
    )
    snapshot_restore = keyboard_snapshot is not None
    output = pathlib.Path(output)
    if output.exists() or output.is_symlink():
        raise BoundaryResetError(f"refusing existing output: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = output.with_name(f".{output.name}.partial-{os.getpid()}")
    if staging.exists() or staging.is_symlink():
        raise BoundaryResetError(f"refusing existing staging path: {staging}")
    staging.mkdir()

    records = []
    started = time.monotonic()
    phases = {}

    def recorded(command, input_text=None):
        return _run_recorded(
            runner, command, records, input_text=input_text
        )

    terminate_commands = [
        ["xcrun", "simctl", "terminate", udid, CUSTOM_BUNDLE],
        ["xcrun", "simctl", "terminate", udid, STOCK_BUNDLE],
    ]
    phase_started = time.monotonic()
    for command in terminate_commands:
        _require_result(recorded(command), command, accepted=(0, 3))
    phases["terminateSeconds"] = time.monotonic() - phase_started

    disable_command = [
        "xcrun", "simctl", "spawn", udid, "launchctl", "disable",
        KEYBOARD_SERVICE,
    ]
    kill_command = [
        "xcrun", "simctl", "spawn", udid, "launchctl", "kill", "SIGKILL",
        KEYBOARD_SERVICE,
    ]
    enable_command = [
        "xcrun", "simctl", "spawn", udid, "launchctl", "enable",
        KEYBOARD_SERVICE,
    ]
    kickstart_command = [
        "xcrun", "simctl", "spawn", udid, "launchctl", "kickstart", "-k",
        KEYBOARD_SERVICE,
    ]

    phase_started = time.monotonic()
    _require_result(recorded(disable_command), disable_command)
    restart_needed = True
    learning = None
    provisioning = None
    restore_summary = None
    primary_error = None
    try:
        _require_result(recorded(kill_command), kill_command)
        phases["suspendKeyboardSeconds"] = time.monotonic() - phase_started

        if snapshot_restore:
            phase_started = time.monotonic()
            restore_command = [
                sys.executable,
                str(SCRIPT_ROOT / "text_input_keyboard_snapshot.py"),
                "restore",
                "--device-root", str(device_root),
                "--snapshot", str(keyboard_snapshot),
                "--identity", str(identity),
                "--output", str(staging / "snapshot-restore"),
            ]
            _require_result(recorded(restore_command), restore_command)
            preferences_xml = _snapshot_keyboard_preferences_xml(
                keyboard_snapshot
            )
            delete_preferences_command = [
                "xcrun", "simctl", "spawn", udid, "defaults", "delete",
                "com.apple.keyboard.preferences",
            ]
            import_preferences_command = [
                "xcrun", "simctl", "spawn", udid, "defaults", "import",
                "com.apple.keyboard.preferences", "-",
            ]
            _require_result(
                recorded(delete_preferences_command),
                delete_preferences_command,
                accepted=(0, 1),
            )
            _require_result(
                recorded(import_preferences_command,
                         input_text=preferences_xml),
                import_preferences_command,
            )
            phases["snapshotRestoreSeconds"] = (
                time.monotonic() - phase_started
            )
        else:
            phase_started = time.monotonic()
            learning = RESET_MODULE.reset(
                udid, device_root, staging / "learning-reset"
            )
            phases["learningResetSeconds"] = (
                time.monotonic() - phase_started
            )

            contract = KEYBOARD_MODULE.load_contract(CONTRACT_PATH)

            def provisioning_runner(command):
                result = recorded(command)
                return KEYBOARD_MODULE.CommandResult(
                    result.returncode, result.stdout, result.stderr
                )

            phase_started = time.monotonic()
            provisioning = KEYBOARD_MODULE.live_provision(
                contract,
                udid,
                staging / "provisioning",
                runner=provisioning_runner,
            )
            phases["provisioningSeconds"] = time.monotonic() - phase_started
    except Exception as error:
        primary_error = error
    finally:
        if restart_needed:
            phase_started = time.monotonic()
            try:
                _require_result(recorded(enable_command), enable_command)
                _require_result(recorded(kickstart_command), kickstart_command)
                phases["restartKeyboardSeconds"] = (
                    time.monotonic() - phase_started
                )
            except Exception as restart_error:
                if primary_error is None:
                    primary_error = restart_error
                else:
                    primary_error = BoundaryResetError(
                        f"boundary reset failed and keyboard restart failed: "
                        f"{primary_error}; {restart_error}"
                    )
    if primary_error is None and snapshot_restore:
        phase_started = time.monotonic()
        try:
            inventory_command = [
                "xcrun", "simctl", "spawn", udid, "defaults", "write",
                "NSGlobalDomain", "AppleKeyboards", "-array",
                *identity_value["inputModes"],
            ]
            notification_command = [
                "xcrun", "simctl", "spawn", udid, "notifyutil", "-p",
                "AppleKeyboardsPreferencesChangedNotification",
            ]
            _require_result(recorded(inventory_command), inventory_command)
            _require_result(recorded(notification_command),
                            notification_command)
            phases["inventoryRestoreSeconds"] = (
                time.monotonic() - phase_started
            )
        except Exception as error:
            primary_error = error
    _write_json_atomic(staging / "commands.json", records)
    if primary_error is not None:
        raise primary_error

    if snapshot_restore:
        phase_started = time.monotonic()
        probe_command = [
            "xcrun", "simctl", "spawn", udid, "defaults", "read",
            "NSGlobalDomain", "AppleKeyboards",
        ]
        probe = recorded(probe_command)
        _require_result(probe, probe_command)
        inventory = KEYBOARD_MODULE.parse_defaults_array(probe.stdout)
        if inventory != identity_value["inputModes"]:
            raise BoundaryResetError(
                "restored keyboard inventory differs from snapshot identity"
            )
        restore_summary_path = staging / "snapshot-restore" / "summary.json"
        try:
            restore_summary = json.loads(
                restore_summary_path.read_text(encoding="utf-8")
            )
        except (OSError, json.JSONDecodeError) as error:
            raise BoundaryResetError(
                f"keyboard restore summary is invalid: {error}"
            ) from error
        _validate_restore_summary(restore_summary, identity_value)
        phases["verifySnapshotSeconds"] = time.monotonic() - phase_started
        phases["totalSeconds"] = time.monotonic() - started
        _write_json_atomic(staging / "commands.json", records)
        _write_json_atomic(staging / "timing.json", {"schema": 1, **phases})
        _write_json_atomic(staging / "summary.json", restore_summary)
        staging.replace(output)
        return restore_summary

    phase_started = time.monotonic()
    post_state = BATCH_MODULE.fingerprint(
        udid,
        device_root,
        staging / "provisioning" / "summary.json",
        staging / "post-state.json",
    )
    _require_clean_post_state(post_state, provisioning)
    phases["fingerprintSeconds"] = time.monotonic() - phase_started
    phases["totalSeconds"] = time.monotonic() - started
    timing = {"schema": 1, **phases}
    _write_json_atomic(staging / "timing.json", timing)

    summary = {
        "schema": 1,
        "runtime": RUNTIME,
        "udid": udid,
        "learning": learning,
        "provisioning": provisioning,
        "postState": post_state,
        "result": "Passed",
    }
    _write_json_atomic(staging / "summary.json", summary)
    staging.replace(output)
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--device-root", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--keyboard-snapshot", type=pathlib.Path)
    parser.add_argument("--identity", type=pathlib.Path)
    arguments = parser.parse_args()
    try:
        summary = run_boundary_reset(
            arguments.udid, arguments.device_root, arguments.output,
            keyboard_snapshot=arguments.keyboard_snapshot,
            identity=arguments.identity,
        )
    except (BoundaryResetError, OSError, ValueError) as error:
        raise SystemExit(f"text-input live boundary reset failed: {error}")
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
