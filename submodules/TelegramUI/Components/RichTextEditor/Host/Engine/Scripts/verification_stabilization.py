#!/usr/bin/env python3

import argparse
import json
import pathlib


PREFLIGHT_IDENTIFIER = (
    "InputDecTests/IDSpellingReadinessProbeTests/"
    "testStockTextViewSpellingEnvironmentIsReady"
)
FAILURE_PREFIX = "IDSpellingReadiness:stockUnavailable:"
OBSERVATION_KEYS = {
    "schema", "status", "continuousCheckingEnabled",
    "temporaryAnnotationObserved", "markerPixelCount", "elapsedSeconds",
    "currentPrimaryLanguage", "inputPrimaryLanguage",
    "word", "wordRange", "firstRect", "markerROI",
}
STATUSES = {
    "ready", "inputModeMismatch", "continuousCheckingDisabled",
    "temporaryAnnotationUnavailable", "markerRenderingUnavailable",
}
RECT_KEYS = {"x", "y", "width", "height"}
RANGE_KEYS = {"location", "length"}


class EvidenceError(ValueError):
    pass


def _load_json(path, description):
    path = pathlib.Path(path)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise EvidenceError(f"invalid {description}: {path}: {error}") from error
    if not isinstance(value, dict):
        raise EvidenceError(f"{description} must be an object")
    return value


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _validate_numeric_object(value, keys, description):
    if not isinstance(value, dict) or set(value) != keys:
        raise EvidenceError(f"{description} has wrong schema")
    if any(not _is_number(item) for item in value.values()):
        raise EvidenceError(f"{description} values must be numeric")


def validate_observation(value):
    if set(value) != OBSERVATION_KEYS or value.get("schema") != 2:
        raise EvidenceError("spelling observation has wrong schema")
    status = value.get("status")
    if status not in STATUSES:
        raise EvidenceError(f"unknown spelling status: {status}")
    for key in ("continuousCheckingEnabled", "temporaryAnnotationObserved"):
        if type(value.get(key)) is not bool:
            raise EvidenceError(f"{key} must be boolean")
    for key in ("currentPrimaryLanguage", "inputPrimaryLanguage"):
        if not isinstance(value.get(key), str):
            raise EvidenceError(f"{key} must be text")
    if (not isinstance(value.get("markerPixelCount"), int) or
            isinstance(value.get("markerPixelCount"), bool) or
            value["markerPixelCount"] < 0):
        raise EvidenceError("markerPixelCount must be a nonnegative integer")
    if not _is_number(value.get("elapsedSeconds")):
        raise EvidenceError("elapsedSeconds must be numeric")
    if value.get("word") != "wrng":
        raise EvidenceError("unexpected spelling probe word")
    _validate_numeric_object(value.get("wordRange"), RANGE_KEYS, "wordRange")
    _validate_numeric_object(value.get("firstRect"), RECT_KEYS, "firstRect")
    _validate_numeric_object(value.get("markerROI"), RECT_KEYS, "markerROI")
    if value["wordRange"] != {"location": 10, "length": 4}:
        raise EvidenceError("unexpected spelling probe range")
    languages_match = (
        value["currentPrimaryLanguage"] == "en-US" and
        value["inputPrimaryLanguage"] == "en-US"
    )
    if languages_match != (status != "inputModeMismatch"):
        raise EvidenceError("spelling input-mode evidence contradicts its status")
    if status != "inputModeMismatch":
        expected = {
            "ready": (True, True, True),
            "continuousCheckingDisabled": (False, False, False),
            "temporaryAnnotationUnavailable": (True, False, False),
            "markerRenderingUnavailable": (True, True, False),
        }[status]
        actual = (
            value["continuousCheckingEnabled"],
            value["temporaryAnnotationObserved"],
            value["markerPixelCount"] > 0,
        )
        if actual != expected:
            raise EvidenceError("spelling observation contradicts its status")
    return value


def _observation_path(attachments):
    attachments = pathlib.Path(attachments)
    exact = attachments / "stock-spelling-readiness.json"
    if exact.is_file() and not exact.is_symlink():
        return exact
    manifest = attachments / "manifest.json"
    if manifest.is_file():
        try:
            value = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise EvidenceError(f"invalid attachment manifest: {error}") from error
        if isinstance(value, list):
            entries = [
                attachment
                for test in value
                if isinstance(test, dict)
                for attachment in test.get("attachments", [])
            ]
        elif isinstance(value, dict):
            entries = value.get("attachments")
            if entries is None and isinstance(value.get("tests"), list):
                entries = [
                    attachment
                    for test in value["tests"]
                    if isinstance(test, dict)
                    for attachment in test.get("attachments", [])
                ]
        else:
            raise EvidenceError("attachment manifest has wrong schema")
        if isinstance(entries, list):
            matches = []
            for entry in entries:
                if not isinstance(entry, dict):
                    continue
                suggested = (entry.get("suggestedHumanReadableName") or
                             entry.get("suggestedName"))
                if (suggested == "stock-spelling-readiness.json" or
                        (isinstance(suggested, str) and
                         suggested.startswith("stock-spelling-readiness_") and
                         suggested.endswith(".json"))):
                    name = entry.get("exportedFileName") or entry.get("filename")
                    if isinstance(name, str):
                        matches.append(attachments / name)
            if len(matches) == 1 and matches[0].is_file():
                return matches[0]
    candidates = list(attachments.glob("stock-spelling-readiness_*.json"))
    if len(candidates) == 1 and candidates[0].is_file():
        return candidates[0]
    raise EvidenceError("missing unique stock-spelling-readiness.json attachment")


def _validate_preflight_metadata(value):
    required = {
        "schema", "identifier", "executed", "passed", "failed",
        "skipped", "crashed", "failures",
    }
    if set(value) != required or value.get("schema") != 1:
        raise EvidenceError("preflight metadata has wrong schema")
    if value.get("identifier") != PREFLIGHT_IDENTIFIER:
        raise EvidenceError("preflight identifier differs")
    for key in ("executed", "passed", "failed", "skipped"):
        if not isinstance(value.get(key), int) or isinstance(value.get(key), bool):
            raise EvidenceError(f"preflight {key} must be an integer")
    if type(value.get("crashed")) is not bool:
        raise EvidenceError("preflight crashed must be boolean")
    if (value["executed"] != 1 or value["skipped"] != 0 or
            value["crashed"] or value["passed"] + value["failed"] != 1 or
            not isinstance(value["failures"], list) or
            any(not isinstance(item, str) for item in value["failures"])):
        raise EvidenceError("preflight did not execute exactly once without a leak")


def _normalize_preflight_metadata(value):
    if "identifier" in value:
        return value
    required = {
        "totalTestCount", "passedTests", "failedTests", "skippedTests",
        "testFailures",
    }
    if not required.issubset(value):
        raise EvidenceError("xcresult preflight summary has wrong schema")
    failures = value["testFailures"]
    if not isinstance(failures, list):
        raise EvidenceError("xcresult preflight failures must be an array")
    identifiers = [item.get("testIdentifierString", "")
                   for item in failures if isinstance(item, dict)]
    if identifiers and not all(identifier.endswith(
            "IDSpellingReadinessProbeTests/"
            "testStockTextViewSpellingEnvironmentIsReady")
            for identifier in identifiers):
        raise EvidenceError("xcresult contains an unrelated failed test")
    return {
        "schema": 1,
        "identifier": PREFLIGHT_IDENTIFIER,
        "executed": value["totalTestCount"],
        "passed": value["passedTests"],
        "failed": value["failedTests"],
        "skipped": value["skippedTests"],
        "crashed": value["totalTestCount"] != 1,
        "failures": [item.get("failureText", "") for item in failures
                     if isinstance(item, dict)],
    }


def classify_preflight(xcresult, attachments):
    metadata = _normalize_preflight_metadata(
        _load_json(xcresult, "preflight metadata")
    )
    _validate_preflight_metadata(metadata)
    observation = validate_observation(
        _load_json(_observation_path(attachments), "spelling observation")
    )
    status = observation["status"]
    if metadata["passed"] == 1:
        if status != "ready" or metadata["failures"]:
            raise EvidenceError("passed preflight lacks ready evidence")
        classification = "ready"
    else:
        expected_prefix = FAILURE_PREFIX + status
        failure = metadata["failures"][0] if metadata["failures"] else ""
        has_readiness_prefix = (
            failure.startswith(expected_prefix) or
            f" - {expected_prefix}" in failure
        )
        if (status == "ready" or len(metadata["failures"]) != 1 or
                not has_readiness_prefix):
            raise EvidenceError("failed preflight is not a stock readiness failure")
        classification = "stockUnavailable"
    return {
        "schema": 1,
        "classification": classification,
        "status": status,
        "metadataArtifact": str(pathlib.Path(xcresult)),
        "attachmentArtifact": str(_observation_path(attachments)),
        "observation": observation,
    }


def _write_create_only(path, value):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def _validate_family(value):
    keys = {"schema", "executed", "passed", "failed", "skipped", "crashed"}
    if set(value) != keys or value.get("schema") != 1:
        raise EvidenceError("family metadata has wrong schema")
    for key in ("executed", "passed", "failed", "skipped"):
        if not isinstance(value.get(key), int) or isinstance(value.get(key), bool):
            raise EvidenceError(f"family {key} must be an integer")
    if type(value.get("crashed")) is not bool:
        raise EvidenceError("family crashed must be boolean")
    if (min(value["executed"], value["passed"], value["failed"],
            value["skipped"]) < 0 or
            value["passed"] + value["failed"] + value["skipped"] !=
            value["executed"]):
        raise EvidenceError("spelling family counts are inconsistent")


def _normalize_family(value):
    if set(value) == {
            "schema", "executed", "passed", "failed", "skipped", "crashed"}:
        return value
    required = {
        "totalTestCount", "passedTests", "failedTests", "skippedTests",
        "testFailures",
    }
    if not required.issubset(value):
        raise EvidenceError("xcresult family summary has wrong schema")
    return {
        "schema": 1,
        "executed": value["totalTestCount"],
        "passed": value["passedTests"],
        "failed": value["failedTests"],
        "skipped": value["skippedTests"],
        "crashed": value["totalTestCount"] != 5,
    }


def write_summary(output, attempt_one, attempt_two, family_result,
                  service_restarts=None, semantic_retries=0):
    first = _load_json(attempt_one, "attempt one classification")
    second = (_load_json(attempt_two, "attempt two classification")
              if attempt_two else None)
    family = (_normalize_family(_load_json(family_result, "family metadata"))
              if family_result else None)
    attempts = 2 if second is not None else 1
    if service_restarts is None:
        service_restarts = 1 if second is not None else 0
    if attempts > 2 or service_restarts > 1 or semantic_retries != 0:
        raise EvidenceError("retry budget exceeded")
    if first.get("classification") not in {"ready", "stockUnavailable"}:
        raise EvidenceError("invalid first attempt classification")
    final = second if second is not None else first
    if second is not None:
        if (first.get("classification") != "stockUnavailable" or
                second.get("classification") not in
                {"ready", "stockUnavailable"} or service_restarts != 1):
            raise EvidenceError("invalid second preflight attempt")
    elif service_restarts != 0:
        raise EvidenceError("restart without a second preflight")

    classification = final["classification"]
    result = "Blocked" if classification == "stockUnavailable" else "Passed"
    if classification == "ready":
        if family is None:
            raise EvidenceError("ready preflight requires family evidence")
        _validate_family(family)
        if (family["crashed"] or family["skipped"] or
                family["executed"] != 5):
            classification = "testStateLeak"
            result = "Failed"
        elif family["failed"]:
            classification = "customDivergence"
            result = "Failed"
    elif family is not None:
        raise EvidenceError("unavailable stock service cannot have family evidence")

    summary = {
        "schema": 1,
        "result": result,
        "classification": classification,
        "preflightAttempts": attempts,
        "serviceRestarts": service_restarts,
        "semanticRetries": semantic_retries,
        "firstAttemptArtifact": str(pathlib.Path(attempt_one)),
        "familyArtifact": str(pathlib.Path(family_result)) if family_result else None,
    }
    _write_create_only(output, summary)
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    classify = commands.add_parser("classify-preflight")
    classify.add_argument("--xcresult", required=True)
    classify.add_argument("--attachments", required=True)
    classify.add_argument("--output", required=True)
    summary = commands.add_parser("write-summary")
    summary.add_argument("--output", required=True)
    summary.add_argument("--attempt-one", required=True)
    summary.add_argument("--attempt-two")
    summary.add_argument("--family-result")
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "classify-preflight":
            value = classify_preflight(arguments.xcresult, arguments.attachments)
            _write_create_only(arguments.output, value)
        else:
            write_summary(arguments.output, arguments.attempt_one,
                          arguments.attempt_two, arguments.family_result)
    except (EvidenceError, FileExistsError) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
