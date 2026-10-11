#!/usr/bin/env python3
import json
import math
import pathlib
import re
import subprocess
import sys


SEMANTIC_KEYS = (
    "canonical",
    "blocks",
    "selection",
    "affinity",
    "markedRange",
    "structuralNewlineLocations",
    "checkingRanges",
    "predictionDescriptor",
    "temporaryRenderingDescriptors",
    "firstResponder",
)
KEYBOARD_KEYS = ("visible", "locale", "inlinePredictionEnabled")
PHASE_ORDER = (
    "baseline",
    "offered",
    "decision",
    "immediate",
    "quiesced",
    "postDismissTyping",
    "firstBackspace",
    "secondBackspace",
)
STATUS_NAME = re.compile(r"inline-prediction-(.+)-status_")


def assert_equal(stock, custom, label):
    if stock != custom:
        raise AssertionError(
            f"{label}: stock={stock!r} custom={custom!r}"
        )


def statuses_from_export(directory):
    manifest_path = directory / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    if not isinstance(manifest, list) or len(manifest) != 1:
        count = len(manifest) if isinstance(manifest, list) else "non-list"
        raise AssertionError(
            f"expected exactly one test manifest in {directory}, found {count}"
        )
    attachments = manifest[0].get("attachments")
    if not isinstance(attachments, list):
        raise AssertionError(f"missing attachment list in {manifest_path}")
    statuses = {}
    for attachment in attachments:
        if not isinstance(attachment, dict):
            raise AssertionError(f"malformed attachment in {manifest_path}")
        name = attachment.get("suggestedHumanReadableName", "")
        match = STATUS_NAME.match(name)
        if match is None:
            continue
        phase = match.group(1)
        if phase in statuses:
            raise AssertionError(f"duplicate {phase} status in {directory}")
        filename = attachment.get("exportedFileName")
        if not isinstance(filename, str) or not filename:
            raise AssertionError(f"missing exported filename for {phase}")
        payload = json.loads((directory / filename).read_text())
        if not isinstance(payload, dict):
            raise AssertionError(f"{phase} status is not an object")
        statuses[phase] = payload
    if not statuses:
        raise AssertionError(f"no inline-prediction statuses in {directory}")
    return statuses


def compare_geometry(stock, custom, phase):
    assert_equal(
        set(stock), set(custom), f"{phase}.predictionGeometry keys"
    )
    for component in stock:
        stock_value = float(stock[component])
        custom_value = float(custom[component])
        if not math.isfinite(stock_value) or not math.isfinite(custom_value):
            raise AssertionError(
                f"{phase}.predictionGeometry.{component} is not finite"
            )
        if abs(stock_value - custom_value) > 1.0:
            raise AssertionError(
                f"{phase}.predictionGeometry.{component}: "
                f"stock={stock_value} custom={custom_value}"
            )


def compare_exported_directories(
    stock_directory,
    custom_directory,
    output,
    stock_bundle,
    custom_bundle,
):
    stock = statuses_from_export(stock_directory)
    custom = statuses_from_export(custom_directory)
    assert_equal(set(stock), set(custom), "phase set")
    phases = [phase for phase in PHASE_ORDER if phase in stock]
    assert_equal(set(phases), set(stock), "known phase set")
    for phase in phases:
        for key in SEMANTIC_KEYS:
            assert_equal(
                stock[phase][key],
                custom[phase][key],
                f"{phase}.{key}",
            )
        for key in KEYBOARD_KEYS:
            assert_equal(
                stock[phase]["keyboardState"][key],
                custom[phase]["keyboardState"][key],
                f"{phase}.keyboardState.{key}",
            )
        compare_geometry(
            stock[phase]["predictionGeometry"],
            custom[phase]["predictionGeometry"],
            phase,
        )
    summary = {
        "schema": 1,
        "stockBundle": str(stock_bundle),
        "customBundle": str(custom_bundle),
        "phases": phases,
        "semanticKeys": list(SEMANTIC_KEYS),
        "keyboardKeys": list(KEYBOARD_KEYS),
        "geometryTolerance": 1.0,
        "result": "passed",
    }
    output.mkdir(parents=True, exist_ok=True)
    parity = output / "parity.json"
    if parity.exists():
        raise AssertionError(f"refusing to replace {parity}")
    parity.write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def export_statuses(bundle, destination):
    if destination.exists():
        raise AssertionError(f"refusing to replace {destination}")
    subprocess.run(
        [
            "xcrun",
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            str(bundle),
            "--output-path",
            str(destination),
        ],
        check=True,
    )


def main():
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: compare-inline-prediction-results.py "
            "STOCK_XCRESULT CUSTOM_XCRESULT OUTPUT"
        )
    stock_bundle = pathlib.Path(sys.argv[1])
    custom_bundle = pathlib.Path(sys.argv[2])
    output = pathlib.Path(sys.argv[3])
    stock_export = output / "stock-attachments"
    custom_export = output / "custom-attachments"
    export_statuses(stock_bundle, stock_export)
    export_statuses(custom_bundle, custom_export)
    compare_exported_directories(
        stock_export,
        custom_export,
        output,
        stock_bundle,
        custom_bundle,
    )


if __name__ == "__main__":
    main()
