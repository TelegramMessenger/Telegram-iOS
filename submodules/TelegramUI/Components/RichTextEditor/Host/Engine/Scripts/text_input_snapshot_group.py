#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import signal
import subprocess
import sys
import time

import text_input_group_protocol as protocol

PYTHON = os.environ.get("INPUTDEC_PYTHON", "python3")


class SnapshotGroupError(RuntimeError):
    pass


def write_json(path, value):
    temporary = path.with_name(f".{path.name}.partial-{os.getpid()}")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def run(command, **kwargs):
    result = subprocess.run(
        command, text=True, capture_output=True, check=False, **kwargs
    )
    if result.returncode != 0:
        raise SnapshotGroupError(
            f"command failed ({result.returncode}): {command!r}: "
            f"{result.stderr.strip()}"
        )
    return result


def load_snapshot_identity(snapshot):
    manifest_path = snapshot / "manifest.json"
    if snapshot.is_symlink() or not snapshot.is_dir():
        raise SnapshotGroupError("keyboard snapshot is not a regular directory")
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise SnapshotGroupError("keyboard snapshot manifest is missing")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SnapshotGroupError(f"keyboard snapshot manifest is invalid: {error}")
    if (not isinstance(manifest, dict) or
            set(manifest) != {"schema", "identity", "roots", "files", "sqlite"} or
            manifest.get("schema") != 1 or
            not isinstance(manifest.get("identity"), dict)):
        raise SnapshotGroupError("keyboard snapshot manifest schema differs")
    roots = manifest.get("roots")
    if (not isinstance(roots, list) or not roots or
            not all(isinstance(root, str) and root for root in roots)):
        raise SnapshotGroupError("keyboard snapshot restore roots differ")
    return manifest["identity"], roots


def patch_xctestrun(source, destination, group_id, token, completed):
    value = plistlib.loads(source.read_bytes())
    try:
        environment = value["InputDecUITests"].setdefault(
            "EnvironmentVariables", {}
        )
    except (KeyError, TypeError, AttributeError) as error:
        raise SnapshotGroupError("xctestrun environment contract differs") from error
    for key in (
        "INPUTDEC_TEXT_INPUT_BATCH_ID",
        "INPUTDEC_TEXT_INPUT_GROUP_ID",
        "INPUTDEC_TEXT_INPUT_GROUP_TOKEN",
        "INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS",
    ):
        environment.pop(key, None)
    environment["INPUTDEC_TEXT_INPUT_GROUP_ID"] = group_id
    environment["INPUTDEC_TEXT_INPUT_GROUP_TOKEN"] = token
    if completed:
        environment["INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS"] = ",".join(
            str(index) for index in completed
        )
    destination.write_bytes(plistlib.dumps(value))


def seed_state(path, group_id, token, completed):
    next_observation = len(completed) + 1
    write_json(path, {
        "schema": 1,
        "token": token,
        "groupId": group_id,
        "nextObservationIndex": next_observation,
        "nextEventIndex": 1,
        "attempt": 1,
        "phase": "complete" if next_observation == 9 else "need-preparation",
        "preparation": None,
        "completedObservationIndexes": completed,
    })


def process_is_live(process):
    return process.poll() is None


def wait_for_path(path, process, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.is_file():
            return
        if not process_is_live(process):
            break
        time.sleep(0.02)
    raise SnapshotGroupError(f"XCTest exited or timed out before {path.name}")


def copy_resume_prefix(resume_from, checkpoints, catalog, group_id):
    if resume_from is None:
        checkpoints.mkdir()
        return []
    classification_path = resume_from / "failure-classification.json"
    if classification_path.is_symlink() or not classification_path.is_file():
        raise SnapshotGroupError("snapshot resume classification is missing")
    classification = json.loads(classification_path.read_text(encoding="utf-8"))
    if (not isinstance(classification, dict) or
            classification.get("result") != "Failed" or
            classification.get("resumable") is not True or
            classification.get("classification") not in {
                "external-interruption", "readiness-exhaustion",
            }):
        raise SnapshotGroupError("snapshot failure is not resumable")
    source = resume_from / "checkpoints"
    checked = run([
        PYTHON, "Scripts/text_input_batch.py",
        "observation-resume-check", "--catalog", str(catalog),
        "--group-id", group_id, "--directory", str(source),
    ])
    completed = (
        [] if not checked.stdout.strip()
        else [int(value) for value in checked.stdout.strip().split(",")]
    )
    checkpoints.mkdir()
    for index in completed:
        name = f"observation-{index:03d}.checkpoint"
        shutil.copytree(source / name, checkpoints / name)
    return completed


def run_snapshot_group(arguments):
    staging = arguments.staging
    selected_group = json.loads(arguments.group.read_text(encoding="utf-8"))
    group_id = selected_group.get("id")
    if group_id != arguments.group_id:
        raise SnapshotGroupError("selected snapshot group identity differs")
    observations = protocol.observation_plan(selected_group)
    if len(observations) != 8:
        raise SnapshotGroupError("snapshot group must contain eight observations")

    identity, restore_roots = load_snapshot_identity(
        arguments.keyboard_snapshot
    )
    identity_path = staging / "snapshot-identity.json"
    write_json(identity_path, identity)
    run([
        PYTHON, "Scripts/text_input_keyboard_snapshot.py", "verify",
        "--snapshot", str(arguments.keyboard_snapshot),
        "--identity", str(identity_path),
    ])
    run(["xcrun", "simctl", "bootstatus", arguments.udid, "-b"])
    for name, expected in (
        ("SIMULATOR_RUNTIME_VERSION", "26.5"),
        ("SIMULATOR_RUNTIME_BUILD_VERSION", "23F73"),
    ):
        result = run(["xcrun", "simctl", "getenv", arguments.udid, name])
        if result.stdout.strip() != expected:
            raise SnapshotGroupError("prepared simulator runtime differs")

    attempt = staging / "attempt-current"
    attempt.mkdir()
    checkpoints = attempt / "checkpoints"
    completed = copy_resume_prefix(
        arguments.resume_from, checkpoints, arguments.catalog, group_id
    )

    token = os.urandom(32).hex()
    patched = arguments.xctestrun.with_name(
        f"InputDec-snapshot-{os.getpid()}.xctestrun"
    )
    patch_xctestrun(
        arguments.xctestrun, patched, group_id, token, completed
    )
    state_path = attempt / "observation-state.json"
    seed_state(state_path, group_id, token, completed)

    result_bundle = attempt / "group.xcresult"
    log_path = attempt / "group.log"
    command = [
        "xcodebuild", "test-without-building",
        "-xctestrun", str(patched),
        "-destination", f"platform=iOS Simulator,id={arguments.udid}",
        "-parallel-testing-enabled", "NO",
        "-maximum-concurrent-test-simulator-destinations", "1",
        "-parallel-testing-worker-count", "1",
        "-maximum-parallel-testing-workers", "1",
        "-collect-test-diagnostics", "never",
        "-only-testing:InputDecUITests/IDInlinePredictionLifecycleUITests/"
        "testBatchedCertification",
        "-resultBundlePath", str(result_bundle),
    ]
    started = time.monotonic()
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                   text=True)
    handshake = None
    try:
        container_deadline = time.monotonic() + arguments.container_timeout
        runner_container = None
        while time.monotonic() < container_deadline and process_is_live(process):
            result = subprocess.run([
                "xcrun", "simctl", "get_app_container", arguments.udid,
                "com.inputdec.demo.uitests.xctrunner", "data",
            ], text=True, capture_output=True, check=False)
            if result.returncode == 0 and result.stdout.strip():
                runner_container = pathlib.Path(result.stdout.strip())
                break
            time.sleep(0.02)
        if runner_container is None:
            raise SnapshotGroupError("cannot locate XCTest runner container")
        handshake = (runner_container / "Documents" /
                     "InputDecTextInputGroup" / token)
        handshake_deadline = time.monotonic() + arguments.container_timeout
        while not handshake.is_dir() and time.monotonic() < handshake_deadline:
            if not process_is_live(process):
                break
            result = subprocess.run([
                "xcrun", "simctl", "get_app_container", arguments.udid,
                "com.inputdec.demo.uitests.xctrunner", "data",
            ], text=True, capture_output=True, check=False)
            if result.returncode == 0 and result.stdout.strip():
                runner_container = pathlib.Path(result.stdout.strip())
                handshake = (runner_container / "Documents" /
                             "InputDecTextInputGroup" / token)
            time.sleep(0.02)
        if not handshake.is_dir():
            raise SnapshotGroupError("snapshot handshake directory is missing")

        restores = 0
        readiness_retries = 0
        authority = []
        audit_before = {}
        while True:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            if state["phase"] == "complete":
                break
            event_index = state["nextEventIndex"]
            event_path = handshake / f"observation-{event_index:06d}-event.json"
            wait_for_path(event_path, process, arguments.request_timeout)
            validated = run([
                PYTHON, "Scripts/text_input_group_protocol.py",
                "validate-event", "--group", str(arguments.group),
                "--token", token, "--state", str(state_path),
                "--path", str(event_path),
            ])
            event = json.loads(validated.stdout)
            kind = event["kind"]
            if kind in {"observation-started", "retry-required"}:
                restores += 1
                if kind == "retry-required":
                    readiness_retries += 1
                observation = event["observationIndex"]
                restore_output = (
                    (attempt / "snapshot-restores" /
                     f"observation-{observation:03d}" /
                     f"attempt-{event['attempt']:03d}")
                    if event["attempt"] == 1 else
                    (attempt / "readiness-attempts" /
                     f"observation-{observation:03d}" /
                     f"attempt-{event['attempt']:03d}" / "snapshot-restore")
                )
                restore_output.parent.mkdir(parents=True, exist_ok=True)
                run([
                    PYTHON, "Scripts/text_input_live_boundary.py",
                    "--udid", arguments.udid,
                    "--device-root", str(arguments.device_root),
                    "--output", str(restore_output),
                    "--keyboard-snapshot", str(arguments.keyboard_snapshot),
                    "--identity", str(identity_path),
                ])
                reset_summary = restore_output / "summary.json"
                reset_hash = hashlib.sha256(reset_summary.read_bytes()).hexdigest()
                if arguments.audit_external_mutations:
                    audit_root = (
                        attempt / "external-mutation-audit" /
                        f"observation-{observation:03d}" /
                        f"attempt-{event['attempt']:03d}"
                    )
                    audit_root.mkdir(parents=True, exist_ok=True)
                    before = audit_root / "before.json"
                    run([
                        PYTHON, "Scripts/text_input_keyboard_mutation_audit.py",
                        "scan", "--device-root", str(arguments.device_root),
                        "--output", str(before),
                    ])
                    audit_before[(observation, event["attempt"])] = before
                response_path = handshake / (
                    f"observation-{event_index:06d}-restore.json"
                )
                response = run([
                    PYTHON, "Scripts/text_input_group_protocol.py",
                    "write-restore-response", "--group", str(arguments.group),
                    "--token", token, "--state", str(state_path),
                    "--request", str(event_path), "--path", str(response_path),
                    "--reset-summary-sha256", reset_hash,
                ])
                response_value = json.loads(response.stdout)
                if event["attempt"] == 1 and observation == 1:
                    write_json(attempt / "snapshot-preflight.json", {
                        key: value for key, value in response_value.items()
                        if key != "token"
                    })
                elif event["attempt"] == 1:
                    boundary = event["precedingBoundary"]
                    archived = {
                        "schema": 2, "token": token, "groupId": group_id,
                        **boundary, "resetSummarySHA256": reset_hash,
                        "result": "ready",
                    }
                    authority.append(archived)
                    write_json(
                        attempt /
                        f"boundary-{boundary['sequenceIndex']:03d}-response.json",
                        archived,
                    )
                continue
            if kind == "offer-ready":
                event_path.unlink()
                continue
            if kind == "observation-complete":
                observation = event["observationIndex"]
                source = handshake / f"observation-{observation:03d}.checkpoint"
                if source.is_symlink() or not source.is_dir():
                    raise SnapshotGroupError("completed observation checkpoint is missing")
                destination = checkpoints / source.name
                if destination.exists():
                    raise SnapshotGroupError("completed checkpoint already exists")
                shutil.copytree(source, destination)
                if arguments.audit_external_mutations:
                    key = (observation, event["attempt"])
                    before = audit_before.get(key)
                    if before is None:
                        raise SnapshotGroupError(
                            "completed observation audit baseline is missing"
                        )
                    audit_root = before.parent
                    after = audit_root / "after.json"
                    report = audit_root / "report.json"
                    run([
                        PYTHON, "Scripts/text_input_keyboard_mutation_audit.py",
                        "scan", "--device-root", str(arguments.device_root),
                        "--output", str(after),
                    ])
                    compare_command = [
                        PYTHON, "Scripts/text_input_keyboard_mutation_audit.py",
                        "compare", "--before", str(before),
                        "--after", str(after), "--output", str(report),
                    ]
                    for root in restore_roots:
                        compare_command.extend(["--restore-root", root])
                    run(compare_command)
                event_path.unlink()
                continue
            raise SnapshotGroupError(f"unexpected observation event: {kind}")

        status = process.wait(timeout=arguments.exit_timeout)
        if status != 0:
            raise SnapshotGroupError(f"snapshot XCTest failed with status {status}")
        if len(list(checkpoints.glob("observation-*.checkpoint"))) != 8:
            raise SnapshotGroupError("XCTest exited before eight completions")
        expected_new_boundaries = 7 if not completed else 8 - len(completed)
        if len(authority) != expected_new_boundaries:
            raise SnapshotGroupError("authority boundary response count differs")

        boundaries = sorted(attempt.glob("boundary-*-response.json"))
        if completed:
            previous = arguments.resume_from / "resume-authority-boundaries.json"
            if not previous.is_file():
                raise SnapshotGroupError("resumed authority boundaries are missing")
            sanitized_prior = json.loads(previous.read_text(encoding="utf-8"))
            prior = [{
                "schema": 2, "token": token, "groupId": group_id, **value,
            } for value in sanitized_prior]
        else:
            prior = []
        boundary_values = prior + [
            json.loads(path.read_text(encoding="utf-8")) for path in boundaries
        ]
        if len(boundary_values) != 7:
            raise SnapshotGroupError("snapshot group requires seven boundaries")
        write_json(attempt / "boundaries.json", boundary_values)

        summary_result = subprocess.run([
            "xcrun", "xcresulttool", "get", "test-results", "summary",
            "--path", str(result_bundle), "--compact",
        ], text=True, capture_output=True, check=False)
        (attempt / "xcresult-summary.json").write_text(
            summary_result.stdout, encoding="utf-8"
        )
        run([
            "Scripts/validate-autocorrection-summary.py",
            str(attempt / "xcresult-summary.json"), arguments.udid,
            "26.5", "23F73",
        ])
        exported = attempt / "exported-attachments"
        run([
            "xcrun", "xcresulttool", "export", "attachments",
            "--path", str(result_bundle), "--output-path", str(exported),
        ])
        materialized = attempt / "materialized"
        run([
            PYTHON, "Scripts/text_input_batch.py", "extract-group",
            "--catalog", str(arguments.catalog), "--group-id", group_id,
            "--attachments", str(exported), "--xcresult", str(result_bundle),
            "--boundaries", str(attempt / "boundaries.json"),
            "--checkpoints", str(checkpoints), "--output", str(materialized),
        ])
        sanitized_boundaries = [{
            key: value for key, value in boundary.items()
            if key not in {"schema", "token", "groupId"}
        } for boundary in boundary_values]
        write_json(attempt / "boundaries.json", sanitized_boundaries)
        for path in boundaries:
            path.unlink()
        for child in materialized.iterdir():
            child.replace(attempt / child.name)
        materialized.rmdir()
        write_json(attempt / "failure-classification.json", {
            "schema": 1, "result": "Passed", "classification": "none",
        })
        write_json(attempt / "group-timing.json", {
            "schema": 1,
            "xctestInvocations": 1,
            "attempts": 1,
            "buildSeconds": 0,
            "provisioningResetSeconds": 0,
            "xctestSeconds": int(time.monotonic() - started),
            "hostResetSeconds": 0,
            "rowResetSeconds": 0,
            "extractionComparisonSeconds": 0,
            "snapshotRestores": restores,
            "readinessRetries": readiness_retries,
            "eraseBootSeconds": 0,
            "totalSeconds": int(time.monotonic() - started),
        })
    except BaseException as error:
        if process_is_live(process):
            process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        readiness_exhausted = False
        if log_path.is_file():
            readiness_exhausted = (
                "Inline prediction remained unavailable after 20 attempts"
                in log_path.read_text(encoding="utf-8", errors="replace")
            )
        resumable = isinstance(error, KeyboardInterrupt) or readiness_exhausted
        if checkpoints.is_dir() and resumable:
            checkpoints.replace(staging / "checkpoints")
            completed_count = len(list(
                (staging / "checkpoints").glob("observation-*.checkpoint")
            ))
            resumable_boundaries = []
            for path in sorted(attempt.glob("boundary-*-response.json")):
                value = json.loads(path.read_text(encoding="utf-8"))
                if value.get("sequenceIndex", 0) < completed_count:
                    resumable_boundaries.append({
                        key: item for key, item in value.items()
                        if key not in {"schema", "token", "groupId"}
                    })
            write_json(
                staging / "resume-authority-boundaries.json",
                resumable_boundaries,
            )
        elif checkpoints.is_dir():
            quarantine = attempt / "quarantined-checkpoints"
            if quarantine.exists():
                shutil.rmtree(quarantine)
            checkpoints.replace(quarantine)
        write_json(staging / "failure-classification.json", {
            "schema": 1,
            "result": "Failed",
            "classification": (
                "external-interruption" if isinstance(error, KeyboardInterrupt)
                else ("readiness-exhaustion" if readiness_exhausted
                      else "snapshot-protocol-or-infrastructure")
            ),
            "message": str(error),
            "resumable": resumable,
        })
        raise
    finally:
        patched.unlink(missing_ok=True)
        state_path.unlink(missing_ok=True)
        if handshake is not None and handshake.is_dir():
            shutil.rmtree(handshake, ignore_errors=True)

    for child in attempt.iterdir():
        child.replace(staging / child.name)
    attempt.rmdir()
    staging.replace(arguments.output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--catalog", required=True, type=pathlib.Path)
    parser.add_argument("--group-id", required=True)
    parser.add_argument("--group", required=True, type=pathlib.Path)
    parser.add_argument("--xctestrun", required=True, type=pathlib.Path)
    parser.add_argument("--device-root", required=True, type=pathlib.Path)
    parser.add_argument("--keyboard-snapshot", required=True, type=pathlib.Path)
    parser.add_argument("--staging", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--resume-from", type=pathlib.Path)
    parser.add_argument("--audit-external-mutations", action="store_true")
    parser.add_argument("--container-timeout", type=float, default=30)
    parser.add_argument("--request-timeout", type=float, default=180)
    parser.add_argument("--exit-timeout", type=float, default=30)
    arguments = parser.parse_args()
    def interrupt(_signal_number, _frame):
        raise KeyboardInterrupt()

    signal.signal(signal.SIGTERM, interrupt)
    signal.signal(signal.SIGINT, interrupt)
    try:
        run_snapshot_group(arguments)
    except KeyboardInterrupt:
        print("snapshot group interrupted", file=sys.stderr)
        return 130
    except (OSError, ValueError, SnapshotGroupError,
            protocol.ProtocolError, subprocess.SubprocessError) as error:
        print(f"snapshot group failed: {error}", file=sys.stderr)
        return 65
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
