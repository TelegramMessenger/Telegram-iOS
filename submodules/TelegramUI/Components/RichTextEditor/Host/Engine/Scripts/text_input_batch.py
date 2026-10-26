#!/usr/bin/env python3

import argparse
import hashlib
import importlib.util
import json
import math
import pathlib
import re
import shutil
import sqlite3
import sys
import tempfile

try:
    from Scripts import text_input_group_protocol as group_protocol
except ImportError:  # Direct execution places Scripts/ on sys.path.
    import text_input_group_protocol as group_protocol


PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
RUNTIME = {"osVersion": "26.5", "osBuild": "23F73"}
RESET_POLICY = "erase-reset-learning-provision"
REPETITIONS = (1, 2)
ORDERS = (
    ("stock-custom", ("stock", "custom")),
    ("custom-stock", ("custom", "stock")),
)
TOP_LEVEL_KEYS = {
    "schema", "runtime", "udid", "subsystem", "rows", "groups",
}
GROUP_KEYS = {
    "id", "language", "rows", "stateSensitive", "resetPolicy",
}
IDENTIFIER = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
ATTACHMENT = re.compile(
    r"^batch--(?P<row>[a-z0-9-]+)--"
    r"(?P<host>stock|custom)--(?P<name>.+)$"
)
GROUP_ATTACHMENT = re.compile(
    r"^group--(?P<batch>[a-z0-9-]+(?:--[a-z0-9-]+){3})--"
    r"(?P<row>[a-z0-9-]+)--(?P<host>stock|custom)--(?P<name>.+)$"
)
GROUP_METADATA = re.compile(
    r"^group--(?P<batch>[a-z0-9-]+(?:--[a-z0-9-]+){3})--"
    r"metadata(?:_.*)?\.json$"
)
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
HEX_64_CANDIDATE = re.compile(r"(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])")
TEST_CLASSES = {
    "ime": "IDIMECompositionLifecycleUITests",
    "autocorrection": "IDAutocorrectionDecisionUITests",
    "inline-prediction": "IDInlinePredictionLifecycleUITests",
}
KEYBOARD_READINESS = re.compile(
    r'Failed to determine hittability of "(?:k|n)" Key: Activation point '
    r'invalid and no suggested hit points based on element frame'
)
READINESS_MESSAGES = (
    "Expected native inline prediction was absent",
    "Expected native candidate 'address' was not actionable",
)
IME_AUTHORITY_FIELDS = (
    "schema", "scenario", "language", "location", "decision",
    "canonical", "blocks", "selection", "affinity", "markedRange",
    "markedText", "markedSelection", "markedAttributeKeys",
    "structuralNewlineLocations", "checkingRanges", "mutationTrace",
    "eventTrace", "coordinateSpaceIdentity", "textEpoch", "selectionEpoch",
    "checkingEpoch", "layoutEpoch", "firstResponder",
)
REQUIRED_IME_INPUT_MODES = {
    "japaneseRomaji": "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
    "simplifiedChinesePinyin": (
        "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic"
    ),
}


def _matches_exported_attachment_name(name, stem, extension):
    if not isinstance(name, str):
        return False
    if name == f"{stem}.{extension}":
        return True
    return re.fullmatch(
        rf"{re.escape(stem)}_\d+_[0-9A-Fa-f-]{{36}}\.{re.escape(extension)}",
        name,
    ) is not None


def _is_reset_induced_testmanager_crash(export_root, attachment):
    name = attachment.get("suggestedHumanReadableName")
    filename = attachment.get("exportedFileName")
    if (not isinstance(name, str) or
            re.fullmatch(r"Crash Log .+\.ips", name) is None or
            not isinstance(filename, str) or not filename.endswith(".ips") or
            attachment.get("isAssociatedWithFailure") is not False):
        return False
    try:
        lines = _attachment_path(export_root, attachment).read_text(
            encoding="utf-8"
        ).splitlines()
        if len(lines) != 2:
            return False
        header, payload = (json.loads(line) for line in lines)
    except (OSError, UnicodeError, json.JSONDecodeError,
            BatchEvidenceError):
        return False
    exception = payload.get("exception") if isinstance(payload, dict) else None
    termination = payload.get("termination") if isinstance(payload, dict) else None
    return (
        isinstance(header, dict) and
        header.get("app_name") == "testmanagerd" and
        header.get("name") == "testmanagerd" and
        header.get("bug_type") == "309" and
        isinstance(payload, dict) and
        payload.get("procName") == "testmanagerd" and
        payload.get("codeSigningID") == "com.apple.testmanagerd" and
        isinstance(exception, dict) and
        exception.get("type") == "EXC_CRASH" and
        exception.get("signal") == "SIGKILL" and
        isinstance(termination, dict) and
        termination.get("namespace") == "LIBXPC" and
        termination.get("indicator") == "XPC_EXIT_REASON_SIGTERM_TIMEOUT"
    )


def is_readiness_failure(diagnostic):
    if not isinstance(diagnostic, str):
        return False
    return (KEYBOARD_READINESS.search(diagnostic) is not None or
            any(message in diagnostic for message in READINESS_MESSAGES))


def _sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fingerprint(udid, device_root, provisioning_summary, output):
    if udid != PINNED_UDID:
        raise BatchEvidenceError(f"refusing non-K3 simulator: {udid}")
    device_root = pathlib.Path(device_root).expanduser().resolve()
    provisioning = _load_json(
        pathlib.Path(provisioning_summary), "provisioning summary"
    )
    output = pathlib.Path(output)
    if output.exists():
        raise BatchEvidenceError(f"refusing existing output: {output}")
    if (provisioning.get("schema") != 1 or
            provisioning.get("udid") != PINNED_UDID or
            provisioning.get("runtime") != RUNTIME):
        raise BatchEvidenceError("provisioning summary identity differs")
    inventory = provisioning.get("inventory")
    primary_languages = provisioning.get("primaryLanguages")
    if (not isinstance(inventory, list) or not inventory or
            any(not isinstance(item, str) or not item for item in inventory) or
            not isinstance(primary_languages, list) or
            any(not isinstance(item, str) or not item
                for item in primary_languages)):
        raise BatchEvidenceError("provisioning language inventory is invalid")

    keyboard = device_root / "Library" / "Keyboard"
    database = keyboard / "AutocorrectionRejections.db"
    counts = {
        "rejections": 0,
        "inline_completion_rejections": 0,
    }
    if database.exists():
        if database.is_symlink() or not database.is_file():
            raise BatchEvidenceError("rejection database is invalid")
        connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
        try:
            for table in counts:
                counts[table] = connection.execute(
                    f"SELECT COUNT(*) FROM {table}"
                ).fetchone()[0]
        finally:
            connection.close()

    lexicon_root = keyboard / "mul-dynamic.lm"
    lexicons = []
    if lexicon_root.exists():
        if lexicon_root.is_symlink() or not lexicon_root.is_dir():
            raise BatchEvidenceError("dynamic lexicon directory is invalid")
        for path in sorted(lexicon_root.glob("dynamic-lexicon-*.dat")):
            if path.is_symlink() or not path.is_file():
                raise BatchEvidenceError(
                    f"dynamic lexicon file is invalid: {path.name}"
                )
            lexicons.append({
                "path": str(path.relative_to(device_root)),
                "sha256": _sha256(path),
            })

    result = {
        "schema": 1,
        "udid": PINNED_UDID,
        "runtime": RUNTIME,
        "locale": "en_US",
        "languages": ["en-US"],
        "primaryLanguages": primary_languages,
        "enabledInputModeIdentifiers": inventory,
        "rejectionTableCounts": counts,
        "dynamicLexicons": lexicons,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, indent=2, sort_keys=True)
        stream.write("\n")
    return result


def _is_file(path):
    return path.is_file() and not path.is_symlink()


def _comparison_filename(subsystem):
    return "comparison.json" if subsystem == "ime" else "parity.json"


def _valid_fingerprint(path):
    value = _load_json(path, "batch state fingerprint")
    return (
        value.get("schema") == 1 and
        value.get("udid") == PINNED_UDID and
        value.get("runtime") == RUNTIME and
        value.get("locale") == "en_US" and
        value.get("languages") == ["en-US"] and
        isinstance(value.get("primaryLanguages"), list) and
        isinstance(value.get("enabledInputModeIdentifiers"), list) and
        isinstance(value.get("rejectionTableCounts"), dict) and
        isinstance(value.get("dynamicLexicons"), list)
    )


def batch_is_resumable(directory, batch):
    directory = pathlib.Path(directory)
    try:
        if directory.is_symlink() or not directory.is_dir():
            return False
        for relative in ("batch.log", "selected-batch.json", "timing.json"):
            if not _is_file(directory / relative):
                return False
        if not (directory / "batch.xcresult").is_dir():
            return False
        if _load_json(directory / "selected-batch.json", "selected batch") != batch:
            return False
        summary = _load_json(
            directory / "batch-summary.json", "batch summary"
        )
        expected_summary = {
            "schema": 1,
            "runtime": RUNTIME,
            "udid": PINNED_UDID,
            "batchId": batch["id"],
            "subsystem": batch["subsystem"],
            "observedHosts": batch["hosts"],
            "comparisons": len(batch["rows"]),
            "hostObservations": len(batch["hosts"]),
            "failedTests": 0,
            "skippedTests": 0,
            "result": "Passed",
        }
        if summary != expected_summary:
            return False
        timing = _load_json(directory / "timing.json", "batch timing")
        timing_keys = {
            "schema", "attempts", "buildSeconds", "eraseBootSeconds",
            "provisioningResetSeconds", "xctestSeconds",
            "extractionComparisonSeconds", "totalSeconds",
        }
        if (set(timing) != timing_keys or timing.get("schema") != 1 or
                type(timing.get("attempts")) is not int or
                not 1 <= timing["attempts"] <= 3 or
                any(type(timing.get(key)) is not int or timing[key] < 0
                    for key in timing_keys - {"schema", "attempts"})):
            return False
        if not _valid_fingerprint(directory / "pre-state.json"):
            return False
        if not _valid_fingerprint(directory / "post-state.json"):
            return False
        provisioning = _load_json(
            directory / "provisioning" / "summary.json",
            "batch provisioning summary",
        )
        if (provisioning.get("schema") != 1 or
                provisioning.get("udid") != PINNED_UDID or
                provisioning.get("runtime") != RUNTIME):
            return False
        for row in batch["rows"]:
            row_root = directory / row
            comparison_path = row_root / _comparison_filename(
                batch["subsystem"]
            )
            if not _is_file(comparison_path):
                return False
            _load_json(comparison_path, "row comparison")
            for host in ("stock", "custom"):
                host_root = row_root / host
                if not _is_file(host_root / "attachments" / "manifest.json"):
                    return False
                host_summary = _load_json(
                    host_root / "host-summary.json", "host summary"
                )
                if any((
                    host_summary.get("schema") != 1,
                    host_summary.get("row") != row,
                    host_summary.get("host") != host,
                    host_summary.get("batchId") != batch["id"],
                )):
                    return False
                if (batch["subsystem"] == "ime" and
                        not _is_file(host_root / "lifecycle.json")):
                    return False
        return True
    except (BatchEvidenceError, OSError, TypeError, ValueError):
        return False


def _group_summary(group, erased_boots, erase_boot_seconds=0,
                   total_seconds=0):
    return {
        "schema": 1,
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        "groupId": group["id"],
        "subsystem": group["subsystem"],
        "batchIds": [batch["id"] for batch in group["batches"]],
        "erasedBoots": erased_boots,
        "batches": len(group["batches"]),
        "comparisons": sum(len(batch["rows"]) for batch in group["batches"]),
        "hostObservations": sum(
            len(batch["hosts"]) for batch in group["batches"]
        ),
        "failedTests": 0,
        "skippedTests": 0,
        "timing": {
            "eraseBootSeconds": erase_boot_seconds,
            "totalSeconds": total_seconds,
        },
        "result": "Passed",
    }


def write_group_summary(directory, group, erased_boots=1,
                        erase_boot_seconds=0, total_seconds=0):
    if erased_boots != 1:
        raise BatchEvidenceError("a logical group must own exactly one erased boot")
    directory = pathlib.Path(directory)
    output = directory / "group-summary.json"
    if output.exists():
        raise BatchEvidenceError(f"refusing existing output: {output}")
    for batch in group["batches"]:
        if not batch_is_resumable(directory / "batches" / batch["id"], batch):
            raise BatchEvidenceError(
                f"group pass is incomplete or invalid: {batch['id']}"
            )
    for label, value in (
            ("erase boot seconds", erase_boot_seconds),
            ("total seconds", total_seconds)):
        if type(value) is not int or value < 0:
            raise BatchEvidenceError(f"{label} must be a nonnegative integer")
    result = _group_summary(
        group, erased_boots, erase_boot_seconds, total_seconds
    )
    _write_json(output, result)
    return result


def group_attempt_limit(group):
    return 20 if group["subsystem"] == "inline-prediction" else 3


def _snapshot_group_is_resumable(directory, group):
    if (not _is_file(directory / "group.log") or
            not _is_file(directory / "selected-group.json") or
            _load_json(directory / "selected-group.json",
                       "selected group") != group):
        return False
    results = [path for path in directory.rglob("*.xcresult")
               if path.is_dir() and not path.is_symlink()]
    if (results != [directory / "group.xcresult"] or
            not any((directory / "group.xcresult").iterdir()) or
            not _valid_group_xcresult_summary(
                directory / "xcresult-summary.json")):
        return False
    summary = _load_json(directory / "group-summary.json", "group summary")
    token_hash = summary.get("tokenSHA256") if isinstance(summary, dict) else None
    plan = group_protocol.boundary_plan(group)
    boundaries = summary.get("boundaries") if isinstance(summary, dict) else None
    if (not isinstance(boundaries, list) or len(boundaries) != len(plan) or
            any(not isinstance(boundary, dict) or
                boundary != {
                    **identity,
                    "resetSummarySHA256": boundary.get("resetSummarySHA256"),
                    "result": "ready",
                } or HEX_64.fullmatch(
                    boundary.get("resetSummarySHA256", "")) is None
                for identity, boundary in zip(plan, boundaries))):
        return False
    if _load_json(directory / "boundaries.json",
                  "snapshot boundaries") != boundaries:
        return False
    expected_summary = {
        "schema": 1, "runtime": RUNTIME, "udid": PINNED_UDID,
        "groupId": group["id"], "subsystem": group["subsystem"],
        "tokenSHA256": token_hash,
        "batchIds": [batch["id"] for batch in group["batches"]],
        "batches": len(group["batches"]),
        "comparisons": sum(len(batch["rows"]) for batch in group["batches"]),
        "hostObservations": sum(
            len(batch["hosts"]) for batch in group["batches"]),
        "successfulBoundaries": len(boundaries),
        "successfulHostBoundaries": sum(
            item["kind"] == "host" for item in boundaries),
        "successfulPassBoundaries": sum(
            item["kind"] == "pass" for item in boundaries),
        "successfulRowBoundaries": sum(
            item["kind"] == "row" for item in boundaries),
        "boundaries": boundaries,
        "hostBoundaries": [
            item for item in boundaries if item["kind"] == "host"],
        "passBoundaries": [
            item for item in boundaries if item["kind"] == "pass"],
        "rowBoundaries": [
            item for item in boundaries if item["kind"] == "row"],
        "failedTests": 0, "skippedTests": 0, "result": "Passed",
    }
    if (not isinstance(token_hash, str) or HEX_64.fullmatch(token_hash) is None or
            summary != expected_summary or
            not _valid_exported_group_metadata(
                directory / "exported-attachments", group, token_hash)):
        return False
    _validated_snapshot_checkpoints(
        directory / "checkpoints", group, require_complete=True
    )
    for batch in group["batches"]:
        if not _materialized_batch_is_valid(
                directory / "batches" / batch["id"], batch):
            return False
    timing = _load_json(directory / "group-timing.json", "group timing")
    timing_keys = {
        "schema", "xctestInvocations", "attempts", "buildSeconds",
        "eraseBootSeconds", "provisioningResetSeconds", "xctestSeconds",
        "hostResetSeconds", "rowResetSeconds", "extractionComparisonSeconds",
        "totalSeconds", "snapshotRestores", "readinessRetries",
    }
    if (not isinstance(timing, dict) or set(timing) != timing_keys or
            timing.get("schema") != 1 or timing.get("xctestInvocations") != 1 or
            timing.get("attempts") != 1 or timing.get("eraseBootSeconds") != 0 or
            any(type(timing.get(key)) is not int or timing[key] < 0
                for key in timing_keys - {
                    "schema", "xctestInvocations", "attempts"}) or
            timing["snapshotRestores"] != 8 + timing["readinessRetries"]):
        return False
    if (timing["hostResetSeconds"] > timing["xctestSeconds"] or
            timing["rowResetSeconds"] > timing["xctestSeconds"] or
            timing["hostResetSeconds"] + timing["rowResetSeconds"] >
            timing["xctestSeconds"] or
            timing["xctestSeconds"] > timing["totalSeconds"] + 1 or
            timing["extractionComparisonSeconds"] >
            timing["totalSeconds"] + 1):
        return False
    classification = _load_json(
        directory / "failure-classification.json", "failure classification"
    )
    if classification != {
            "schema": 1, "result": "Passed", "classification": "none"}:
        return False
    for path in directory.rglob("*"):
        if path.is_symlink():
            return False
        if path.is_file() and path.suffix in {".json", ".txt", ".log"}:
            try:
                text = path.read_text(encoding="utf-8")
            except (UnicodeError, OSError):
                continue
            for candidate in HEX_64_CANDIDATE.findall(text):
                if hashlib.sha256(candidate.encode("ascii")).hexdigest() == token_hash:
                    return False
    return True


def group_is_resumable(directory, group):
    directory = pathlib.Path(directory)
    try:
        if directory.is_symlink() or not directory.is_dir():
            return False
        if (group.get("subsystem") == "inline-prediction" and
                isinstance(group.get("id"), str) and
                group["id"].startswith(
                    "inline-prediction--snapshot-row-v1--")):
            return _snapshot_group_is_resumable(directory, group)
        if (not _is_file(directory / "group.log") or
                not _is_file(directory / "selected-group.json") or
                _load_json(directory / "selected-group.json",
                           "selected group") != group):
            return False
        results = [path for path in directory.rglob("*.xcresult")
                   if path.is_dir() and not path.is_symlink()]
        if (results != [directory / "group.xcresult"] or
                not any((directory / "group.xcresult").iterdir()) or
                not _valid_group_xcresult_summary(
                    directory / "xcresult-summary.json")):
            return False
        summary = _load_json(directory / "group-summary.json", "group summary")
        token_hash = summary.get("tokenSHA256")
        plan = group_protocol.boundary_plan(group)
        boundaries_root = directory / "boundaries"
        expected_reset_names = {
            f"boundary-{identity['sequenceIndex']:03d}-{identity['kind']}-reset"
            for identity in plan
        }
        if (boundaries_root.is_symlink() or not boundaries_root.is_dir() or
                {path.name for path in boundaries_root.iterdir()} !=
                expected_reset_names or
                any(not path.is_dir() or path.is_symlink()
                    for path in boundaries_root.iterdir())):
            return False
        expected_boundaries = []
        for identity in plan:
            reset_summary = (
                boundaries_root /
                f"boundary-{identity['sequenceIndex']:03d}-"
                f"{identity['kind']}-reset" / "summary.json"
            )
            expected_boundaries.append({
                **identity,
                "resetSummarySHA256": _sha256(reset_summary),
                "result": "ready",
            })
        expected_pass_boundaries = [
            item for item in expected_boundaries if item["kind"] == "pass"
        ]
        expected_host_boundaries = [
            item for item in expected_boundaries if item["kind"] == "host"
        ]
        expected_row_boundaries = [
            item for item in expected_boundaries if item["kind"] == "row"
        ]
        expected_summary = {
            "schema": 1,
            "runtime": RUNTIME,
            "udid": PINNED_UDID,
            "groupId": group["id"],
            "subsystem": group["subsystem"],
            "tokenSHA256": token_hash,
            "batchIds": [batch["id"] for batch in group["batches"]],
            "batches": len(group["batches"]),
            "comparisons": sum(
                len(batch["rows"]) for batch in group["batches"]),
            "hostObservations": sum(
                len(batch["hosts"]) for batch in group["batches"]),
            "successfulBoundaries": len(expected_boundaries),
            "successfulHostBoundaries": len(expected_host_boundaries),
            "successfulPassBoundaries": len(expected_pass_boundaries),
            "successfulRowBoundaries": len(expected_row_boundaries),
            "boundaries": expected_boundaries,
            "hostBoundaries": expected_host_boundaries,
            "passBoundaries": expected_pass_boundaries,
            "rowBoundaries": expected_row_boundaries,
            "failedTests": 0,
            "skippedTests": 0,
            "result": "Passed",
        }
        if (not isinstance(token_hash, str) or
                HEX_64.fullmatch(token_hash) is None or
                summary != expected_summary or
                not _valid_exported_group_metadata(
                    directory / "exported-attachments", group, token_hash)):
            return False
        for path in directory.rglob("*"):
            if path.is_symlink():
                return False
            if path.is_file():
                if any(parent.suffix == ".xcresult" for parent in path.parents):
                    continue
                if path.suffix not in {".json", ".txt", ".log"}:
                    continue
                try:
                    text = path.read_text(encoding="utf-8")
                except (UnicodeError, OSError):
                    continue
                for candidate in HEX_64_CANDIDATE.findall(text):
                    if hashlib.sha256(candidate.encode("ascii")).hexdigest() == token_hash:
                        return False

        timing = _load_json(directory / "group-timing.json", "group timing")
        timing_keys = {
            "schema", "xctestInvocations", "attempts", "buildSeconds",
            "eraseBootSeconds", "provisioningResetSeconds", "xctestSeconds",
            "hostResetSeconds", "rowResetSeconds",
            "extractionComparisonSeconds", "totalSeconds",
        }
        if (not isinstance(timing, dict) or set(timing) != timing_keys or
                timing.get("schema") != 1 or
                timing.get("xctestInvocations") != 1 or
                type(timing.get("xctestInvocations")) is not int or
                type(timing.get("attempts")) is not int or
                not 1 <= timing["attempts"] <= group_attempt_limit(group) or
                any(type(timing.get(key)) is not int or timing[key] < 0
                    for key in timing_keys - {
                        "schema", "xctestInvocations", "attempts"})):
            return False
        if (timing["hostResetSeconds"] > timing["xctestSeconds"] or
                timing["rowResetSeconds"] > timing["xctestSeconds"] or
                timing["hostResetSeconds"] + timing["rowResetSeconds"] >
                timing["xctestSeconds"]):
            return False
        phase_seconds = [timing[key] for key in (
            "eraseBootSeconds", "provisioningResetSeconds", "xctestSeconds",
            "extractionComparisonSeconds",
        )]
        if (any(value > timing["totalSeconds"] + 1
                for value in phase_seconds) or
                sum(phase_seconds) > timing["totalSeconds"] + 4):
            return False
        if (not _valid_fingerprint(directory / "pre-state.json") or
                not _valid_fingerprint(directory / "post-state.json")):
            return False
        provisioning = _load_json(
            directory / "provisioning" / "summary.json",
            "group provisioning summary",
        )
        if (provisioning.get("schema") != 1 or
                provisioning.get("udid") != PINNED_UDID or
                provisioning.get("runtime") != RUNTIME):
            return False

        batches_root = directory / "batches"
        if (batches_root.is_symlink() or not batches_root.is_dir() or
                {path.name for path in batches_root.iterdir()
                 if path.is_dir() and not path.is_symlink()} !=
                {batch["id"] for batch in group["batches"]} or
                any(not path.is_dir() or path.is_symlink()
                    for path in batches_root.iterdir())):
            return False
        return all(
            _materialized_batch_is_valid(
                directory / "batches" / batch["id"], batch
            ) for batch in group["batches"]
        )
    except (BatchEvidenceError, OSError, TypeError, ValueError):
        return False


def _valid_group_xcresult_summary(path):
    value = _load_json(path, "group xcresult summary")
    if (not isinstance(value, dict) or value.get("result") != "Passed" or
            type(value.get("totalTestCount")) is not int or
            value["totalTestCount"] != 1):
        return False
    expected_counts = {
        "expectedFailures": 0, "failedTests": 0,
        "skippedTests": 0, "passedTests": 1,
    }
    if any(type(value.get(key)) is not int or value[key] != expected
           for key, expected in expected_counts.items()):
        return False
    configurations = value.get("devicesAndConfigurations")
    if not isinstance(configurations, list) or len(configurations) != 1:
        return False
    configuration = configurations[0]
    if (not isinstance(configuration, dict) or
            any(type(configuration.get(key)) is not int or
                configuration[key] != expected
                for key, expected in expected_counts.items())):
        return False
    device = configuration.get("device")
    return isinstance(device, dict) and all((
        device.get("deviceId") == PINNED_UDID,
        device.get("osVersion") == RUNTIME["osVersion"],
        device.get("osBuildNumber") == RUNTIME["osBuild"],
    ))


def _valid_exported_group_metadata(export_root, group, token_hash):
    export_root = pathlib.Path(export_root)
    manifest = _load_json(export_root / "manifest.json", "group export manifest")
    if (not isinstance(manifest, list) or len(manifest) != 1 or
            not isinstance(manifest[0], dict) or
            manifest[0].get("testIdentifier") !=
            _expected_test_identifier(group["subsystem"]) or
            not isinstance(manifest[0].get("attachments"), list)):
        return False
    attachments = [
        attachment for attachment in manifest[0]["attachments"]
        if isinstance(attachment, dict) and _matches_exported_attachment_name(
            attachment.get("suggestedHumanReadableName"),
            "group-metadata", "json")
    ]
    if len(attachments) != 1:
        return False
    metadata = _load_json(
        _attachment_path(export_root, attachments[0]), "exported group metadata"
    )
    return metadata == {
        "schema": 1, "groupId": group["id"],
        "subsystem": group["subsystem"], "runtime": RUNTIME,
        "udid": PINNED_UDID, "tokenSHA256": token_hash,
        "batches": [batch["id"] for batch in group["batches"]],
    }


def _materialized_batch_is_valid(directory, batch):
    directory = pathlib.Path(directory)
    if directory.is_symlink() or not directory.is_dir():
        return False
    summary = _load_json(directory / "batch-summary.json", "batch summary")
    if summary != {
            "schema": 1, "runtime": RUNTIME, "udid": PINNED_UDID,
            "batchId": batch["id"], "subsystem": batch["subsystem"],
            "observedHosts": batch["hosts"],
            "comparisons": len(batch["rows"]),
            "hostObservations": len(batch["hosts"]),
            "failedTests": 0, "skippedTests": 0, "result": "Passed"}:
        return False
    for row in batch["rows"]:
        row_root = directory / row
        if not _is_file(
                row_root / _comparison_filename(batch["subsystem"])):
            return False
        for host in ("stock", "custom"):
            host_root = row_root / host
            if not _is_file(host_root / "attachments" / "manifest.json"):
                return False
            host_summary = _load_json(
                host_root / "host-summary.json", "host summary"
            )
            if any((host_summary.get("schema") != 1,
                    host_summary.get("row") != row,
                    host_summary.get("host") != host,
                    host_summary.get("batchId") != batch["id"])):
                return False
            if (batch["subsystem"] == "ime" and
                    not _is_file(host_root / "lifecycle.json")):
                return False
    return True


def aggregate_certification(catalog_paths, batches_root):
    batches_root = pathlib.Path(batches_root)
    if batches_root.is_symlink() or not batches_root.is_dir():
        raise BatchEvidenceError("aggregate groups root is invalid")
    batches_root = batches_root.resolve()
    catalogs = []
    children = []
    seen_subsystems = set()
    seen_paths = set()
    seen_boot_scopes = set()
    totals = {
        "logicalRows": 0,
        "groups": 0,
        "erasedBoots": 0,
        "successfulXCTestInvocations": 0,
        "successfulBoundaries": 0,
        "successfulHostBoundaries": 0,
        "successfulPassBoundaries": 0,
        "successfulRowBoundaries": 0,
        "totalAttempts": 0,
        "batches": 0,
        "comparisons": 0,
        "hostObservations": 0,
        "readinessRetries": 0,
        "failedTests": 0,
        "skippedTests": 0,
    }
    durations = {
        "buildSeconds": 0,
        "eraseBootSeconds": 0,
        "provisioningResetSeconds": 0,
        "xctestSeconds": 0,
        "hostResetSeconds": 0,
        "rowResetSeconds": 0,
        "extractionComparisonSeconds": 0,
        "totalSeconds": 0,
    }
    subsystem_boundaries = {}
    for catalog_path in catalog_paths:
        catalog_path = pathlib.Path(catalog_path).resolve()
        catalog = load_catalog(catalog_path)
        subsystem = catalog["subsystem"]
        if subsystem in seen_subsystems:
            raise BatchEvidenceError(
                f"duplicate aggregate subsystem: {subsystem}"
            )
        seen_subsystems.add(subsystem)
        catalogs.append({
            "subsystem": subsystem,
            "path": str(catalog_path),
            "sha256": _sha256(catalog_path),
        })
        totals["logicalRows"] += len(catalog["rows"])
        for group in logical_groups(catalog):
            directory = (batches_root / subsystem / group["id"]).resolve()
            if directory in seen_paths:
                raise BatchEvidenceError(
                    f"duplicate aggregate group path: {directory}"
                )
            seen_paths.add(directory)
            if not group_is_resumable(directory, group):
                raise BatchEvidenceError(
                    f"group is incomplete or invalid: {group['id']}"
                )
            group_summary = _load_json(
                directory / "group-summary.json", "group summary"
            )
            totals["groups"] += 1
            seen_boot_scopes.add(boot_scope(group))
            totals["successfulXCTestInvocations"] += 1
            totals["successfulBoundaries"] += group_summary[
                "successfulBoundaries"
            ]
            totals["successfulHostBoundaries"] += group_summary[
                "successfulHostBoundaries"
            ]
            totals["successfulPassBoundaries"] += group_summary[
                "successfulPassBoundaries"
            ]
            totals["successfulRowBoundaries"] += group_summary[
                "successfulRowBoundaries"
            ]
            inventory = subsystem_boundaries.setdefault(subsystem, {
                "successfulBoundaries": 0,
                "successfulHostBoundaries": 0,
                "successfulPassBoundaries": 0,
                "successfulRowBoundaries": 0,
            })
            for key in inventory:
                inventory[key] += group_summary[key]
            timing = _load_json(
                directory / "group-timing.json", "group timing"
            )
            totals["totalAttempts"] += timing["attempts"]
            if subsystem != "inline-prediction":
                totals["readinessRetries"] += timing["attempts"] - 1
            for key in durations:
                durations[key] += timing[key]
            for batch in group["batches"]:
                child = directory / "batches" / batch["id"]
                summary = _load_json(
                    child / "batch-summary.json", "batch summary"
                )
                totals["batches"] += 1
                totals["comparisons"] += summary["comparisons"]
                totals["hostObservations"] += summary["hostObservations"]
                totals["failedTests"] += summary["failedTests"]
                totals["skippedTests"] += summary["skippedTests"]
                if subsystem == "inline-prediction":
                    for observation in batch["hosts"]:
                        host_summary = _load_json(
                            child / observation["row"] /
                            observation["host"] / "host-summary.json",
                            "inline host summary",
                        )
                        retries = host_summary.get("readinessAttempts", 0)
                        if type(retries) is not int or not 0 <= retries <= 19:
                            raise BatchEvidenceError(
                                "inline readiness attempt count differs")
                        totals["readinessRetries"] += retries
                children.append({
                    "groupId": group["id"],
                    "batchId": batch["id"],
                    "path": str(child.relative_to(batches_root)),
                    "attempts": timing["attempts"],
                    "comparisons": summary["comparisons"],
                    "hostObservations": summary["hostObservations"],
                })
    totals["erasedBoots"] = len(seen_boot_scopes)
    if (totals["logicalRows"] != 54 or totals["groups"] != 28 or
            totals["erasedBoots"] != 20 or totals["batches"] != 112 or
            totals["successfulXCTestInvocations"] != 28 or
            totals["successfulBoundaries"] != 344 or
            totals["successfulHostBoundaries"] != 180 or
            totals["successfulPassBoundaries"] != 84 or
            totals["successfulRowBoundaries"] != 80 or
            totals["comparisons"] != 216 or
            totals["hostObservations"] != 432):
        raise BatchEvidenceError(
            "aggregate counts differ from the frozen certification corpus"
        )
    expected_subsystem_boundaries = {
        "autocorrection": {
            "successfulBoundaries": 99,
            "successfulHostBoundaries": 48,
            "successfulPassBoundaries": 27,
            "successfulRowBoundaries": 24,
        },
        "ime": {
            "successfulBoundaries": 182,
            "successfulHostBoundaries": 96,
            "successfulPassBoundaries": 30,
            "successfulRowBoundaries": 56,
        },
        "inline-prediction": {
            "successfulBoundaries": 63,
            "successfulHostBoundaries": 36,
            "successfulPassBoundaries": 27,
            "successfulRowBoundaries": 0,
        },
    }
    if subsystem_boundaries != expected_subsystem_boundaries:
        raise BatchEvidenceError(
            "aggregate boundary inventory differs by subsystem")
    actual_subsystems = {
        path.name for path in batches_root.iterdir()
        if path.is_dir() and not path.is_symlink()
    }
    if (actual_subsystems != seen_subsystems or
            any(not path.is_dir() or path.is_symlink()
                for path in batches_root.iterdir())):
        raise BatchEvidenceError("aggregate subsystem inventory differs")
    actual_paths = set()
    for subsystem in seen_subsystems:
        subsystem_root = batches_root / subsystem
        for path in subsystem_root.iterdir():
            if not path.is_dir() or path.is_symlink():
                raise BatchEvidenceError("aggregate group inventory is invalid")
            actual_paths.add(path.resolve())
    if actual_paths != seen_paths:
        raise BatchEvidenceError("aggregate group inventory differs")
    return {
        "schema": 1,
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        "repetitions": list(REPETITIONS),
        "orders": [name for name, _ in ORDERS],
        "catalogs": catalogs,
        **totals,
        "durations": durations,
        "result": "Passed",
        "children": children,
    }


def _autocorrection_rows():
    return [
        f"{location}-{decision}"
        for location in ("interior", "before-boundary", "after-boundary")
        for decision in (
            "accept-space", "accept-punctuation", "accept-candidate",
            "reject-precommit", "undo-space", "undo-punctuation",
            "undo-candidate",
        )
    ]


def _inline_prediction_rows():
    return [
        f"{location}-{decision}"
        for location in ("interior", "before-boundary", "after-boundary")
        for decision in (
            "accept", "dismiss-then-type", "accept-then-delete",
        )
    ]


def _ime_rows():
    rows = []
    for language in ("japanese-romaji", "simplified-chinese-pinyin"):
        for location in ("interior", "before-boundary", "after-boundary"):
            for decision in (
                "candidate-commit", "cancel", "ordinary-commit",
                "return-commit-then-undo", "responder-loss",
            ):
                if (decision == "return-commit-then-undo" and
                        location == "interior"):
                    continue
                if decision == "responder-loss" and location != "before-boundary":
                    continue
                rows.append(f"{language}-{location}-{decision}")
    return rows


FROZEN_ROWS = {
    "ime": _ime_rows(),
    "autocorrection": _autocorrection_rows(),
    "inline-prediction": _inline_prediction_rows(),
}


class BatchContractError(ValueError):
    pass


class BatchEvidenceError(ValueError):
    pass


class AuthorityMismatch(BatchEvidenceError):
    pass


def _authority_fields(status, fields, label):
    missing = [field for field in fields if field not in status]
    if missing:
        raise BatchEvidenceError(
            f"{label} is missing authority fields: {missing!r}"
        )
    return {field: status[field] for field in fields}


def _canonicalize_authority_marked_range(status):
    marked_range = status.get("markedRange")
    if (isinstance(marked_range, dict) and
            marked_range.get("location") in {-1, 9223372036854775807}):
        status["markedRange"] = dict(marked_range, location=-1)


def authority_payload(subsystem, source):
    """Return comparator-authoritative semantics and numeric geometry."""
    if subsystem == "ime":
        if (not isinstance(source, dict) or source.get("schema") != 1 or
                not isinstance(source.get("phases"), list)):
            raise BatchEvidenceError("invalid IME authority lifecycle")
        semantic = {
            "decision": source.get("decision"),
            "phases": [],
        }
        geometry = {"phases": []}
        for item in source["phases"]:
            if (not isinstance(item, dict) or
                    not isinstance(item.get("phase"), str) or
                    not isinstance(item.get("status"), dict)):
                raise BatchEvidenceError("invalid IME authority phase")
            phase = item["phase"]
            status = item["status"]
            normalized = _authority_fields(
                status, IME_AUTHORITY_FIELDS, f"IME {phase} status"
            )
            _canonicalize_authority_marked_range(normalized)
            for field in ("blockIdentifiers", "anchorIdentities"):
                identities = status.get(field)
                if not isinstance(identities, list) or not identities:
                    raise BatchEvidenceError(
                        f"IME {phase} {field} is empty or invalid"
                    )
                normalized[f"{field}Count"] = len(identities)
            descriptors = status.get("temporaryRenderingDescriptors")
            if not isinstance(descriptors, list):
                raise BatchEvidenceError(
                    f"IME {phase} temporary rendering descriptors are invalid"
                )
            normalized["temporaryRenderingDescriptors"] = [{
                "range": descriptor.get("range"),
                "attributeKeys": descriptor.get("attributeKeys"),
            } for descriptor in descriptors]
            candidate = status.get("candidateDescriptor")
            if not isinstance(candidate, dict):
                raise BatchEvidenceError(
                    f"IME {phase} candidate descriptor is invalid"
                )
            normalized["candidateDescriptor"] = _authority_fields(
                candidate,
                ("visible", "actionable", "labels", "selectedLabel"),
                f"IME {phase} candidate descriptor",
            )
            if phase == "firstComposition":
                normalized["candidateDescriptor"]["labels"] = []
                normalized["candidateDescriptor"]["selectedLabel"] = ""
            keyboard = status.get("keyboardState")
            if not isinstance(keyboard, dict):
                raise BatchEvidenceError(f"IME {phase} keyboard state is invalid")
            modes = keyboard.get("enabledInputModeIdentifiers")
            if not isinstance(modes, list):
                raise BatchEvidenceError(f"IME {phase} input modes are invalid")
            normalized["keyboardState"] = {
                "visible": keyboard.get("visible"),
                "primaryLanguage": keyboard.get("primaryLanguage"),
                "requiredInputModes": {
                    name: identifier in modes
                    for name, identifier in REQUIRED_IME_INPUT_MODES.items()
                },
            }
            semantic["phases"].append({"phase": phase, "status": normalized})
            candidate_geometry = candidate.get("geometry")
            if not isinstance(candidate_geometry, dict):
                raise BatchEvidenceError(
                    f"IME {phase} candidate geometry is invalid"
                )
            geometry["phases"].append({
                "phase": phase,
                "compositionGeometry": status.get("compositionGeometry"),
                # The established IME comparator intentionally excludes x.
                "candidateGeometry": {
                    key: candidate_geometry.get(key)
                    for key in ("y", "width", "height")
                },
            })
        return semantic, geometry

    if subsystem not in {"autocorrection", "inline-prediction"}:
        raise BatchEvidenceError(f"unknown authority subsystem: {subsystem}")
    comparator_name = subsystem.replace("-", "_")
    comparator = _load_script_module(
        f"inputdec_authority_{comparator_name}",
        f"compare-{subsystem}-results.py",
    )
    if not isinstance(source, dict) or not source:
        raise BatchEvidenceError(f"invalid {subsystem} authority statuses")
    phases = [phase for phase in comparator.PHASE_ORDER if phase in source]
    if set(phases) != set(source):
        raise BatchEvidenceError(f"unknown {subsystem} authority phase")
    semantic = {"phases": []}
    geometry = {"phases": []}
    geometry_key = (
        "correctionGeometry" if subsystem == "autocorrection"
        else "predictionGeometry"
    )
    keyboard_fields = (
        ("visible", "locale", "learnedOriginal")
        if subsystem == "autocorrection" else comparator.KEYBOARD_KEYS
    )
    for phase in phases:
        status = source[phase]
        if not isinstance(status, dict):
            raise BatchEvidenceError(
                f"invalid {subsystem} {phase} authority status"
            )
        normalized = _authority_fields(
            status, comparator.SEMANTIC_KEYS,
            f"{subsystem} {phase} status",
        )
        _canonicalize_authority_marked_range(normalized)
        keyboard = status.get("keyboardState")
        if not isinstance(keyboard, dict):
            raise BatchEvidenceError(
                f"invalid {subsystem} {phase} keyboard state"
            )
        normalized["keyboardState"] = _authority_fields(
            keyboard, keyboard_fields,
            f"{subsystem} {phase} keyboard state",
        )
        semantic["phases"].append({"phase": phase, "status": normalized})
        geometry["phases"].append({
            "phase": phase,
            geometry_key: status.get(geometry_key),
        })
    return semantic, geometry


def _authority_identity(observation):
    expected_keys = {
        "subsystem", "repetition", "order", "row", "host",
        "semantic", "geometry",
    }
    if not isinstance(observation, dict) or set(observation) != expected_keys:
        raise AuthorityMismatch("authority observation keys differ")
    identity = tuple(observation[key] for key in (
        "subsystem", "repetition", "order", "row", "host"
    ))
    subsystem, repetition, order, row, host = identity
    if (subsystem not in TEST_CLASSES or repetition not in REPETITIONS or
            order not in {name for name, _ in ORDERS} or
            not isinstance(row, str) or not row or
            host not in {"stock", "custom"} or
            not isinstance(observation["semantic"], dict) or
            not isinstance(observation["geometry"], dict)):
        raise AuthorityMismatch(
            f"invalid authority observation identity: {identity!r}"
        )
    return identity


def _authority_index(corpus, label):
    expected_keys = {"schema", "runtime", "udid", "observations"}
    if not isinstance(corpus, dict) or set(corpus) != expected_keys:
        raise AuthorityMismatch(f"{label} corpus keys differ")
    if (corpus.get("schema") != 1 or corpus.get("runtime") != RUNTIME or
            corpus.get("udid") != PINNED_UDID or
            not isinstance(corpus.get("observations"), list)):
        raise AuthorityMismatch(f"{label} corpus provenance differs")
    result = {}
    for observation in corpus["observations"]:
        identity = _authority_identity(observation)
        if identity in result:
            raise AuthorityMismatch(
                f"duplicate {label} authority observation: {identity!r}"
            )
        result[identity] = observation
    return result


def _compare_geometry(actual, expected, path="geometry"):
    if type(actual) is not type(expected):
        raise AuthorityMismatch(f"{path} type differs")
    if isinstance(expected, dict):
        if set(actual) != set(expected):
            raise AuthorityMismatch(f"{path} keys differ")
        for key in expected:
            _compare_geometry(actual[key], expected[key], f"{path}.{key}")
        return
    if isinstance(expected, list):
        if len(actual) != len(expected):
            raise AuthorityMismatch(f"{path} length differs")
        for index, (actual_item, expected_item) in enumerate(
                zip(actual, expected)):
            _compare_geometry(
                actual_item, expected_item, f"{path}[{index}]"
            )
        return
    if isinstance(expected, (int, float)) and not isinstance(expected, bool):
        if (not math.isfinite(float(actual)) or
                not math.isfinite(float(expected)) or
                abs(float(actual) - float(expected)) > 1.0):
            raise AuthorityMismatch(f"{path} differs beyond 1 point")
        return
    if actual != expected:
        raise AuthorityMismatch(f"{path} differs")


def _compare_semantic(actual, expected, identity, diagnostics,
                      path="semantic"):
    if type(actual) is not type(expected):
        raise AuthorityMismatch(f"{path} type differs for {identity!r}")
    if isinstance(expected, dict):
        if set(actual) != set(expected):
            raise AuthorityMismatch(f"{path} keys differ for {identity!r}")
        for key in expected:
            field = f"{path}.{key}"
            if key == "labels" and path.endswith("candidateDescriptor"):
                if actual[key] != expected[key]:
                    diagnostics.append({
                        "identity": list(identity),
                        "field": field,
                        "batched": actual[key],
                        "fresh": expected[key],
                    })
                continue
            _compare_semantic(
                actual[key], expected[key], identity, diagnostics, field
            )
        return
    if isinstance(expected, list):
        if len(actual) != len(expected):
            raise AuthorityMismatch(f"{path} length differs for {identity!r}")
        for index, (actual_item, expected_item) in enumerate(
                zip(actual, expected)):
            _compare_semantic(
                actual_item, expected_item, identity, diagnostics,
                f"{path}[{index}]",
            )
        return
    if actual != expected:
        raise AuthorityMismatch(f"{path} differs for {identity!r}")


def compare_authority(batched, fresh):
    batched_index = _authority_index(batched, "batched")
    fresh_index = _authority_index(fresh, "fresh")
    if set(batched_index) != set(fresh_index):
        missing = sorted(set(fresh_index) - set(batched_index))
        extra = sorted(set(batched_index) - set(fresh_index))
        raise AuthorityMismatch(
            f"authority observation inventory differs: "
            f"missing={missing!r} extra={extra!r}"
        )
    diagnostics = []
    for identity in sorted(fresh_index):
        actual = batched_index[identity]
        expected = fresh_index[identity]
        _compare_semantic(
            actual["semantic"], expected["semantic"], identity, diagnostics
        )
        _compare_geometry(actual["geometry"], expected["geometry"])
    comparisons = {
        identity[:-1] for identity in fresh_index
    }
    return {
        "schema": 1,
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        "comparisons": len(comparisons),
        "hostObservations": len(fresh_index),
        "geometryTolerance": 1.0,
        "diagnosticDifferenceCount": len(diagnostics),
        "diagnosticDifferences": diagnostics,
        "result": "Passed",
    }


def _authority_catalogs():
    fixture_root = pathlib.Path(__file__).resolve().parents[1] / "UITests" / "Fixtures"
    return {
        subsystem: load_catalog(
            fixture_root / f"text-input-{subsystem}-batches-ios26.5-v1.json"
        )
        for subsystem in TEST_CLASSES
    }


def _authority_observation(subsystem, repetition, order, row, host, source):
    semantic, geometry = authority_payload(subsystem, source)
    return {
        "subsystem": subsystem,
        "repetition": repetition,
        "order": order,
        "row": row,
        "host": host,
        "semantic": semantic,
        "geometry": geometry,
    }


def _load_authority_host(subsystem, host_root):
    if subsystem == "ime":
        return _load_json(host_root / "lifecycle.json", "IME lifecycle")
    comparator = _load_script_module(
        f"inputdec_materialize_{subsystem.replace('-', '_')}",
        f"compare-{subsystem}-results.py",
    )
    try:
        attachments = host_root / "attachments"
        if not attachments.is_dir():
            attachments = host_root
        return comparator.statuses_from_export(attachments)
    except (AssertionError, OSError, ValueError) as error:
        raise BatchEvidenceError(str(error)) from error


def materialize_batched_authority(root):
    root = pathlib.Path(root)
    summary = _load_json(root / "summary.json", "batched summary")
    if (summary.get("result") != "Passed" or
            summary.get("comparisons") != 216 or
            summary.get("hostObservations") != 432):
        raise BatchEvidenceError("batched authority summary is incomplete")
    observations = []
    for subsystem, catalog in _authority_catalogs().items():
        for batch in expand_batches(catalog):
            matches = list((root / "batches" / subsystem).glob(
                f"*/batches/{batch['id']}"
            ))
            if len(matches) != 1:
                raise BatchEvidenceError(
                    f"expected one materialized batch {batch['id']}, "
                    f"found {len(matches)}"
                )
            batch_root = matches[0]
            for item in batch["hosts"]:
                row, host = item["row"], item["host"]
                source = _load_authority_host(
                    subsystem, batch_root / row / host
                )
                observations.append(_authority_observation(
                    subsystem, batch["repetition"], batch["order"],
                    row, host, source,
                ))
    corpus = {
        "schema": 1,
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        "observations": observations,
    }
    _authority_index(corpus, "batched")
    if len(observations) != 432:
        raise BatchEvidenceError(
            f"expected 432 batched authority observations, "
            f"found {len(observations)}"
        )
    return corpus


def _fresh_scenario_suffix(row):
    return "".join(component.capitalize() for component in row.split("-"))


def _ime_authority_row(lifecycle):
    phases = lifecycle.get("phases") if isinstance(lifecycle, dict) else None
    if not isinstance(phases, list) or not phases:
        raise BatchEvidenceError("fresh IME lifecycle has no phases")
    status = phases[0].get("status") if isinstance(phases[0], dict) else None
    if not isinstance(status, dict):
        raise BatchEvidenceError("fresh IME lifecycle has no baseline status")
    components = [
        status.get("language"), status.get("location"),
        status.get("decision"),
    ]
    if any(not isinstance(component, str) or not component
           for component in components):
        raise BatchEvidenceError("fresh IME lifecycle identity is invalid")
    return "-".join(components)


def materialize_fresh_authority(root):
    root = pathlib.Path(root)
    summary = _load_json(root / "summary.json", "fresh authority summary")
    if (summary.get("overallResult") != "Passed" or
            summary.get("comparisonCount") != 216 or
            summary.get("hostExecutionCount") != 432):
        raise BatchEvidenceError("fresh authority summary is incomplete")
    observations = []
    order_names = {
        "stock-custom": "StockThenCustom",
        "custom-stock": "CustomThenStock",
    }
    for subsystem, catalog in _authority_catalogs().items():
        subsystem_root = root / subsystem
        for repetition in REPETITIONS:
            for order, ordered_hosts in ORDERS:
                for row in catalog["rows"]:
                    if subsystem == "ime":
                        row_roots = []
                        for candidate in subsystem_root.glob(
                                f"{order}-*/repetition-{repetition}/row-*"):
                            lifecycle_path = candidate / "stock/lifecycle.json"
                            if not lifecycle_path.is_file():
                                continue
                            lifecycle = _load_json(
                                lifecycle_path, "fresh IME stock lifecycle"
                            )
                            if _ime_authority_row(lifecycle) == row:
                                row_roots.append(candidate)
                    else:
                        row_roots = [
                            subsystem_root /
                            f"repeat-{repetition}-{order_names[order]}-"
                            f"{_fresh_scenario_suffix(row)}"
                        ]
                        if not row_roots[0].is_dir():
                            row_roots = []
                    if len(row_roots) != 1:
                        raise BatchEvidenceError(
                            f"expected one fresh authority row for "
                            f"{subsystem}/{repetition}/{order}/{row}, "
                            f"found {len(row_roots)}"
                        )
                    for host in ordered_hosts:
                        if subsystem == "ime":
                            host_root = row_roots[0] / host
                        else:
                            host_root = row_roots[0] / f"{host}-attachments"
                        source = _load_authority_host(subsystem, host_root)
                        observations.append(_authority_observation(
                            subsystem, repetition, order, row, host, source,
                        ))
    corpus = {
        "schema": 1,
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        "observations": observations,
    }
    _authority_index(corpus, "fresh")
    if len(observations) != 432:
        raise BatchEvidenceError(
            f"expected 432 fresh authority observations, "
            f"found {len(observations)}"
        )
    return corpus


def _exact_keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != expected:
        actual = sorted(value) if isinstance(value, dict) else type(value).__name__
        raise BatchContractError(
            f"{label} keys differ: expected={sorted(expected)!r} actual={actual!r}"
        )


def _string_list(value, label):
    if (not isinstance(value, list) or
            any(not isinstance(item, str) or not item for item in value)):
        raise BatchContractError(f"{label} must be a nonempty-string array")


def load_catalog(path):
    path = pathlib.Path(path)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise BatchContractError(f"cannot load catalog {path}: {error}") from error
    validate_catalog(value)
    return value


def validate_catalog(catalog):
    _exact_keys(catalog, TOP_LEVEL_KEYS, "top-level")
    if isinstance(catalog["schema"], bool) or catalog["schema"] != 1:
        raise BatchContractError("schema must equal integer 1")
    if catalog["runtime"] != RUNTIME:
        raise BatchContractError(f"runtime must equal {RUNTIME!r}")
    if catalog["udid"] != PINNED_UDID:
        raise BatchContractError(f"udid must equal {PINNED_UDID}")
    subsystem = catalog["subsystem"]
    if subsystem not in FROZEN_ROWS:
        raise BatchContractError(f"unsupported subsystem: {subsystem!r}")
    _string_list(catalog["rows"], "rows")
    expected_rows = FROZEN_ROWS[subsystem]
    if catalog["rows"] != expected_rows:
        raise BatchContractError(
            f"{subsystem} frozen rows differ: "
            f"expected={expected_rows!r} actual={catalog['rows']!r}"
        )
    if not isinstance(catalog["groups"], list) or not catalog["groups"]:
        raise BatchContractError("groups must be a nonempty array")

    group_ids = []
    grouped_rows = []
    for index, group in enumerate(catalog["groups"]):
        label = f"groups[{index}]"
        _exact_keys(group, GROUP_KEYS, label)
        identifier = group["id"]
        if not isinstance(identifier, str) or IDENTIFIER.fullmatch(identifier) is None:
            raise BatchContractError(f"{label}.id is invalid: {identifier!r}")
        group_ids.append(identifier)
        rows = group["rows"]
        _string_list(rows, f"{label}.rows")
        if not rows:
            raise BatchContractError(f"{label}.rows must be nonempty")
        state_sensitive = group["stateSensitive"]
        if type(state_sensitive) is not bool:
            raise BatchContractError(f"{label}.stateSensitive must be boolean")
        maximum = 3 if state_sensitive else 12
        if len(rows) > maximum:
            raise BatchContractError(
                f"{label}.rows must contain at most {maximum} rows"
            )
        if group["resetPolicy"] != RESET_POLICY:
            raise BatchContractError(
                f"{label}.resetPolicy must equal {RESET_POLICY!r}"
            )
        language = group["language"]
        if subsystem == "ime":
            valid_languages = (
                "japanese-romaji", "simplified-chinese-pinyin",
            )
            if language not in valid_languages:
                raise BatchContractError(f"{label}.language is invalid")
            if any(not row.startswith(f"{language}-") for row in rows):
                raise BatchContractError(
                    f"{label}.language does not match all grouped rows"
                )
        elif language != "en-US":
            raise BatchContractError(f"{label}.language must equal 'en-US'")
        grouped_rows.extend(rows)

    if len(group_ids) != len(set(group_ids)):
        raise BatchContractError("duplicate group id")
    if grouped_rows != catalog["rows"]:
        raise BatchContractError(
            "grouped rows must cover frozen rows exactly once in frozen order"
        )


def execution_groups(catalog):
    validate_catalog(catalog)
    if catalog["subsystem"] != "inline-prediction":
        return [dict(group) for group in catalog["groups"]]
    return [
        {
            "id": row,
            "language": "en-US",
            "rows": [row],
            "stateSensitive": True,
            "resetPolicy": RESET_POLICY,
        }
        for row in catalog["rows"]
    ]


def expand_batches(catalog):
    groups = execution_groups(catalog)
    result = []
    for repetition in REPETITIONS:
        for order, ordered_hosts in ORDERS:
            for group in groups:
                if group.get("repetition", repetition) != repetition:
                    continue
                if group.get("order", order) != order:
                    continue
                observations = [
                    {"row": row, "host": host}
                    for row in group["rows"]
                    for host in ordered_hosts
                ]
                result.append({
                    "id": (
                        f"{catalog['subsystem']}--r{repetition}--"
                        f"{order}--{group['id']}"
                    ),
                    "subsystem": catalog["subsystem"],
                    "language": group["language"],
                    "rows": list(group["rows"]),
                    "hosts": observations,
                    "repetition": repetition,
                    "order": order,
                    "stateSensitive": group["stateSensitive"],
                    "resetPolicy": group["resetPolicy"],
                    "expectedHostObservations": len(observations),
                })
    return result


def logical_groups(catalog):
    """Return execution groups, sharing one snapshot boot for inline rows."""
    groups = execution_groups(catalog)
    expanded = expand_batches(catalog)
    result = []
    for source_group in groups:
        suffix = f"--{source_group['id']}"
        batches = [
            batch for batch in expanded
            if batch["id"].endswith(suffix)
        ]
        inline_prediction = catalog["subsystem"] == "inline-prediction"
        if inline_prediction and (
                len(source_group["rows"]) != 1 or len(batches) != 4 or
                [(batch["repetition"], batch["order"])
                 for batch in batches] != [
                    (1, "stock-custom"), (1, "custom-stock"),
                    (2, "stock-custom"), (2, "custom-stock"),
                ] or
                sum(len(batch["hosts"]) for batch in batches) != 8):
            raise BatchContractError(
                "inline snapshot row inventory is not canonical")
        group_scope = "snapshot-row-v1" if inline_prediction else "group"
        logical_group = {
            "id": (
                f"{catalog['subsystem']}--{group_scope}--"
                f"{source_group['id']}"
            ),
            "subsystem": catalog["subsystem"],
            "language": source_group["language"],
            "rows": list(source_group["rows"]),
            "stateSensitive": source_group["stateSensitive"],
            "resetPolicy": source_group["resetPolicy"],
            "batches": batches,
        }
        result.append(logical_group)
    return result


def boot_scope(group):
    if (not isinstance(group, dict) or
            not isinstance(group.get("id"), str) or
            not isinstance(group.get("subsystem"), str)):
        raise BatchContractError("logical group boot scope is invalid")
    if group["subsystem"] == "inline-prediction":
        if not group["id"].startswith(
                "inline-prediction--snapshot-row-v1--"):
            raise BatchContractError(
                "inline logical group is not snapshot-row-v1")
        return "inline-prediction--keyboard-snapshot-v1"
    return group["id"]


def _load_json(path, label):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise BatchEvidenceError(f"cannot read {label} {path}: {error}") from error


def _attachment_path(export_root, attachment):
    filename = attachment.get("exportedFileName")
    if (not isinstance(filename, str) or not filename or
            pathlib.PurePath(filename).name != filename):
        raise BatchEvidenceError(f"invalid exported attachment filename: {filename!r}")
    path = export_root / filename
    if not path.is_file():
        raise BatchEvidenceError(f"missing exported attachment: {path}")
    return path


def _load_script_module(name, filename):
    path = pathlib.Path(__file__).resolve().parent / filename
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _expected_test_identifier(subsystem):
    return f"{TEST_CLASSES[subsystem]}/testBatchedCertification"


def _write_json(path, value):
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _snapshot_observations(group):
    if (not isinstance(group, dict) or
            group.get("subsystem") != "inline-prediction" or
            not isinstance(group.get("id"), str) or
            not group["id"].startswith(
                "inline-prediction--snapshot-row-v1--") or
            not isinstance(group.get("batches"), list) or
            len(group["batches"]) != 4):
        raise BatchEvidenceError("snapshot observation group is invalid")
    result = []
    for batch in group["batches"]:
        hosts = batch.get("hosts") if isinstance(batch, dict) else None
        if not isinstance(hosts, list) or len(hosts) != 2:
            raise BatchEvidenceError("snapshot batch observations differ")
        for observation in hosts:
            result.append({
                "observationIndex": len(result) + 1,
                "batchId": batch["id"],
                "rowId": observation["row"],
                "host": observation["host"],
            })
    if len(result) != 8:
        raise BatchEvidenceError("snapshot group must contain eight observations")
    return result


def _validated_checkpoint_package(package, expected):
    if package.is_symlink() or not package.is_dir():
        raise BatchEvidenceError(f"checkpoint package is invalid: {package}")
    manifest_path = package / "manifest.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise BatchEvidenceError(f"checkpoint manifest is missing: {package}")
    manifest = _load_json(manifest_path, "checkpoint manifest")
    if (not isinstance(manifest, dict) or set(manifest) != {"schema", "files"} or
            manifest.get("schema") != 1 or
            not isinstance(manifest.get("files"), list)):
        raise BatchEvidenceError("checkpoint manifest contract differs")
    actual_files = []
    for child in package.rglob("*"):
        if child.is_symlink():
            raise BatchEvidenceError("checkpoint contains a symbolic link")
        if child.is_file():
            if child != manifest_path:
                actual_files.append(child.relative_to(package).as_posix())
        elif not child.is_dir():
            raise BatchEvidenceError("checkpoint contains a special file")
    actual_files.sort()
    declared = []
    for entry in manifest["files"]:
        if (not isinstance(entry, dict) or
                set(entry) != {"path", "size", "sha256"} or
                not isinstance(entry.get("path"), str) or
                pathlib.PurePosixPath(entry["path"]).is_absolute() or
                ".." in pathlib.PurePosixPath(entry["path"]).parts or
                type(entry.get("size")) is not int or entry["size"] < 0 or
                not isinstance(entry.get("sha256"), str) or
                HEX_64.fullmatch(entry["sha256"]) is None):
            raise BatchEvidenceError("checkpoint manifest entry differs")
        path = package / entry["path"]
        if (path.is_symlink() or not path.is_file() or
                path.stat().st_size != entry["size"] or
                _sha256(path) != entry["sha256"]):
            raise BatchEvidenceError("checkpoint file hash differs")
        declared.append(entry["path"])
    if declared != sorted(set(declared)) or declared != actual_files:
        raise BatchEvidenceError("checkpoint file inventory differs")

    metadata = _load_json(package / "metadata.json", "checkpoint metadata")
    expected_metadata = {
        "schema": 1,
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        **expected,
        "successfulAttempt": metadata.get("successfulAttempt")
            if isinstance(metadata, dict) else None,
        "result": "complete",
    }
    if (metadata != expected_metadata or
            type(metadata.get("successfulAttempt")) is not int or
            not 1 <= metadata["successfulAttempt"] <= 20):
        raise BatchEvidenceError("checkpoint metadata identity differs")

    attachment_root = package / "attachments"
    status_files = sorted(attachment_root.glob(
        "inline-prediction-*-status.json"))
    screenshot_files = sorted(attachment_root.glob(
        "inline-prediction-*.png"))
    hierarchy = attachment_root / "hierarchy.txt"
    if not status_files or not screenshot_files or not hierarchy.is_file():
        raise BatchEvidenceError("checkpoint canonical evidence is incomplete")
    return {"metadata": metadata, "package": package,
            "statuses": status_files, "screenshots": screenshot_files,
            "hierarchy": hierarchy}


def _validated_snapshot_checkpoints(checkpoints, group, require_complete):
    checkpoints = pathlib.Path(checkpoints)
    if checkpoints.is_symlink() or not checkpoints.is_dir():
        raise BatchEvidenceError("snapshot checkpoint root is invalid")
    expected = _snapshot_observations(group)
    packages = sorted(checkpoints.iterdir(), key=lambda path: path.name)
    if any(not re.fullmatch(r"observation-\d{3}\.checkpoint", path.name)
           for path in packages):
        raise BatchEvidenceError("unknown snapshot checkpoint entry")
    indexes = [int(path.name[12:15]) for path in packages]
    if indexes != list(range(1, len(indexes) + 1)):
        raise BatchEvidenceError("completed observations are not contiguous")
    if len(indexes) > len(expected) or (require_complete and len(indexes) != 8):
        raise BatchEvidenceError("snapshot checkpoint prefix is incomplete")
    return [
        _validated_checkpoint_package(package, expected[index - 1])
        for index, package in zip(indexes, packages)
    ]


def snapshot_observation_resume_indexes(checkpoints, group):
    validated = _validated_snapshot_checkpoints(
        checkpoints, group, require_complete=False
    )
    return list(range(1, len(validated) + 1))


def _validated_observation_attempt_map(export_root, attachments, group,
                                       checkpoints):
    matches = [
        attachment for attachment in attachments
        if _matches_exported_attachment_name(
            attachment.get("suggestedHumanReadableName"),
            "observation-attempts", "json")
    ]
    if len(matches) != 1:
        raise BatchEvidenceError("expected one observation attempt map")
    value = _load_json(
        _attachment_path(export_root, matches[0]), "observation attempt map"
    )
    expected = _snapshot_observations(group)
    entries = value.get("observations") if isinstance(value, dict) else None
    if (not isinstance(value, dict) or
            set(value) != {"schema", "groupId", "observations"} or
            value.get("schema") != 1 or value.get("groupId") != group["id"] or
            not isinstance(entries, list) or len(entries) > 8):
        raise BatchEvidenceError("observation attempt map contract differs")
    entry_indexes = [
        entry.get("observationIndex") if isinstance(entry, dict) else None
        for entry in entries
    ]
    first_entry = 9 - len(entries)
    if entry_indexes != list(range(first_entry, 9)):
        raise BatchEvidenceError(
            "observation attempt map must be a contiguous suffix")
    entries_by_index = {
        entry["observationIndex"]: entry for entry in entries
    }
    sanitized = []
    for identity, checkpoint in zip(expected, checkpoints):
        entry = entries_by_index.get(identity["observationIndex"])
        if entry is None:
            successful = checkpoint["metadata"]["successfulAttempt"]
            sanitized.append({
                **identity,
                "successfulAttempt": successful,
                "readinessAttempts": successful - 1,
            })
            continue
        expected_entry = {
            **identity,
            "successfulAttempt": entry.get("successfulAttempt")
                if isinstance(entry, dict) else None,
            "readinessAttempts": entry.get("readinessAttempts")
                if isinstance(entry, dict) else None,
        }
        successful = expected_entry["successfulAttempt"]
        if (entry != expected_entry or type(successful) is not int or
                not 1 <= successful <= 20 or
                expected_entry["readinessAttempts"] != successful - 1 or
                checkpoint["metadata"]["successfulAttempt"] != successful):
            raise BatchEvidenceError("observation attempt sequence differs")
        sanitized.append(expected_entry)
    return matches[0], sanitized


def _materialize_host(export_root, attachments, destination, observation,
                      xcresult):
    destination.mkdir(parents=True)
    copied = []
    names = set()
    has_status = False
    has_screenshot = False
    has_hierarchy = False
    lifecycle_path = None
    for index, (attachment, stripped_name) in enumerate(attachments):
        if stripped_name in names:
            raise BatchEvidenceError(
                f"duplicate attachment for {observation}: {stripped_name}"
            )
        names.add(stripped_name)
        source = _attachment_path(export_root, attachment)
        suffix = pathlib.Path(source.name).suffix
        filename = f"attachment-{index:03d}{suffix}"
        shutil.copy2(source, destination / filename)
        copied.append({
            "exportedFileName": filename,
            "suggestedHumanReadableName": stripped_name,
        })
        if "-status_" in stripped_name:
            has_status = True
        if (stripped_name.startswith("autocorrection-") or
                stripped_name.startswith("inline-prediction-") or
                stripped_name.startswith("ime-composition-")) and not (
                    "-status_" in stripped_name
                ):
            has_screenshot = True
        if _matches_exported_attachment_name(
                stripped_name, "hierarchy", "txt"):
            has_hierarchy = True
        if _matches_exported_attachment_name(
                stripped_name, "ime-lifecycle", "json"):
            lifecycle_path = destination / filename
    subsystem = observation["subsystem"]
    if subsystem == "ime":
        if lifecycle_path is None:
            raise BatchEvidenceError(f"missing IME lifecycle for {observation}")
    elif not has_status:
        raise BatchEvidenceError(f"missing status attachment for {observation}")
    if not has_screenshot:
        raise BatchEvidenceError(f"missing screenshot attachment for {observation}")
    if not has_hierarchy:
        raise BatchEvidenceError(f"missing hierarchy attachment for {observation}")
    _write_json(destination / "manifest.json", [{
        "testIdentifier": _expected_test_identifier(subsystem),
        "attachments": copied,
    }])
    _write_json(destination.parent / "host-summary.json", {
        "schema": 1,
        "row": observation["row"],
        "host": observation["host"],
        "batchId": observation["batchId"],
        "xcresult": str(xcresult),
        "attachmentCount": len(copied),
    })
    if lifecycle_path is not None:
        shutil.copy2(lifecycle_path, destination.parent / "lifecycle.json")


def _compare_row(subsystem, row_root, xcresult):
    stock = row_root / "stock" / "attachments"
    custom = row_root / "custom" / "attachments"
    if subsystem == "autocorrection":
        comparator = _load_script_module(
            "inputdec_compare_autocorrection",
            "compare-autocorrection-results.py",
        )
        return comparator.compare_exported_directories(
            stock, custom, row_root, xcresult, xcresult
        )
    if subsystem == "inline-prediction":
        comparator = _load_script_module(
            "inputdec_compare_inline_prediction",
            "compare-inline-prediction-results.py",
        )
        return comparator.compare_exported_directories(
            stock, custom, row_root, xcresult, xcresult
        )
    comparator = _load_script_module(
        "inputdec_compare_ime", "compare-ime-composition-results.py"
    )
    stock_lifecycle = _load_json(
        row_root / "stock" / "lifecycle.json", "stock lifecycle"
    )
    custom_lifecycle = _load_json(
        row_root / "custom" / "lifecycle.json", "custom lifecycle"
    )
    comparison = comparator.compare_lifecycles(
        stock_lifecycle, custom_lifecycle, 1.0
    )
    _write_json(row_root / "comparison.json", comparison)
    return comparison


def extract_batch(export_root, batch, output, xcresult):
    export_root = pathlib.Path(export_root)
    output = pathlib.Path(output)
    xcresult = pathlib.Path(xcresult)
    if output.exists():
        raise BatchEvidenceError(f"refusing existing output: {output}")
    manifest = _load_json(export_root / "manifest.json", "export manifest")
    if not isinstance(manifest, list) or len(manifest) != 1:
        raise BatchEvidenceError("export manifest must contain exactly one test")
    test = manifest[0]
    if test.get("testIdentifier") != _expected_test_identifier(
            batch["subsystem"]):
        raise BatchEvidenceError("unexpected batch test identifier")
    attachments = test.get("attachments")
    if not isinstance(attachments, list):
        raise BatchEvidenceError("export manifest has no attachment array")
    metadata_attachments = [
        attachment for attachment in attachments
        if _matches_exported_attachment_name(
            attachment.get("suggestedHumanReadableName"),
            "batch-metadata",
            "json",
        )
    ]
    if len(metadata_attachments) != 1:
        raise BatchEvidenceError("expected exactly one batch metadata attachment")
    metadata = _load_json(
        _attachment_path(export_root, metadata_attachments[0]),
        "batch metadata",
    )
    expected_metadata = {
        "schema": 1,
        "batchId": batch["id"],
        "subsystem": batch["subsystem"],
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        "observations": batch["hosts"],
    }
    if metadata != expected_metadata:
        if metadata.get("observations") != batch["hosts"]:
            raise BatchEvidenceError("batch metadata observation order differs")
        raise BatchEvidenceError("batch metadata contract differs")

    expected = [(item["row"], item["host"]) for item in batch["hosts"]]
    grouped = {identity: [] for identity in expected}
    for attachment in attachments:
        name = attachment.get("suggestedHumanReadableName")
        if attachment in metadata_attachments:
            continue
        if not isinstance(name, str):
            raise BatchEvidenceError("attachment name is not a string")
        match = ATTACHMENT.fullmatch(name)
        if match is None:
            raise BatchEvidenceError(f"unknown batch attachment name: {name}")
        identity = (match.group("row"), match.group("host"))
        if identity not in grouped:
            raise BatchEvidenceError(f"unexpected row/host attachment: {identity}")
        grouped[identity].append((attachment, match.group("name")))

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = pathlib.Path(tempfile.mkdtemp(
        prefix=f".{output.name}.partial-", dir=output.parent
    ))
    try:
        for row, host in expected:
            observation = {
                "subsystem": batch["subsystem"],
                "batchId": batch["id"],
                "row": row,
                "host": host,
            }
            _materialize_host(
                export_root,
                grouped[(row, host)],
                temporary / row / host / "attachments",
                observation,
                xcresult,
            )
        comparisons = []
        for row in batch["rows"]:
            comparisons.append(
                _compare_row(batch["subsystem"], temporary / row, xcresult)
            )
        summary = {
            "schema": 1,
            "runtime": RUNTIME,
            "udid": PINNED_UDID,
            "batchId": batch["id"],
            "subsystem": batch["subsystem"],
            "observedHosts": batch["hosts"],
            "comparisons": len(comparisons),
            "hostObservations": len(expected),
            "failedTests": 0,
            "skippedTests": 0,
            "result": "Passed",
        }
        _write_json(temporary / "batch-summary.json", summary)
        temporary.replace(output)
        return summary
    except (BatchEvidenceError, AssertionError, OSError, ValueError) as error:
        shutil.rmtree(temporary, ignore_errors=True)
        if isinstance(error, BatchEvidenceError):
            raise
        raise BatchEvidenceError(str(error)) from error


def _validated_group_boundaries(group, boundaries, token_sha256):
    try:
        plan = group_protocol.boundary_plan(group)
    except group_protocol.ProtocolError as error:
        raise BatchEvidenceError(f"invalid group boundary plan: {error}") from error
    if not isinstance(boundaries, list) or len(boundaries) != len(plan):
        raise BatchEvidenceError(
            f"expected exactly {len(plan)} successful boundaries")
    if (not isinstance(token_sha256, str) or
            HEX_64.fullmatch(token_sha256) is None):
        raise BatchEvidenceError("group token hash is invalid")
    sanitized = []
    for identity, boundary in zip(plan, boundaries):
        expected_keys = {
            "schema", "token", "groupId", "resetSummarySHA256", "result",
            *identity.keys(),
        }
        if not isinstance(boundary, dict) or set(boundary) != expected_keys:
            raise BatchEvidenceError("boundary response keys differ")
        token = boundary.get("token")
        if (type(boundary.get("schema")) is not int or
                boundary.get("schema") != 2 or
                boundary.get("groupId") != group["id"] or
                any(boundary.get(key) != value
                    for key, value in identity.items()) or
                boundary.get("result") != "ready" or
                not isinstance(token, str) or HEX_64.fullmatch(token) is None or
                not isinstance(boundary.get("resetSummarySHA256"), str) or
                HEX_64.fullmatch(boundary["resetSummarySHA256"]) is None):
            raise BatchEvidenceError("boundary response sequence differs")
        if hashlib.sha256(token.encode("utf-8")).hexdigest() != token_sha256:
            raise BatchEvidenceError("boundary token hash differs")
        sanitized.append({
            **identity,
            "resetSummarySHA256": boundary["resetSummarySHA256"],
            "result": "ready",
        })
    return sanitized


def _checkpoint_batch_export(pass_export, export_root, partition, batch,
                             checkpoint_by_identity):
    pass_attachments = []
    metadata = [
        (attachment, name) for attachment, name in partition
        if _matches_exported_attachment_name(name, "batch-metadata", "json")
    ]
    if len(metadata) != 1:
        raise BatchEvidenceError("snapshot batch metadata differs")
    source = _attachment_path(export_root, metadata[0][0])
    destination = pass_export / f"attachment-{len(pass_attachments):03d}.json"
    shutil.copy2(source, destination)
    pass_attachments.append({
        "exportedFileName": destination.name,
        "suggestedHumanReadableName": metadata[0][1],
    })
    for observation in batch["hosts"]:
        identity = (batch["id"], observation["row"], observation["host"])
        checkpoint = checkpoint_by_identity[identity]
        prefix = f"batch--{observation['row']}--{observation['host']}--"
        for status in checkpoint["statuses"]:
            phase = status.name[len("inline-prediction-"):-len("-status.json")]
            destination = pass_export / (
                f"attachment-{len(pass_attachments):03d}.json"
            )
            shutil.copy2(status, destination)
            pass_attachments.append({
                "exportedFileName": destination.name,
                "suggestedHumanReadableName": (
                    prefix + f"inline-prediction-{phase}-status_checkpoint.json"
                ),
            })
        for screenshot in checkpoint["screenshots"]:
            phase = screenshot.name[len("inline-prediction-"):-len(".png")]
            destination = pass_export / (
                f"attachment-{len(pass_attachments):03d}.png"
            )
            shutil.copy2(screenshot, destination)
            pass_attachments.append({
                "exportedFileName": destination.name,
                "suggestedHumanReadableName": (
                    prefix + f"inline-prediction-{phase}_checkpoint.png"
                ),
            })
        destination = pass_export / (
            f"attachment-{len(pass_attachments):03d}.txt"
        )
        shutil.copy2(checkpoint["hierarchy"], destination)
        pass_attachments.append({
            "exportedFileName": destination.name,
            "suggestedHumanReadableName": prefix + "hierarchy.txt",
        })
    _write_json(pass_export / "manifest.json", [{
        "testIdentifier": _expected_test_identifier(batch["subsystem"]),
        "attachments": pass_attachments,
    }])


def _materialize_snapshot_attempt_evidence(export_root, partition,
                                           batch_output, batch,
                                           checkpoint_by_identity,
                                           attempt_by_identity):
    diagnostics = {}
    for attachment, stripped_name in partition:
        match = ATTACHMENT.fullmatch(stripped_name)
        if match is None:
            continue
        attempt_match = re.match(r"attempt-(\d{3})--(.+)$", match.group("name"))
        if attempt_match is None:
            continue
        identity = (batch["id"], match.group("row"), match.group("host"))
        diagnostics.setdefault(identity, {}).setdefault(
            int(attempt_match.group(1)), []
        ).append((attachment, attempt_match.group(2)))

    for observation in batch["hosts"]:
        identity = (batch["id"], observation["row"], observation["host"])
        attempt = attempt_by_identity[identity]
        successful = attempt["successfulAttempt"]
        host_root = batch_output / observation["row"] / observation["host"]
        host_summary_path = host_root / "host-summary.json"
        host_summary = _load_json(host_summary_path, "host summary")
        host_summary["successfulAttempt"] = successful
        host_summary["readinessAttempts"] = attempt["readinessAttempts"]
        _write_json(host_summary_path, host_summary)

        checkpoint = checkpoint_by_identity[identity]
        for status in checkpoint["statuses"]:
            phase = status.name[len("inline-prediction-"):-len("-status.json")]
            shutil.copy2(status, host_root / "attachments" /
                         f"{phase}-status.json")
        for screenshot in checkpoint["screenshots"]:
            phase = screenshot.name[len("inline-prediction-"):-len(".png")]
            shutil.copy2(screenshot, host_root / "attachments" / f"{phase}.png")

        attempts = dict(diagnostics.get(identity, {}))
        successful_provenance = attempts.pop(successful, [])
        if any(index > successful for index in attempts):
            raise BatchEvidenceError(
                "xcresult contains a post-success observation attempt")
        if set(attempts) != set(range(1, successful)):
            raise BatchEvidenceError("readiness attempt evidence has a gap")
        for index in range(1, successful):
            attempt_root = (host_root / "readiness-attempts" /
                            f"attempt-{index:03d}" / "attachments")
            attempt_root.mkdir(parents=True)
            copied = []
            for offset, (attachment, name) in enumerate(attempts[index]):
                source = _attachment_path(export_root, attachment)
                destination = attempt_root / f"attachment-{offset:03d}{source.suffix}"
                shutil.copy2(source, destination)
                copied.append({
                    "exportedFileName": destination.name,
                    "suggestedHumanReadableName": name,
                })
            _write_json(attempt_root / "manifest.json", [{
                "testIdentifier": _expected_test_identifier(batch["subsystem"]),
                "attachments": copied,
            }])
        if successful_provenance:
            provenance_root = (host_root / "xcresult-provenance" /
                               f"attempt-{successful:03d}" / "attachments")
            provenance_root.mkdir(parents=True)
            copied = []
            for offset, (attachment, name) in enumerate(successful_provenance):
                source = _attachment_path(export_root, attachment)
                destination = (provenance_root /
                               f"attachment-{offset:03d}{source.suffix}")
                shutil.copy2(source, destination)
                copied.append({
                    "exportedFileName": destination.name,
                    "suggestedHumanReadableName": name,
                })
            _write_json(provenance_root / "manifest.json", [{
                "testIdentifier": _expected_test_identifier(batch["subsystem"]),
                "attachments": copied,
            }])


def extract_group(export_root, group, output, xcresult, boundaries,
                  checkpoints=None):
    export_root = pathlib.Path(export_root)
    output = pathlib.Path(output)
    xcresult = pathlib.Path(xcresult)
    if output.exists():
        raise BatchEvidenceError(f"refusing existing output: {output}")
    batches = group.get("batches") if isinstance(group, dict) else None
    if not isinstance(batches, list):
        raise BatchEvidenceError("group batches must be an array")
    try:
        group_protocol.boundary_plan(group)
    except group_protocol.ProtocolError as error:
        raise BatchEvidenceError(f"invalid group batch inventory: {error}") from error
    expected_ids = [batch["id"] for batch in batches]
    if len(set(expected_ids)) != len(expected_ids):
        raise BatchEvidenceError("group batch identifiers must be unique")

    manifest = _load_json(export_root / "manifest.json", "export manifest")
    if not isinstance(manifest, list) or len(manifest) != 1:
        raise BatchEvidenceError("export manifest must contain exactly one test")
    test = manifest[0]
    if not isinstance(test, dict):
        raise BatchEvidenceError("export manifest test is not an object")
    if test.get("testIdentifier") != _expected_test_identifier(
            group["subsystem"]):
        raise BatchEvidenceError("unexpected group test identifier")
    attachments = test.get("attachments")
    if not isinstance(attachments, list):
        raise BatchEvidenceError("export manifest has no attachment array")

    is_snapshot_group = (
        group.get("subsystem") == "inline-prediction" and
        isinstance(group.get("id"), str) and
        group["id"].startswith("inline-prediction--snapshot-row-v1--")
    )
    if is_snapshot_group and checkpoints is None:
        raise BatchEvidenceError(
            "inline snapshot extraction requires checkpoint packages")

    snapshot_checkpoints = None
    attempt_map_attachment = None
    attempt_entries = None
    if checkpoints is not None:
        snapshot_checkpoints = _validated_snapshot_checkpoints(
            checkpoints, group, require_complete=True
        )
        attempt_map_attachment, attempt_entries = (
            _validated_observation_attempt_map(
                export_root, attachments, group, snapshot_checkpoints
            )
        )

    group_metadata_attachments = []
    metadata_order = []
    partitions = {batch_id: [] for batch_id in expected_ids}
    for attachment in attachments:
        if not isinstance(attachment, dict):
            raise BatchEvidenceError("group attachment is not an object")
        name = attachment.get("suggestedHumanReadableName")
        if attachment is attempt_map_attachment:
            continue
        if _matches_exported_attachment_name(name, "group-metadata", "json"):
            group_metadata_attachments.append(attachment)
            continue
        metadata_match = GROUP_METADATA.fullmatch(name) if isinstance(name, str) else None
        if metadata_match is not None:
            batch_id = metadata_match.group("batch")
            if batch_id not in partitions:
                raise BatchEvidenceError(f"unexpected group metadata pass: {batch_id}")
            metadata_order.append(batch_id)
            stripped = re.sub(r"^group--.*--metadata", "batch-metadata", name)
            partitions[batch_id].append((attachment, stripped))
            continue
        host_match = GROUP_ATTACHMENT.fullmatch(name) if isinstance(name, str) else None
        if host_match is None:
            if _is_reset_induced_testmanager_crash(export_root, attachment):
                continue
            raise BatchEvidenceError(f"unknown group attachment name: {name}")
        batch_id = host_match.group("batch")
        if batch_id not in partitions:
            raise BatchEvidenceError(f"unexpected group attachment pass: {batch_id}")
        stripped = (
            f"batch--{host_match.group('row')}--{host_match.group('host')}--"
            f"{host_match.group('name')}"
        )
        partitions[batch_id].append((attachment, stripped))

    if len(group_metadata_attachments) != 1:
        raise BatchEvidenceError("expected exactly one group metadata attachment")
    # xcresulttool exports XCTest attachments newest-first. The group metadata
    # and boundary responses certify execution chronology; the manifest must
    # therefore contain the same pass metadata attachments in reverse catalog
    # order.
    if metadata_order != list(reversed(expected_ids)):
        raise BatchEvidenceError("group metadata pass order differs")
    group_metadata = _load_json(
        _attachment_path(export_root, group_metadata_attachments[0]),
        "group metadata",
    )
    if not isinstance(group_metadata, dict):
        raise BatchEvidenceError("group metadata is not an object")
    expected_group_metadata = {
        "schema": 1,
        "groupId": group["id"],
        "subsystem": group["subsystem"],
        "runtime": RUNTIME,
        "udid": PINNED_UDID,
        "tokenSHA256": group_metadata.get("tokenSHA256"),
        "batches": expected_ids,
    }
    if group_metadata != expected_group_metadata:
        raise BatchEvidenceError("group metadata contract differs")
    sanitized_boundaries = _validated_group_boundaries(
        group, boundaries, group_metadata["tokenSHA256"]
    )

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = pathlib.Path(tempfile.mkdtemp(
        prefix=f".{output.name}.partial-", dir=output.parent
    ))
    try:
        batch_summaries = []
        checkpoint_by_identity = {}
        attempt_by_identity = {}
        if snapshot_checkpoints is not None:
            checkpoint_by_identity = {
                (item["metadata"]["batchId"], item["metadata"]["rowId"],
                 item["metadata"]["host"]): item
                for item in snapshot_checkpoints
            }
            attempt_by_identity = {
                (item["batchId"], item["rowId"], item["host"]): item
                for item in attempt_entries
            }
        for batch in batches:
            batch_id = batch["id"]
            pass_export = temporary / "pass-exports" / batch_id
            pass_export.mkdir(parents=True)
            if snapshot_checkpoints is None:
                pass_attachments = []
                for index, (attachment, stripped_name) in enumerate(
                        partitions[batch_id]):
                    source = _attachment_path(export_root, attachment)
                    destination_name = f"attachment-{index:03d}{source.suffix}"
                    shutil.copy2(source, pass_export / destination_name)
                    pass_attachments.append({
                        "exportedFileName": destination_name,
                        "suggestedHumanReadableName": stripped_name,
                    })
                _write_json(pass_export / "manifest.json", [{
                    "testIdentifier": _expected_test_identifier(
                        group["subsystem"]),
                    "attachments": pass_attachments,
                }])
            else:
                _checkpoint_batch_export(
                    pass_export, export_root, partitions[batch_id], batch,
                    checkpoint_by_identity,
                )
            batch_output = temporary / "batches" / batch_id
            batch_summaries.append(extract_batch(
                pass_export, batch, batch_output, xcresult
            ))
            if snapshot_checkpoints is not None:
                _materialize_snapshot_attempt_evidence(
                    export_root, partitions[batch_id], batch_output, batch,
                    checkpoint_by_identity, attempt_by_identity,
                )
        shutil.rmtree(temporary / "pass-exports")
        summary = {
            "schema": 1,
            "runtime": RUNTIME,
            "udid": PINNED_UDID,
            "groupId": group["id"],
            "subsystem": group["subsystem"],
            "tokenSHA256": group_metadata["tokenSHA256"],
            "batchIds": expected_ids,
            "batches": len(batch_summaries),
            "comparisons": sum(item["comparisons"] for item in batch_summaries),
            "hostObservations": sum(
                item["hostObservations"] for item in batch_summaries
            ),
            "successfulBoundaries": len(sanitized_boundaries),
            "boundaries": sanitized_boundaries,
            "successfulHostBoundaries": sum(
                item["kind"] == "host" for item in sanitized_boundaries
            ),
            "successfulPassBoundaries": sum(
                item["kind"] == "pass" for item in sanitized_boundaries
            ),
            "successfulRowBoundaries": sum(
                item["kind"] == "row" for item in sanitized_boundaries
            ),
            "hostBoundaries": [
                item for item in sanitized_boundaries
                if item["kind"] == "host"
            ],
            "passBoundaries": [
                item for item in sanitized_boundaries
                if item["kind"] == "pass"
            ],
            "rowBoundaries": [
                item for item in sanitized_boundaries
                if item["kind"] == "row"
            ],
            "failedTests": 0,
            "skippedTests": 0,
            "result": "Passed",
        }
        _write_json(temporary / "group-summary.json", summary)
        temporary.replace(output)
        return summary
    except (BatchEvidenceError, AssertionError, OSError, ValueError) as error:
        shutil.rmtree(temporary, ignore_errors=True)
        if isinstance(error, BatchEvidenceError):
            raise
        raise BatchEvidenceError(str(error)) from error


def _summary(catalog):
    expanded = expand_batches(catalog)
    return {
        "subsystem": catalog["subsystem"],
        "logicalRows": len(catalog["rows"]),
        "batches": len(expanded),
        "comparisons": len(catalog["rows"]) * len(REPETITIONS) * len(ORDERS),
        "hostObservations": sum(
            batch["expectedHostObservations"] for batch in expanded
        ),
    }


def _parser():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate")
    validate.add_argument("catalog")
    listing = commands.add_parser("list")
    listing.add_argument("catalog")
    listing.add_argument("--state-sensitive", action="store_true")
    show = commands.add_parser("show")
    show.add_argument("catalog")
    show.add_argument("batch_id")
    list_groups = commands.add_parser("list-groups")
    list_groups.add_argument("catalog")
    show_group = commands.add_parser("show-group")
    show_group.add_argument("catalog")
    show_group.add_argument("group_id")
    extract = commands.add_parser("extract")
    extract.add_argument("--catalog", required=True)
    extract.add_argument("--batch-id", required=True)
    extract.add_argument("--attachments", required=True)
    extract.add_argument("--output", required=True)
    extract.add_argument("--xcresult", required=True)
    extract_group_command = commands.add_parser("extract-group")
    extract_group_command.add_argument("--catalog", required=True)
    extract_group_command.add_argument("--group-id", required=True)
    extract_group_command.add_argument("--attachments", required=True)
    extract_group_command.add_argument("--output", required=True)
    extract_group_command.add_argument("--xcresult", required=True)
    extract_group_command.add_argument("--boundaries", required=True)
    extract_group_command.add_argument("--checkpoints")
    state = commands.add_parser("fingerprint")
    state.add_argument("--udid", required=True)
    state.add_argument("--device-root", required=True)
    state.add_argument("--provisioning-summary", required=True)
    state.add_argument("--output", required=True)
    resume = commands.add_parser("resume-check")
    resume.add_argument("--catalog", required=True)
    resume.add_argument("--batch-id", required=True)
    resume.add_argument("--directory", required=True)
    group_resume = commands.add_parser("group-resume-check")
    group_resume.add_argument("--catalog", required=True)
    group_resume.add_argument("--group-id", required=True)
    group_resume.add_argument("--directory", required=True)
    observation_resume = commands.add_parser("observation-resume-check")
    observation_resume.add_argument("--catalog", required=True)
    observation_resume.add_argument("--group-id", required=True)
    observation_resume.add_argument("--directory", required=True)
    group_summary = commands.add_parser("write-group-summary")
    group_summary.add_argument("--catalog", required=True)
    group_summary.add_argument("--group-id", required=True)
    group_summary.add_argument("--directory", required=True)
    group_summary.add_argument("--erase-boot-seconds", type=int, default=0)
    group_summary.add_argument("--total-seconds", type=int, default=0)
    aggregate = commands.add_parser("aggregate")
    aggregate.add_argument("--catalog", action="append", required=True)
    aggregate.add_argument("--batches-root", required=True)
    aggregate.add_argument("--output", required=True)
    authority = commands.add_parser("compare-authority")
    authority.add_argument("--batched", required=True)
    authority.add_argument("--fresh", required=True)
    authority.add_argument("--output", required=True)
    materialize = commands.add_parser("materialize-authority")
    materialize.add_argument(
        "--source", required=True, choices=("batched", "fresh")
    )
    materialize.add_argument("--root", required=True)
    materialize.add_argument("--output", required=True)
    return parser


def main(argv=None):
    arguments = _parser().parse_args(argv)
    try:
        if arguments.command == "fingerprint":
            result = fingerprint(
                arguments.udid,
                pathlib.Path(arguments.device_root),
                pathlib.Path(arguments.provisioning_summary),
                pathlib.Path(arguments.output),
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        if arguments.command == "aggregate":
            output = pathlib.Path(arguments.output)
            if output.exists():
                raise BatchEvidenceError(f"refusing existing output: {output}")
            result = aggregate_certification(
                arguments.catalog, pathlib.Path(arguments.batches_root)
            )
            output.parent.mkdir(parents=True, exist_ok=True)
            with output.open("x", encoding="utf-8") as stream:
                json.dump(result, stream, indent=2, sort_keys=True)
                stream.write("\n")
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        if arguments.command == "compare-authority":
            output = pathlib.Path(arguments.output)
            if output.exists():
                raise BatchEvidenceError(f"refusing existing output: {output}")
            corpora = []
            for label, raw in (
                    ("batched", arguments.batched), ("fresh", arguments.fresh)):
                root = pathlib.Path(raw)
                if root.is_symlink() or not root.is_dir():
                    raise BatchEvidenceError(
                        f"{label} authority root is invalid: {root}"
                    )
                corpora.append(_load_json(
                    root / "authority-observations.json",
                    f"{label} authority observations",
                ))
            result = compare_authority(corpora[0], corpora[1])
            output.parent.mkdir(parents=True, exist_ok=True)
            with output.open("x", encoding="utf-8") as stream:
                json.dump(result, stream, indent=2, sort_keys=True)
                stream.write("\n")
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        if arguments.command == "materialize-authority":
            output = pathlib.Path(arguments.output)
            if output.exists():
                raise BatchEvidenceError(f"refusing existing output: {output}")
            root = pathlib.Path(arguments.root)
            if root.is_symlink() or not root.is_dir():
                raise BatchEvidenceError(
                    f"authority source root is invalid: {root}"
                )
            if arguments.source == "batched":
                result = materialize_batched_authority(root)
            else:
                result = materialize_fresh_authority(root)
            output.parent.mkdir(parents=True, exist_ok=True)
            with output.open("x", encoding="utf-8") as stream:
                json.dump(result, stream, indent=2, sort_keys=True)
                stream.write("\n")
            print(json.dumps({
                "result": "Passed",
                "source": arguments.source,
                "observations": len(result["observations"]),
                "output": str(output),
            }, indent=2, sort_keys=True))
            return 0
        catalog = load_catalog(arguments.catalog)
        batches = expand_batches(catalog)
        groups = logical_groups(catalog)
        if arguments.command in {
                "show-group", "extract-group", "group-resume-check",
                "observation-resume-check", "write-group-summary"}:
            matches = [
                group for group in groups if group["id"] == arguments.group_id
            ]
            if len(matches) != 1:
                raise BatchContractError(
                    f"unknown group id: {arguments.group_id}"
                )
            group = matches[0]
            if arguments.command == "show-group":
                print(json.dumps(group, indent=2, sort_keys=True))
                return 0
            if arguments.command == "extract-group":
                result = extract_group(
                    pathlib.Path(arguments.attachments), group,
                    pathlib.Path(arguments.output),
                    pathlib.Path(arguments.xcresult),
                    _load_json(pathlib.Path(arguments.boundaries),
                               "group boundaries"),
                    checkpoints=(pathlib.Path(arguments.checkpoints)
                                 if arguments.checkpoints else None),
                )
                print(json.dumps(result, indent=2, sort_keys=True))
                return 0
            if arguments.command == "observation-resume-check":
                indexes = snapshot_observation_resume_indexes(
                    pathlib.Path(arguments.directory), group
                )
                print(",".join(str(index) for index in indexes))
                return 0
            if arguments.command == "group-resume-check":
                if not group_is_resumable(arguments.directory, group):
                    raise BatchEvidenceError(
                        f"group is not resumable: {arguments.group_id}"
                    )
                print(f"RESUMABLE {arguments.group_id}")
                return 0
            result = write_group_summary(
                arguments.directory, group,
                erase_boot_seconds=arguments.erase_boot_seconds,
                total_seconds=arguments.total_seconds,
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        if arguments.command == "extract":
            matches = [
                batch for batch in batches
                if batch["id"] == arguments.batch_id
            ]
            if len(matches) != 1:
                raise BatchContractError(
                    f"unknown batch id: {arguments.batch_id}"
                )
            summary = extract_batch(
                pathlib.Path(arguments.attachments), matches[0],
                pathlib.Path(arguments.output),
                pathlib.Path(arguments.xcresult),
            )
            print(json.dumps(summary, indent=2, sort_keys=True))
            return 0
        if arguments.command == "resume-check":
            matches = [
                batch for batch in batches
                if batch["id"] == arguments.batch_id
            ]
            if len(matches) != 1:
                raise BatchContractError(
                    f"unknown batch id: {arguments.batch_id}"
                )
            if not batch_is_resumable(arguments.directory, matches[0]):
                raise BatchEvidenceError(
                    f"batch is not resumable: {arguments.batch_id}"
                )
            print(f"RESUMABLE {arguments.batch_id}")
            return 0
        if arguments.command == "validate":
            summary = _summary(catalog)
            print(
                "VALID " + " ".join(
                    f"{key}={value}" for key, value in summary.items()
                )
            )
            return 0
        if arguments.command == "list":
            for batch in batches:
                if arguments.state_sensitive and not batch["stateSensitive"]:
                    continue
                print(batch["id"])
            return 0
        if arguments.command == "list-groups":
            for group in groups:
                print(group["id"])
            return 0
        matches = [
            batch for batch in batches if batch["id"] == arguments.batch_id
        ]
        if len(matches) != 1:
            raise BatchContractError(
                f"unknown batch id: {arguments.batch_id}"
            )
        print(json.dumps(matches[0], indent=2, sort_keys=True))
        return 0
    except (BatchContractError, BatchEvidenceError, OSError,
            sqlite3.Error) as error:
        print(f"text-input batch contract failed: {error}", file=sys.stderr)
        return 65


if __name__ == "__main__":
    raise SystemExit(main())
