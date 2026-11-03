#!/usr/bin/env python3

import argparse
import json
import math
import pathlib


FIXTURE_KEYS = {
    "schema", "runtime", "language", "inputModeIdentifier",
    "primaryLanguage", "canonicalDocument", "interiorOffset",
    "beforeBoundaryOffset", "afterBoundaryOffset", "physicalKeySequence",
    "firstComposition", "updatedComposition", "markedSelections",
    "candidateAction", "candidateLabel",
    "candidateAccessibilityIdentity", "committedText",
    "ordinaryCommitAction", "ordinaryCommitResult", "cancelAction",
    "cancelResult", "returnAction", "returnCommitResult", "undoAction",
    "undoResult", "responderLossResult", "geometryTolerance",
}
ACTION_KEYS = {"kind", "value", "accessibilityIdentity"}
GEOMETRY_KEYS = {"x", "y", "width", "height"}


class TruthError(AssertionError):
    pass


def exact_keys(value, expected, context):
    if not isinstance(value, dict):
        raise TruthError(f"{context} must be an object")
    actual = set(value)
    if actual != set(expected):
        raise TruthError(
            f"{context} keys differ: "
            f"missing={sorted(set(expected) - actual)} "
            f"extra={sorted(actual - set(expected))}"
        )


def nonempty_string(value, context):
    if not isinstance(value, str) or not value:
        raise TruthError(f"{context} must be a nonempty string")


def nonnegative_integer(value, context):
    if type(value) is not int or value < 0:
        raise TruthError(f"{context} must be a nonnegative integer")


def validate_action(value, context):
    exact_keys(value, ACTION_KEYS, context)
    for key in ACTION_KEYS:
        nonempty_string(value[key], f"{context}.{key}")


def validate_geometry(value, context):
    exact_keys(value, GEOMETRY_KEYS, context)
    for key in GEOMETRY_KEYS:
        number = value[key]
        if isinstance(number, bool) or not isinstance(number, (int, float)):
            raise TruthError(f"{context}.{key} must be a finite number")
        if not math.isfinite(number):
            raise TruthError(f"{context}.{key} must be finite")
    if value["width"] < 0 or value["height"] < 0:
        raise TruthError(f"{context} size must be nonnegative")


def validate_range(value, upper_bound, context):
    exact_keys(value, {"location", "length"}, context)
    nonnegative_integer(value["location"], f"{context}.location")
    nonnegative_integer(value["length"], f"{context}.length")
    if value["location"] + value["length"] > upper_bound:
        raise TruthError(f"{context} exceeds its marked text")


def validate_fixture(value):
    exact_keys(value, FIXTURE_KEYS, "fixture")
    if type(value["schema"]) is not int or value["schema"] != 1:
        raise TruthError("fixture.schema must equal integer 1")
    if value["runtime"] != {"osVersion": "26.5", "osBuild": "23F73"}:
        raise TruthError("fixture.runtime must equal iOS 26.5 (23F73)")
    nonempty_string(value["language"], "fixture.language")
    for key in (
        "inputModeIdentifier", "primaryLanguage", "canonicalDocument",
        "firstComposition", "updatedComposition", "candidateLabel",
        "candidateAccessibilityIdentity", "committedText",
        "ordinaryCommitResult", "cancelResult", "returnCommitResult",
        "undoResult", "responderLossResult",
    ):
        nonempty_string(value[key], f"fixture.{key}")
    canonical = value["canonicalDocument"]
    boundary = canonical.find("\n")
    if boundary < 0:
        raise TruthError("fixture canonical document needs a boundary")
    for key in (
        "interiorOffset", "beforeBoundaryOffset", "afterBoundaryOffset",
    ):
        nonnegative_integer(value[key], f"fixture.{key}")
        if value[key] > len(canonical):
            raise TruthError(f"fixture.{key} exceeds the canonical document")
    if value["beforeBoundaryOffset"] != boundary:
        raise TruthError("fixture.beforeBoundaryOffset differs from newline")
    if value["afterBoundaryOffset"] != boundary + 1:
        raise TruthError("fixture.afterBoundaryOffset differs from newline")
    keys = value["physicalKeySequence"]
    if not isinstance(keys, list) or len(keys) < 2:
        raise TruthError("fixture.physicalKeySequence is incomplete")
    for index, key in enumerate(keys):
        nonempty_string(key, f"fixture.physicalKeySequence[{index}]")
    selections = value["markedSelections"]
    if not isinstance(selections, list) or len(selections) != 2:
        raise TruthError("fixture.markedSelections must contain two ranges")
    validate_range(
        selections[0], len(value["firstComposition"]),
        "fixture.markedSelections[0]")
    validate_range(
        selections[1], len(value["updatedComposition"]),
        "fixture.markedSelections[1]")
    for key in (
        "candidateAction", "ordinaryCommitAction", "cancelAction",
        "returnAction", "undoAction",
    ):
        validate_action(value[key], f"fixture.{key}")
    tolerance = value["geometryTolerance"]
    if (isinstance(tolerance, bool) or
            not isinstance(tolerance, (int, float)) or
            not math.isfinite(tolerance) or tolerance < 0):
        raise TruthError(
            "fixture.geometryTolerance must be finite and nonnegative")
    return value


def validate_observation(value):
    exact_keys(
        value,
        {"schema", "fixture", "candidateGeometry", "compositionGeometry"},
        "observation",
    )
    if type(value["schema"]) is not int or value["schema"] != 1:
        raise TruthError("observation.schema must equal integer 1")
    validate_fixture(value["fixture"])
    validate_geometry(value["candidateGeometry"],
                      "observation.candidateGeometry")
    validate_geometry(value["compositionGeometry"],
                      "observation.compositionGeometry")
    return value


def load_observation(attachment_directory):
    attachment_directory = pathlib.Path(attachment_directory)
    manifest_path = attachment_directory / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise TruthError(
            f"cannot read attachment manifest {manifest_path}: {error}"
        ) from error
    if not isinstance(manifest, list):
        raise TruthError("attachment manifest must be an array")
    matches = []
    for test in manifest:
        if not isinstance(test, dict):
            raise TruthError("attachment manifest test must be an object")
        attachments = test.get("attachments")
        if not isinstance(attachments, list):
            raise TruthError("attachment manifest attachments must be an array")
        for attachment in attachments:
            if not isinstance(attachment, dict):
                raise TruthError("attachment record must be an object")
            name = attachment.get("suggestedHumanReadableName")
            if isinstance(name, str) and name.startswith(
                    "ime-stock-contract-observation"):
                filename = attachment.get("exportedFileName")
                nonempty_string(filename, "observation attachment filename")
                matches.append(attachment_directory / filename)
    if len(matches) != 1:
        raise TruthError(
            "expected exactly one observation attachment, "
            f"found {len(matches)}")
    try:
        payload = json.loads(matches[0].read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise TruthError(
            f"cannot read observation attachment {matches[0]}: {error}"
        ) from error
    return validate_observation(payload)


def compare_observations(attachment_directories, expected_language):
    paths = [pathlib.Path(path) for path in attachment_directories]
    if not paths:
        raise TruthError("at least one observation is required")
    observations = [load_observation(path) for path in paths]
    fixture = observations[0]["fixture"]
    if fixture["language"] != expected_language:
        raise TruthError(
            f"wrong observation language: {fixture['language']!r}")
    for index, observation in enumerate(observations[1:], start=2):
        if observation["fixture"] != fixture:
            raise TruthError(
                f"semantic disagreement in observation {index}")

    tolerance = fixture["geometryTolerance"]
    for geometry_key in ("candidateGeometry", "compositionGeometry"):
        for component in GEOMETRY_KEYS:
            values = [
                observation[geometry_key][component]
                for observation in observations
            ]
            if max(values) - min(values) > tolerance:
                raise TruthError(
                    f"geometry disagreement for "
                    f"{geometry_key}.{component}: {values!r}")
    return {
        "schema": 1,
        "language": expected_language,
        "observationCount": len(observations),
        "fixture": fixture,
        "candidateGeometries": [
            value["candidateGeometry"] for value in observations
        ],
        "compositionGeometries": [
            value["compositionGeometry"] for value in observations
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--language", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("attachment_directories", nargs="+")
    arguments = parser.parse_args()
    output = pathlib.Path(arguments.output)
    if output.exists():
        raise SystemExit(f"refusing existing agreement output: {output}")
    try:
        agreement = compare_observations(
            arguments.attachment_directories, arguments.language)
    except TruthError as error:
        raise SystemExit(f"invalid IME stock truth: {error}") from error
    output.write_text(
        json.dumps(agreement, indent=2, ensure_ascii=False, sort_keys=True)
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
